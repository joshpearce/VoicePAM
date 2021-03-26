//
//  util.swift
//  voicepam
//
//  Created by Joshua Pearce on 3/25/21.
//

import Foundation
import TSCBasic

public enum OutFileParamStatus {
        case empty
        case ok
        case directoryProvided
        case directoryNotFound
}

public extension String {
    var paramStatus: OutFileParamStatus {
        get {
            if !self.isEmpty {
                let url = URL(fileURLWithPath: self)
                var isDirectory = ObjCBool(false)
                var fileExists = FileManager.default.fileExists(atPath: self, isDirectory: &isDirectory)
                if (fileExists) {
                    if isDirectory.boolValue {
                        return .directoryProvided
                    }
                    else {
                        return .ok
                    }
                } else {
                    var parent = url.deletingLastPathComponent().absoluteString.replacingOccurrences(of: "file://", with: "")
                    if (url.absoluteString.hasSuffix("/")) {
                        parent = url.absoluteString.replacingOccurrences(of: "file://", with: "")
                    }
                    fileExists = FileManager.default.fileExists(atPath: parent, isDirectory: &isDirectory)
                    if !fileExists {
                        return .directoryNotFound
                    } else {
                        return .ok
                    }
                }
            } else {
                return .empty
            }
        }
    }
}

extension FileHandle {
    func enableRawMode() -> termios {
        var raw = termios()
        tcgetattr(self.fileDescriptor, &raw)

        let original = raw
        raw.c_lflag &= ~UInt(ECHO | ICANON)
        tcsetattr(self.fileDescriptor, TCSADRAIN, &raw)
        return original
    }

    func restoreRawMode(originalTerm: termios) {
        var term = originalTerm
        tcsetattr(self.fileDescriptor, TCSADRAIN, &term)
    }
}

public extension TerminalController {
    func getch() -> UInt8 {
        let handle = FileHandle.standardInput
        let term = handle.enableRawMode()
        defer { handle.restoreRawMode(originalTerm: term) }

        var byte: UInt8 = 0
        read(handle.fileDescriptor, &byte, 1)
        
        return byte
    }
}


