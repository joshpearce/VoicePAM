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

enum State: Int {
    case None, Record, Play
}

let bitRate = 192000
let sampleRate = 44100.0
let channels = 1
let dbFloor: Float = 30.0

typealias AudioDoneClosure = (_ recorder: AVAudioRecorder, _ successfully: Bool) -> Void
typealias AudioErrorClosure = (_ recorder: AVAudioRecorder, _ error: Error?) -> Void

class RecordingDelegate: NSObject, AVAudioRecorderDelegate {
    let done: AudioDoneClosure
    let error: AudioErrorClosure
    init(done: @escaping AudioDoneClosure, error: @escaping AudioErrorClosure) {
        self.done = done
        self.error = error
    }
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.done(recorder, flag)
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        self.error(recorder, error)
    }
}

struct MainProcess: ParsableCommand {
    
    static var shouldExit = false
    
    @Option()
    var outFile: String = ""
    func run () {
        let app = App()
        app.run(outFile)
    }
}

class App {
    let tc: TerminalController
    var recordingDelegate: RecordingDelegate? = nil
    
    init() {
        tc = TerminalController(stream: stdoutStream)!
    }
    
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("Recording complete")
        MainProcess.shouldExit = true
    }
    
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Recording error")
        MainProcess.shouldExit = true
    }

    func run (_ outFile: String) {
        let tc = TerminalController(stream: stdoutStream)!
        var recordingURL: URL
        
        switch outFile.paramStatus {
        case .directoryProvided:
            tc.write("Please provide a path+filename, not just a directory\n", inColor: .red)
            MainProcess.shouldExit = true
            return
        case .directoryNotFound:
            tc.write("directory not found for: \(outFile)\n", inColor: .red)
            MainProcess.shouldExit = true
            return
        case .ok:
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
                tc.write("Unable to create \(userHiddenDir.absoluteString) \(error.debugDescription)\n", inColor: .red)
                MainProcess.shouldExit = true
                return
            }
        }
        
        //tc.write("using output file: \(recordingURL.path)\n")

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
            tc.write("Error: \(error.debugDescription)\n", inColor: .red)
            MainProcess.shouldExit = true
            return
        }
        
        recordingDelegate = RecordingDelegate(
            done: {
            (_ recorder: AVAudioRecorder, _ successfully: Bool) -> Void in
                print("Recording complete")
                MainProcess.shouldExit = true
            },
            error: {
            (_ recorder: AVAudioRecorder, _ error: Error?) -> Void in
                print("Recording error")
                MainProcess.shouldExit = true
            })
        
        recorder.delegate = recordingDelegate!
        
        let _ = recorder.prepareToRecord()

        recorder.isMeteringEnabled = true;
        
        var cmd: UInt8 = 0
        while true {
            tc.clearLine()
            tc.write("Press 'r' to record, 'p' to play recording, or 'q' to quit.")
            cmd = tc.getch()
            if cmd == 114 {
                record(tc, recorder)
            }
            else if cmd == 112 {
                play(recordingURL)
            }
            else if cmd == 113 {
                MainProcess.shouldExit = true
                break
            }
        }
    }
    
    func record(_ tc: TerminalController, _ recorder: AVAudioRecorder) {
        tc.clearLine()
        tc.endLine()
        tc.write("When you are ready, press <ENTER>, and then say, \"My voice is my password.\"")
        let _ = tc.getch()
        recorder.record()
        tc.clearLine()
        tc.write("Press <ENTER> when done.\n")
        
        while true {
            let prevFileControl = fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK)
            tc.clearLine()
            let peakPower = recorder.averagePower(forChannel: 0)
            recorder.updateMeters()
            let vol = max(0, dbFloor + peakPower)
            let volMeter = String(repeating: ".", count: Int(vol))
            tc.write(volMeter, inColor: .red, bold: true)
            usleep(1000)
            var byte: UInt8 = 0
            let len = read(STDIN_FILENO, &byte, 1)
            if len > 0 {
                recorder.stop()
                let _ = fcntl(STDIN_FILENO, F_SETFL, prevFileControl)
                break
            }
        }
    }
    
    func play(_ recordingURL: URL) {
        do {
            tc.clearLine()
            tc.write("Playing...")
            let player: AVAudioPlayer? = try AVAudioPlayer(contentsOf: recordingURL)
            player!.volume = 1.0
            player!.play()
            sleep(UInt32(player!.duration.rounded(.up)))
        }
        catch let error as NSError
        {
            tc.write("Error: \(error.debugDescription)\n", inColor: .red)
            MainProcess.shouldExit = true
        }
        
    }
        
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

autoreleasepool {

    let runLoop = RunLoop.current
    MainProcess.main()
    
    while (!MainProcess.shouldExit && (runLoop.run(mode: .default, before: Date.distantFuture))) {}
}

