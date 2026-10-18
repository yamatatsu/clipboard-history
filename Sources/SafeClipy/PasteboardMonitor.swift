import AppKit
import SafeClipyCore

/// changeCount を 0.5 秒ごとに確認する（docs/specs/clipboard-history.md）。
@MainActor
final class PasteboardMonitor {
    struct Snapshot {
        let text: String
        let types: [String]
        let frontmostBundleID: String?
    }

    var isPaused = false
    var onCopy: ((Snapshot) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        // 一時停止中も changeCount は進めておき、再開したときにさかのぼって記録しない。
        lastChangeCount = changeCount
        guard !isPaused else { return }

        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard !types.contains(Config.markerType) else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        onCopy?(Snapshot(text: text, types: types, frontmostBundleID: frontmost))
    }
}
