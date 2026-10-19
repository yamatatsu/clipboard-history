import AppKit
import ClipboardHistoryCore

/// パネルに並べる1行。見出しは選べない。
struct PickerEntry {
    enum Kind {
        case header
        case item(onChoose: () -> Void)
    }

    let kind: Kind
    let title: String
    var tooltip: String? = nil
    /// 絞り込みの対象にする文字列。
    var searchFields: [String] = []

    var isHeader: Bool {
        if case .header = kind { return true }
        return false
    }
}

/// 元のアプリのフォーカスを奪わずにキー入力を受けるパネル。
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// 履歴とスニペットで共通の、検索欄つきのパネル（docs/specs/ui-and-paste.md）。
@MainActor
final class PickerPanel: NSObject {
    private let panel: KeyablePanel
    private let searchField = NSSearchField()
    private let tableView = NSTableView()

    private var entries: [PickerEntry] = []
    private var visible: [PickerEntry] = []
    private var numbered = false

    override init() {
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered, defer: true)
        super.init()
        configurePanel()
    }

    var isVisible: Bool { panel.isVisible }

    func show(entries: [PickerEntry], placeholder: String, numbered: Bool) {
        self.entries = entries
        self.numbered = numbered
        searchField.placeholderString = placeholder
        searchField.stringValue = ""
        applyFilter()
        positionNearMouse()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func close() {
        panel.orderOut(nil)
    }

    // MARK: - 組み立て

    private func configurePanel() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: .init("main"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 22
        tableView.style = .inset
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.action = #selector(rowClicked)
        tableView.refusesFirstResponder = true

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let content = NSVisualEffectView()
        content.material = .menu
        content.state = .active
        content.addSubview(searchField)
        content.addSubview(scroll)
        panel.contentView = content

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 30),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
        ])
    }

    private func positionNearMouse() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x, y: mouse.y - size.height)
        if let bounds = screen?.visibleFrame {
            origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
            origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
    }

    // MARK: - 絞り込みと選択

    private var query: String { searchField.stringValue.trimmingCharacters(in: .whitespaces) }

    private func applyFilter() {
        let query = self.query
        var result: [PickerEntry] = []
        var pendingHeader: PickerEntry?
        for entry in entries {
            if entry.isHeader {
                pendingHeader = entry
            } else if entry.searchFields.contains(where: { DisplayText.matches(query, $0) }) {
                if let header = pendingHeader {
                    result.append(header)
                    pendingHeader = nil
                }
                result.append(entry)
            }
        }
        visible = result
        tableView.reloadData()
        selectRow(firstSelectable(from: 0, step: 1))
    }

    /// 検索欄が空のときだけ、先頭から9件に番号を付ける。
    private func number(forRow row: Int) -> Int? {
        guard numbered, query.isEmpty, !visible[row].isHeader else { return nil }
        let n = visible[...row].filter { !$0.isHeader }.count
        return n <= 9 ? n : nil
    }

    private func firstSelectable(from start: Int, step: Int) -> Int? {
        var row = start
        while row >= 0 && row < visible.count {
            if !visible[row].isHeader { return row }
            row += step
        }
        return nil
    }

    private func selectRow(_ row: Int?) {
        guard let row else {
            tableView.deselectAll(nil)
            return
        }
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func moveSelection(_ step: Int) {
        let current = tableView.selectedRow
        let start = current < 0 ? (step > 0 ? 0 : visible.count - 1) : current + step
        if let row = firstSelectable(from: start, step: step) {
            selectRow(row)
        }
    }

    private func choose(row: Int) {
        guard row >= 0, row < visible.count, case .item(let onChoose) = visible[row].kind else { return }
        close()
        onChoose()
    }

    @objc private func rowClicked() {
        choose(row: tableView.clickedRow)
    }
}

extension PickerPanel: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let text = searchField.stringValue
        // 空の検索欄に 1〜9 を打ったら、その番号の項目に決める。
        if numbered, text.count == 1, let n = Int(text), (1...9).contains(n),
           let row = visible.indices.first(where: { !visible[$0].isHeader && numberIgnoringQuery(row: $0) == n }) {
            choose(row: row)
            return
        }
        applyFilter()
    }

    private func numberIgnoringQuery(row: Int) -> Int {
        visible[...row].filter { !$0.isHeader }.count
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(-1)
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(1)
        case #selector(NSResponder.insertNewline(_:)):
            choose(row: tableView.selectedRow)
        case #selector(NSResponder.cancelOperation(_:)):
            close()
        default:
            return false
        }
        return true
    }
}

extension PickerPanel: NSWindowDelegate {
    /// パネルの外をクリックしたら閉じる。
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}

extension PickerPanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        visible.count
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !visible[row].isHeader
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        visible[row].isHeader
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = visible[row]
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = entry.tooltip

        if entry.isHeader {
            label.stringValue = entry.title
            label.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
            label.textColor = .secondaryLabelColor
        } else {
            let text = NSMutableAttributedString()
            if let n = number(forRow: row) {
                text.append(NSAttributedString(string: "\(n)  ", attributes: [
                    .foregroundColor: NSColor.tertiaryLabelColor,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                ]))
            }
            text.append(NSAttributedString(string: entry.title, attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor,
            ]))
            label.attributedStringValue = text
        }

        let cell = NSTableCellView()
        cell.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
