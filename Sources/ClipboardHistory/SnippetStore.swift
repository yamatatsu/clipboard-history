import Foundation
import ClipboardHistoryCore

/// snippets.json の読み込みと変更の監視（docs/specs/snippets.md）。
@MainActor
final class SnippetStore {
    let fileURL: URL
    private(set) var library: SnippetLibrary = .empty
    var onLoadError: ((String) -> Void)?

    private var source: DispatchSourceFileSystemObject?

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("snippets.json")
    }

    func start() {
        createSampleIfMissing()
        reload()
        watch()
    }

    /// 読めなければ、前に読めた内容を使い続ける。
    func reload() {
        do {
            let data = try Data(contentsOf: fileURL)
            library = try SnippetLibrary.decode(data)
        } catch {
            onLoadError?(SnippetLibrary.describe(error))
        }
    }

    private func createSampleIfMissing() {
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try SnippetLibrary.sample.encoded()
            FileManager.default.createFile(atPath: fileURL.path, contents: data, attributes: [.posixPermissions: 0o600])
        } catch {
            log.error("failed to create sample snippets: \(String(describing: error), privacy: .public)")
        }
    }

    private func watch() {
        source?.cancel()
        source = nil

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else {
            log.error("cannot watch snippets.json (errno \(errno, privacy: .public))")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let source = self.source else { return }
                if !source.data.isDisjoint(with: [.delete, .rename]) {
                    // エディタが保存のたびにファイルを置き換える場合は、新しいファイルを監視し直す。
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.createSampleIfMissing()
                        self.reload()
                        self.watch()
                    }
                } else {
                    self.reload()
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }
}
