import CryptoKit
import Foundation
import ClipboardHistoryCore

/// history.enc の読み書き（docs/specs/storage-and-encryption.md）。
final class HistoryPersistence {
    enum LoadOutcome {
        case loaded([HistoryItem])
        case fresh
        /// 読み込めなかったファイルを退避して、空から始めた。
        case recovered
    }

    let directory: URL
    let fileURL: URL
    private var key: SymmetricKey?

    /// Keychain を使えないなど、保存できない状態なら false。履歴はメモリにだけ持つ。
    var isAvailable: Bool { key != nil }

    init() throws {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipboardHistory", isDirectory: true)
        fileURL = directory.appendingPathComponent("history.enc")
        try Self.prepareDirectory(directory)
    }

    static func prepareDirectory(_ url: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    func load() throws -> LoadOutcome {
        let exists = FileManager.default.fileExists(atPath: fileURL.path)
        // Keychain の読み込みに失敗（拒否など）したら throw して、既存のファイルには触らない。
        let existingKey = try KeychainKey.load()

        guard exists else {
            key = try existingKey ?? KeychainKey.create()
            return .fresh
        }
        guard let existingKey else {
            try quarantineUnreadableFile()
            key = try KeychainKey.create()
            return .recovered
        }
        key = existingKey
        do {
            let data = try Data(contentsOf: fileURL)
            return .loaded(try HistoryCodec.open(data, key: existingKey).items)
        } catch {
            log.error("history decode failed: \(String(describing: type(of: error)), privacy: .public)")
            try quarantineUnreadableFile()
            return .recovered
        }
    }

    func save(_ items: [HistoryItem]) throws {
        guard let key else { return }
        let data = try HistoryCodec.seal(HistoryFile(items: items), key: key)
        try writeAtomically(data)
    }

    /// 0600 の一時ファイルに書いてから rename で差し替える。平文は書かない。
    private func writeAtomically(_ data: Data) throws {
        let tmp = directory.appendingPathComponent(".history.enc.\(UUID().uuidString).tmp")
        let fd = open(tmp.path, O_WRONLY | O_CREAT | O_EXCL, mode_t(0o600))
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        do {
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            guard rename(tmp.path, fileURL.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        } catch {
            unlink(tmp.path)
            throw error
        }
    }

    private func quarantineUnreadableFile() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmmss"
        let dest = directory.appendingPathComponent("history.enc.unreadable-\(formatter.string(from: Date()))")
        try FileManager.default.moveItem(at: fileURL, to: dest)
    }
}
