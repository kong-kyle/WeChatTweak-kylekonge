//
//  Command.swift
//
//  Created by Sunny Young.
//

import Foundation
import ArgumentParser

struct Command {
    enum Error: @unchecked Sendable, LocalizedError {
        case executing(command: String, error: NSDictionary)

        var errorDescription: String? {
            switch self {
            case let .executing(command, error):
                return "executing: \(command) error: \(error)"
            }
        }
    }

    static func version(app: URL) async throws -> String? {
        try await Command.execute(command: "defaults read \(app.appendingPathComponent("Contents/Info.plist").path) CFBundleVersion")
    }

    static func patch(app: URL, config: Config) async throws {
        let grouped = Dictionary(grouping: config.targets, by: { $0.binary })
        for (binary, targets) in grouped {
            let binaryURL = app.appendingPathComponent(binary)
            try Patcher.patch(binary: binaryURL, targets: targets)
            // Re-sign the patched binary so its own code signature matches the
            // new bytes. App-level `codesign --deep` does NOT re-sign standalone
            // dylibs under Resources (e.g. wechat.dylib), which would otherwise
            // crash WeChat at launch with "Code Signature Invalid / Invalid Page".
            try await Command.execute(command: "codesign --force --sign - \(binaryURL.path)")
        }
    }

    static func resign(app: URL) async throws {
        try await Command.execute(command: "codesign --remove-sign \(app.path)")
        try await Command.execute(command: "codesign --force --deep --sign - \(app.path)")
        try await Command.execute(command: "xattr -cr \(app.path)")
    }

    @discardableResult
    private static func execute(command: String) async throws -> String? {
        guard let script = NSAppleScript(source: "do shell script \"\(command)\"") else {
            throw Error.executing(
                command: command,
                error: ["error": "Create script failed."]
            )
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)

        if let error = error {
            throw Error.executing(
                command: command,
                error: error
            )
        } else {
            return descriptor.stringValue
        }
    }
}
