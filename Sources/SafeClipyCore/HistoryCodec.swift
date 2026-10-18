import CryptoKit
import Foundation

public struct HistoryFile: Codable {
    public static let currentVersion = 1

    public let version: Int
    public var items: [HistoryItem]

    public init(items: [HistoryItem]) {
        self.version = Self.currentVersion
        self.items = items
    }
}

/// history.enc の形式（docs/specs/storage-and-encryption.md）。
///
///     magic("SCH1") || nonce(12) || ciphertext || tag(16)
///
/// magic は AAD としても渡す。
public enum HistoryCodec {
    public enum Error: Swift.Error {
        case badFormat
        case unsupportedVersion(Int)
    }

    static let magic = Data("SCH1".utf8)

    public static func seal(_ file: HistoryFile, key: SymmetricKey) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(file)
        let box = try AES.GCM.seal(plaintext, using: key, authenticating: magic)
        guard let combined = box.combined else { throw Error.badFormat }
        return magic + combined
    }

    public static func open(_ data: Data, key: SymmetricKey) throws -> HistoryFile {
        guard data.count > magic.count + 12 + 16, data.prefix(magic.count) == magic else {
            throw Error.badFormat
        }
        let box = try AES.GCM.SealedBox(combined: data.dropFirst(magic.count))
        let plaintext = try AES.GCM.open(box, using: key, authenticating: magic)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(HistoryFile.self, from: plaintext)
        guard file.version == HistoryFile.currentVersion else {
            throw Error.unsupportedVersion(file.version)
        }
        return file
    }
}
