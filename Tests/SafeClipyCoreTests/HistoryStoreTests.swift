import Foundation
import Testing
@testable import SafeClipyCore

@Suite struct HistoryStoreTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func recordsNewestFirst() {
        var store = HistoryStore()
        store.record("a", now: t0)
        store.record("b", now: t0 + 1)
        #expect(store.items.map(\.text) == ["b", "a"])
    }

    @Test func duplicateMovesToTopWithoutGrowing() {
        var store = HistoryStore()
        store.record("a", now: t0)
        store.record("b", now: t0 + 1)
        let originalID = store.items[1].id
        store.record("a", now: t0 + 2)
        #expect(store.items.map(\.text) == ["a", "b"])
        #expect(store.items[0].id == originalID)
        #expect(store.items[0].copiedAt == t0 + 2)
    }

    @Test func dropsOldestBeyondLimit() {
        var store = HistoryStore(maxItems: 3)
        for i in 0..<5 { store.record("\(i)", now: t0 + Double(i)) }
        #expect(store.items.map(\.text) == ["4", "3", "2"])
    }

    @Test func promoteMovesToTop() {
        var store = HistoryStore()
        store.record("a", now: t0)
        store.record("b", now: t0 + 1)
        store.promote(id: store.items[1].id, now: t0 + 2)
        #expect(store.items.map(\.text) == ["a", "b"])
        #expect(store.items[0].copiedAt == t0 + 2)
    }

    @Test func purgesExpired() {
        var store = HistoryStore(retention: 10)
        store.record("old", now: t0)
        store.record("new", now: t0 + 5)
        let first = store.purgeExpired(now: t0 + 11)
        let second = store.purgeExpired(now: t0 + 11)
        #expect(first)
        #expect(!second)
        #expect(store.items.map(\.text) == ["new"])
    }

    @Test func initSortsAndTruncates() {
        let items = (0..<5).map { HistoryItem(text: "\($0)", copiedAt: t0 + Double($0)) }
        let store = HistoryStore(items: items, maxItems: 2)
        #expect(store.items.map(\.text) == ["4", "3"])
    }
}
