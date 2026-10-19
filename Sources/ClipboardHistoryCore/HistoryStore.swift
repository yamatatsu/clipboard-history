import Foundation

public struct HistoryItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    /// 最後にコピーまたは貼り付けた日時。
    public var copiedAt: Date

    public init(id: UUID = UUID(), text: String, copiedAt: Date) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }
}

/// クリップボード履歴（docs/specs/clipboard-history.md）。新しいものほど先頭。
public struct HistoryStore {
    public private(set) var items: [HistoryItem]
    public let maxItems: Int
    public let retention: TimeInterval

    public init(
        items: [HistoryItem] = [],
        maxItems: Int = Config.maxHistoryItems,
        retention: TimeInterval = Config.historyRetention
    ) {
        self.maxItems = maxItems
        self.retention = retention
        self.items = Array(items.sorted { $0.copiedAt > $1.copiedAt }.prefix(maxItems))
    }

    /// テキストを先頭に追加する。同じテキストがあれば先頭に移す。
    public mutating func record(_ text: String, now: Date) {
        if let index = items.firstIndex(where: { $0.text == text }) {
            var item = items.remove(at: index)
            item.copiedAt = now
            items.insert(item, at: 0)
        } else {
            items.insert(HistoryItem(text: text, copiedAt: now), at: 0)
            if items.count > maxItems {
                items.removeLast(items.count - maxItems)
            }
        }
    }

    /// 貼り付けた項目を先頭に移す。
    public mutating func promote(id: UUID, now: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: index)
        item.copiedAt = now
        items.insert(item, at: 0)
    }

    /// 保存期間を過ぎたものを消す。消したものがあれば true。
    @discardableResult
    public mutating func purgeExpired(now: Date) -> Bool {
        let before = items.count
        items.removeAll { now.timeIntervalSince($0.copiedAt) > retention }
        return items.count != before
    }

    public mutating func removeAll() {
        items.removeAll()
    }
}
