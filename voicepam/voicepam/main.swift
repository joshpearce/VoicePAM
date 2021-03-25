//
//  main.swift
//  voicepam
//
//  Created by Joshua Pearce on 3/25/21.
//

import Foundation
import TSCBasic
import AVFoundation
import QuartzCore
import ArgumentParser

class RecordingDelegate: NSObject, AVAudioRecorderDelegate {
    let done, error: () -> Void
    init(done: @escaping () -> Void, error: @escaping () -> Void) {
        self.done = done
        self.error = error
    }
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.done()
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        self.error()
    }
}

enum State: Int {
    case None, Record, Play
}

let bitRate = 192000
let sampleRate = 44100.0
let channels = 1
let dbFloor: Float = 30.0


struct MainProcess: ParsableCommand {
    static var shouldExit = false
    
    @Option()
    var outFile: String = ""

    mutating func run () {
        var recordingURL: URL
        
        switch outFile.paramStatus {
        case .directoryProvided:
            print ("Please provide a path+filename, not just a directory")
            Self.shouldExit = true
            return
        case .directoryNotFound:
            print ("directory not found for: \(outFile)")
            Self.shouldExit = true
            return
        case .ok:
            print ("using output file: \(outFile)")
            recordingURL = URL(fileURLWithPath: outFile)
        default:
            let userHiddenDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".sudovoice", isDirectory: true)
            recordingURL = userHiddenDir.appendingPathComponent("recording.m4a")
            do {
                try FileManager.default.createDirectory(at: userHiddenDir, withIntermediateDirectories: true)
            }
            catch let error as NSError
            {
                print("Unable to create \(userHiddenDir.absoluteString) \(error.debugDescription)")
                Self.shouldExit = true
                return
            }
        }
        
        //print ("Output file: \(outFile)")
        //Self.shouldExit = true

        let settings: [String: AnyObject] = [
            AVFormatIDKey : NSNumber(value: Int32(kAudioFormatMPEG4AAC)),
            // Change below to any quality your app requires
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue as AnyObject,
            AVEncoderBitRateKey: bitRate as AnyObject,
            AVNumberOfChannelsKey: channels as AnyObject,
            AVSampleRateKey: sampleRate as AnyObject
        ]
        
        var recorder: AVAudioRecorder
        
        do {
            let recorderTemp: AVAudioRecorder? = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder = recorderTemp!
        }
        catch let error as NSError
        {
            print("Error: \(error.debugDescription)")
            Self.shouldExit = true
            return
        }
        
        recorder.delegate = RecordingDelegate(
            done: {
            () -> Void in
                print("Recording complete")
                Self.shouldExit = true
            },
            error: {
            () -> Void in
                print("Recording error")
                Self.shouldExit = true
            })
        let prepareSuccess = recorder.prepareToRecord()

        recorder.isMeteringEnabled = true;
        
// TODO: Convert the following to use dispatching or some async tasks
//        tc!.write("Begin speaking in, ")
//        tc!.write("3 ")
//        usleep(1000000)
//        tc!.write("2 ")
//        usleep(1000000)
//        tc!.write("1 ")
//        usleep(1000000)
//
//        recorder!.record()
//
//        tc!.write("GO")
//
//        tc!.endLine()
//
//        var counter = 0
//
//        while true {
//            tc!.clearLine()
//            let peakPower = recorder!.peakPower(forChannel: 0)
//            recorder!.updateMeters()
//
//            let vol = max(0, dbFloor + peakPower)
//            let volMeter = String(repeating: ".", count: Int(vol))
//
//            tc!.write(volMeter, inColor: .red, bold: true)
//            counter += 1
//            if counter > 1000 && vol < 2.0 {
//                break
//            }
//            usleep(1000)
//        }
//        recorder!.stop()
//        tc!.write("Press <ENTER> to hear recording")
//        readLine()
//        let player: AVAudioPlayer? = try AVAudioPlayer(contentsOf: recordingURL as URL)
//        player!.volume = 1.0
//        player!.play()
//        tc!.write("Press <ENTER> to exit")
//        readLine()
        
        
    }
}

autoreleasepool {
    print("In autoreleasepool")
    let runLoop = RunLoop.current
    MainProcess.main()
    
    while (!MainProcess.shouldExit && (runLoop.run(mode: .default, before: Date.distantFuture))) {}
}

