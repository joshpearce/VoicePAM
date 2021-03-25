//
//  util.swift
//  voicepam
//
//  Created by Joshua Pearce on 3/25/21.
//

import Foundation

open enum OutFileParamStatus {
        case empty
        case ok
        case directoryProvided
        case directoryNotFound
}

open extension String {
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
