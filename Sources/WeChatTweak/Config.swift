//
//  Config.swift
//  WeChatTweak
//
//  Created by Sunny Young on 2025/12/5.
//

import Foundation
import MachO
import CryptoKit

struct Config: Decodable {
    enum LoadError: Swift.Error, LocalizedError {
        case untrustedRemoteURL
        case invalidRemoteResponse
        case configTooLarge
        case integrityMismatch

        var errorDescription: String? {
            switch self {
            case .untrustedRemoteURL:
                return "Only the pinned release config URL or a local file is allowed"
            case .invalidRemoteResponse:
                return "Invalid remote config response"
            case .configTooLarge:
                return "Config file is too large"
            case .integrityMismatch:
                return "Config integrity check failed"
            }
        }
    }

    // Keeping the URL and digest together prevents a branch update from changing patch bytes silently.
    static let defaultURL = URL(string: "https://raw.githubusercontent.com/kong-kyle/WeChatTweak-kylekonge/5a6d9f804bb9a1a5bb5a8631320f17d81bcfba11/config.json")!
    private static let defaultSHA256 = "6c64e80b22e33878933b698dd4beeee6747f41a468a74a35670807deb7e40f2c"
    private static let maxConfigBytes = 1024 * 1024

    enum Arch: String, Decodable {
        case arm64
        case x86_64

        var cpu: UInt32 {
            switch self {
            case .arm64:
                return UInt32(CPU_TYPE_ARM64)
            case .x86_64:
                return UInt32(CPU_TYPE_X86_64)
            }
        }
    }

    struct Entry: Decodable {
        let arch: Arch
        let addr: UInt64
        let asm: Data
        let expected: Data?

        private enum CodingKeys: CodingKey {
            case arch
            case addr
            case asm
            case expected
        }

        init(from decoder: any Decoder) throws {
            let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
            self.arch = try container.decode(Arch.self, forKey: .arch)
            self.addr = try {
                let hex = try container.decode(String.self, forKey: .addr)
                guard let value = UInt64(hex, radix: 16) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: CodingKeys.addr,
                        in: container,
                        debugDescription: "Invalid Entry.addr"
                    )
                }
                return value
            }()
            self.asm = try {
                let hex = try container.decode(String.self, forKey: .asm)
                guard let value = Data(hex: hex) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: CodingKeys.asm,
                        in: container,
                        debugDescription: "Invalid Entry.asm"
                    )
                }
                guard !value.isEmpty else {
                    throw DecodingError.dataCorruptedError(
                        forKey: CodingKeys.asm,
                        in: container,
                        debugDescription: "Entry.asm cannot be empty"
                    )
                }
                return value
            }()
            self.expected = try {
                guard let hex = try container.decodeIfPresent(String.self, forKey: .expected) else {
                    return nil
                }
                guard let value = Data(hex: hex) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: CodingKeys.expected,
                        in: container,
                        debugDescription: "Invalid Entry.expected"
                    )
                }
                return value
            }()
        }
    }

    struct Target: Decodable {
        static let defaultBinary = "Contents/MacOS/WeChat"

        let identifier: String
        let entries: [Entry]
        let binary: String

        private enum CodingKeys: CodingKey {
            case identifier
            case entries
            case binary
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.identifier = try container.decode(String.self, forKey: .identifier)
            self.entries = try container.decode([Entry].self, forKey: .entries)
            let binary = try container.decodeIfPresent(String.self, forKey: .binary) ?? Target.defaultBinary
            guard Self.isSafeRelativeBinaryPath(binary) else {
                throw DecodingError.dataCorruptedError(
                    forKey: CodingKeys.binary,
                    in: container,
                    debugDescription: "Invalid target binary path"
                )
            }
            self.binary = binary
        }

        private static func isSafeRelativeBinaryPath(_ path: String) -> Bool {
            guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0") else {
                return false
            }
            return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
        }
    }

    let version: String
    let targets: [Target]

    static func load(url: URL) async throws -> [Config] {
        let data: Data
        if url.isFileURL {
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            data = try file.read(upToCount: maxConfigBytes + 1) ?? Data()
            guard data.count <= maxConfigBytes else {
                throw LoadError.configTooLarge
            }
        } else {
            guard url == defaultURL else {
                throw LoadError.untrustedRemoteURL
            }

            let (remoteData, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  response.url == defaultURL else {
                throw LoadError.invalidRemoteResponse
            }
            guard remoteData.count <= maxConfigBytes else {
                throw LoadError.configTooLarge
            }

            let digest = SHA256.hash(data: remoteData)
                .map { String(format: "%02x", $0) }
                .joined()
            guard digest == defaultSHA256 else {
                throw LoadError.integrityMismatch
            }
            data = remoteData
        }

        return try JSONDecoder().decode([Config].self, from: data)
    }
}

private extension Data {
    init?(hex: String) {
        let chars = Array(hex.utf8)
        guard chars.count % 2 == 0 else { return nil }

        self.init()
        self.reserveCapacity(chars.count / 2)

        func nibble(_ c: UInt8) -> UInt8? {
            switch c {
            case 48...57:  return c - 48       // '0'...'9'
            case 65...70:  return c - 55       // 'A'...'F'
            case 97...102: return c - 87       // 'a'...'f'
            default:       return nil
            }
        }

        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]),
                  let lo = nibble(chars[i + 1]) else { return nil }
            append(hi << 4 | lo)
            i += 2
        }
    }
}
