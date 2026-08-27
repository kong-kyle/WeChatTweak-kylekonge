//
//  Command.swift
//
//  Created by Sunny Young.
//

import Foundation
import ArgumentParser

struct Command {
    enum Error: Swift.Error, LocalizedError {
        case executing(command: String, error: String)
        case invalidBinaryPath(String)

        var errorDescription: String? {
            switch self {
            case let .executing(command, error):
                return "executing: \(command) error: \(error)"
            case let .invalidBinaryPath(path):
                return "Invalid target binary path: \(path)"
            }
        }
    }

    static func version(app: URL) async throws -> String? {
        try await Command.execute(
            executable: "/usr/bin/defaults",
            arguments: [
                "read",
                app.appendingPathComponent("Contents/Info.plist").path,
                "CFBundleVersion"
            ]
        )
    }

    static func patch(app: URL, config: Config) async throws {
        let grouped = Dictionary(grouping: config.targets, by: { $0.binary })
        for (binary, targets) in grouped {
            let binaryURL = try targetURL(app: app, relativePath: binary)
            try Patcher.patch(binary: binaryURL, targets: targets)
            // Re-sign the patched binary so its own code signature matches the
            // new bytes. App-level `codesign --deep` does NOT re-sign standalone
            // dylibs under Resources (e.g. wechat.dylib), which would otherwise
            // crash WeChat at launch with "Code Signature Invalid / Invalid Page".
            try await Command.execute(
                executable: "/usr/bin/codesign",
                arguments: ["--force", "--sign", "-", binaryURL.path]
            )
        }
    }

    static func resign(app: URL) async throws {
        try await Command.execute(
            executable: "/usr/bin/codesign",
            arguments: ["--remove-sign", app.path]
        )
        try await Command.execute(
            executable: "/usr/bin/codesign",
            arguments: ["--force", "--deep", "--sign", "-", app.path]
        )
        // Keep quarantine and provenance metadata so patching does not bypass Gatekeeper.
    }

    private static func targetURL(app: URL, relativePath: String) throws -> URL {
        let appRoot = app.resolvingSymlinksInPath().standardizedFileURL
        let target = appRoot
            .appendingPathComponent(relativePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let rootPath = appRoot.path.hasSuffix("/") ? appRoot.path : appRoot.path + "/"

        guard target.path.hasPrefix(rootPath) else {
            throw Error.invalidBinaryPath(relativePath)
        }
        return target
    }

    @discardableResult
    private static func execute(executable: String, arguments: [String]) async throws -> String? {
        // Passing arguments directly prevents an app path from being interpreted as shell syntax.
        let command = ([executable] + arguments).joined(separator: " ")
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw Error.executing(
                command: command,
                error: error.localizedDescription
            )
        }

        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = (String(data: errorOutput, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw Error.executing(
                command: command,
                error: !message.isEmpty
                    ? message
                    : "exit status \(process.terminationStatus)"
            )
        }

        return String(data: output, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
