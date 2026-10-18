import CryptoKit
import Foundation
import Testing
@testable import SafeClipyCore

@Suite struct HistoryCodecTests {
    let key = SymmetricKey(size: .bits256)
    let file = HistoryFile(items: [
        HistoryItem(text: "こんにちは", copiedAt: Date(timeIntervalSince1970: 1_700_000_000)),
        HistoryItem(text: "second", copiedAt: Date(timeIntervalSince1970: 1_700_000_100)),
    ])

    @Test func roundTrips() throws {
        let data = try HistoryCodec.seal(file, key: key)
        let opened = try HistoryCodec.open(data, key: key)
        #expect(opened.items == file.items)
        #expect(opened.version == HistoryFile.currentVersion)
    }

    @Test func startsWithMagicAndHidesPlaintext() throws {
        let data = try HistoryCodec.seal(file, key: key)
        #expect(data.prefix(4) == Data("SCH1".utf8))
        #expect(data.range(of: Data("second".utf8)) == nil)
    }

    @Test func usesFreshNonceEachTime() throws {
        #expect(try HistoryCodec.seal(file, key: key) != HistoryCodec.seal(file, key: key))
    }

    @Test func rejectsWrongKey() throws {
        let data = try HistoryCodec.seal(file, key: key)
        #expect(throws: (any Error).self) { try HistoryCodec.open(data, key: SymmetricKey(size: .bits256)) }
    }

    @Test func rejectsTampering() throws {
        var data = try HistoryCodec.seal(file, key: key)
        data[data.count - 1] ^= 0x01
        #expect(throws: (any Error).self) { try HistoryCodec.open(data, key: key) }
    }

    @Test func rejectsBadMagicAndShortData() throws {
        var data = try HistoryCodec.seal(file, key: key)
        data[0] = UInt8(ascii: "X")
        #expect(throws: HistoryCodec.Error.self) { try HistoryCodec.open(data, key: key) }
        #expect(throws: HistoryCodec.Error.self) { try HistoryCodec.open(Data("SCH1".utf8), key: key) }
    }
}
