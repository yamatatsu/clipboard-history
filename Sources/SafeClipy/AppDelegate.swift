import AppKit
import Carbon
import SafeClipyCore
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var history = HistoryStore()
    private var persistence: HistoryPersistence?
    private let monitor = PasteboardMonitor()
    private var snippets: SnippetStore?
    private let hotKeys = HotKeyCenter()
    private let picker = PickerPanel()
    private var menuBar: MenuBarController?
    private var saveWork: DispatchWorkItem?
    private var purgeTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Notifier.requestAuthorization()
        setUpPersistence()
        setUpSnippets()

        monitor.onCopy = { [weak self] snapshot in self?.handleCopy(snapshot) }
        monitor.start()

        let purgeTimer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.purgeExpired() }
        }
        RunLoop.main.add(purgeTimer, forMode: .common)
        self.purgeTimer = purgeTimer

        registerHotKeys()
        menuBar = MenuBarController(actions: makeMenuActions())
        Paster.promptForAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveNow()
    }

    // MARK: - 履歴

    private func setUpPersistence() {
        do {
            let persistence = try HistoryPersistence()
            self.persistence = persistence
            switch try persistence.load() {
            case .loaded(let items):
                history = HistoryStore(items: items)
            case .fresh:
                break
            case .recovered:
                Notifier.post("履歴を読み込めなかったので、新しく始めます。")
            }
        } catch {
            // 鍵を読めないときは既存のファイルに触らず、この起動中はメモリにだけ持つ。
            log.error("persistence unavailable: \(String(describing: error), privacy: .public)")
            Notifier.post("履歴を保存できません（\(error)）。この起動中はメモリにだけ保持します。")
        }
        purgeExpired()
    }

    private func handleCopy(_ snapshot: PasteboardMonitor.Snapshot) {
        let decision = ContentFilter.evaluate(
            text: snapshot.text, pasteboardTypes: snapshot.types, frontmostBundleID: snapshot.frontmostBundleID)
        guard decision == .record else {
            if case .skip(let reason) = decision {
                log.debug("skipped: \(reason.rawValue, privacy: .public)")
            }
            return
        }
        history.record(snapshot.text, now: Date())
        history.purgeExpired(now: Date())
        scheduleSave()
    }

    private func purgeExpired() {
        if history.purgeExpired(now: Date()) {
            scheduleSave()
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func saveNow() {
        saveWork?.cancel()
        saveWork = nil
        guard let persistence, persistence.isAvailable else { return }
        do {
            try persistence.save(history.items)
        } catch {
            log.error("save failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func clearHistory() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "履歴を消去しますか？"
        alert.informativeText = "保存されている履歴もすべて消えます。元には戻せません。"
        alert.addButton(withTitle: "消去")
        alert.addButton(withTitle: "キャンセル")
        alert.buttons[0].hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        history.removeAll()
        saveNow()
    }

    // MARK: - スニペット

    private func setUpSnippets() {
        guard let directory = persistence?.directory ?? (try? Self.fallbackDirectory()) else { return }
        let store = SnippetStore(directory: directory)
        store.onLoadError = { message in
            Notifier.post("snippets.json を読み込めませんでした: \(message)")
        }
        store.start()
        snippets = store
    }

    private static func fallbackDirectory() throws -> URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SafeClipy", isDirectory: true)
        try HistoryPersistence.prepareDirectory(url)
        return url
    }

    // MARK: - パネル

    private func showHistory() {
        let entries = history.items.map { item in
            PickerEntry(
                kind: .item(onChoose: { [weak self] in self?.pasteHistoryItem(item.id) }),
                title: DisplayText.preview(item.text),
                tooltip: DisplayText.tooltip(item.text),
                searchFields: [item.text])
        }
        picker.show(entries: entries, placeholder: "履歴を検索", numbered: true)
    }

    private func pasteHistoryItem(_ id: UUID) {
        guard let item = history.items.first(where: { $0.id == id }) else { return }
        paste(item.text)
        history.promote(id: id, now: Date())
        scheduleSave()
    }

    private func showSnippets() {
        guard let library = snippets?.library else { return }
        var entries: [PickerEntry] = []
        for folder in library.folders {
            entries.append(PickerEntry(kind: .header, title: folder.title))
            for snippet in folder.snippets {
                entries.append(PickerEntry(
                    kind: .item(onChoose: { [weak self] in self?.paste(snippet.content) }),
                    title: snippet.displayTitle,
                    tooltip: DisplayText.tooltip(snippet.content),
                    searchFields: [folder.title, snippet.title, snippet.content]))
            }
        }
        picker.show(entries: entries, placeholder: "スニペットを検索", numbered: false)
    }

    private func paste(_ text: String) {
        if !Paster.paste(text) {
            Notifier.post("自動で貼り付けるには、アクセシビリティの許可が必要です。クリップボードには入れました。")
        }
    }

    // MARK: - ホットキーとメニュー

    private func registerHotKeys() {
        let modifiers = cmdKey | shiftKey
        if !hotKeys.register(keyCode: kVK_ANSI_V, modifiers: modifiers, handler: { [weak self] in self?.showHistory() }) {
            Notifier.post("⌘⇧V を登録できませんでした。")
        }
        if !hotKeys.register(keyCode: kVK_ANSI_B, modifiers: modifiers, handler: { [weak self] in self?.showSnippets() }) {
            Notifier.post("⌘⇧B を登録できませんでした。")
        }
    }

    private func makeMenuActions() -> MenuBarController.Actions {
        MenuBarController.Actions(
            openHistory: { [weak self] in self?.showHistory() },
            openSnippets: { [weak self] in self?.showSnippets() },
            togglePause: { [weak self] in
                guard let self else { return }
                monitor.isPaused.toggle()
            },
            clearHistory: { [weak self] in self?.clearHistory() },
            editSnippets: { [weak self] in
                guard let url = self?.snippets?.fileURL else { return }
                NSWorkspace.shared.open(url)
            },
            reloadSnippets: { [weak self] in self?.snippets?.reload() },
            toggleLaunchAtLogin: {
                let service = SMAppService.mainApp
                do {
                    if service.status == .enabled {
                        try service.unregister()
                    } else {
                        try service.register()
                    }
                } catch {
                    Notifier.post("ログイン項目を変更できませんでした: \(error.localizedDescription)")
                }
            },
            isPaused: { [weak self] in self?.monitor.isPaused ?? false },
            isLaunchAtLoginEnabled: { SMAppService.mainApp.status == .enabled })
    }
}
