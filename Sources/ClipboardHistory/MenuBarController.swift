import AppKit

/// メニューバーのアイコンとメニュー（docs/specs/ui-and-paste.md）。
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    struct Actions {
        var openHistory: () -> Void
        var openSnippets: () -> Void
        var togglePause: () -> Void
        var clearHistory: () -> Void
        var editSnippets: () -> Void
        var reloadSnippets: () -> Void
        var toggleLaunchAtLogin: () -> Void
        var isPaused: () -> Bool
        var isLaunchAtLoginEnabled: () -> Bool
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let actions: Actions
    private let pauseItem = NSMenuItem()
    private let loginItem = NSMenuItem()

    init(actions: Actions) {
        self.actions = actions
        super.init()
        buildMenu()
        updateIcon()
    }

    func updateIcon() {
        let name = actions.isPaused() ? "pause.circle" : "doc.on.clipboard"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "ClipboardHistory")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("履歴を開く", #selector(openHistory), key: "v"))
        menu.addItem(item("スニペットを開く", #selector(openSnippets), key: "b"))
        menu.addItem(.separator())
        pauseItem.target = self
        pauseItem.action = #selector(togglePause)
        menu.addItem(pauseItem)
        menu.addItem(item("履歴を消去…", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(item("スニペットを編集…", #selector(editSnippets)))
        menu.addItem(item("スニペットを再読み込み", #selector(reloadSnippets)))
        menu.addItem(.separator())
        loginItem.title = "ログイン時に起動"
        loginItem.target = self
        loginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "ClipboardHistory を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if !key.isEmpty {
            // 表示用。実際の動作は HotKeyCenter のグローバルホットキーで行う。
            item.keyEquivalentModifierMask = [.command, .shift]
        }
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.title = actions.isPaused() ? "記録を再開" : "記録を一時停止"
        loginItem.state = actions.isLaunchAtLoginEnabled() ? .on : .off
    }

    @objc private func openHistory() { actions.openHistory() }
    @objc private func openSnippets() { actions.openSnippets() }
    @objc private func togglePause() { actions.togglePause(); updateIcon() }
    @objc private func clearHistory() { actions.clearHistory() }
    @objc private func editSnippets() { actions.editSnippets() }
    @objc private func reloadSnippets() { actions.reloadSnippets() }
    @objc private func toggleLaunchAtLogin() { actions.toggleLaunchAtLogin() }
}
