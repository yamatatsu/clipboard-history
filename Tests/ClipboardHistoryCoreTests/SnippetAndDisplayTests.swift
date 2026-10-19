import Foundation
import Testing
@testable import ClipboardHistoryCore

@Suite struct SnippetLibraryTests {
    @Test func decodesSpecExample() throws {
        let json = """
        {
          "version": 1,
          "folders": [
            { "title": "メール", "snippets": [
              { "title": "お礼", "content": "お世話になっております。\\n..." },
              { "title": "", "content": "署名\\n山本" }
            ] }
          ]
        }
        """
        let library = try SnippetLibrary.decode(Data(json.utf8))
        #expect(library.folders[0].title == "メール")
        #expect(library.folders[0].snippets.map(\.displayTitle) == ["お礼", "署名…"])
    }

    @Test func sampleRoundTrips() throws {
        #expect(try SnippetLibrary.decode(SnippetLibrary.sample.encoded()) == SnippetLibrary.sample)
    }

    @Test func describesErrors() {
        #expect(throws: (any Error).self) { try SnippetLibrary.decode(Data("{".utf8)) }
        do {
            _ = try SnippetLibrary.decode(Data(#"{"version":1,"folders":[{"snippets":[]}]}"#.utf8))
        } catch {
            #expect(SnippetLibrary.describe(error).contains("title"))
        }
    }
}

@Suite struct DisplayTextTests {
    @Test func preview() {
        #expect(DisplayText.preview("hello") == "hello")
        #expect(DisplayText.preview("  \n first\nsecond") == "first…")
        #expect(DisplayText.preview("only\n\n  ") == "only")
        #expect(DisplayText.preview("a\tb") == "a⇥b")
        #expect(DisplayText.preview(String(repeating: "あ", count: 61)) == String(repeating: "あ", count: 60) + "…")
    }

    @Test func tooltip() {
        #expect(DisplayText.tooltip("short") == "short")
        #expect(DisplayText.tooltip(String(repeating: "x", count: 501)).count == 501)
    }

    @Test func matches() {
        #expect(DisplayText.matches("", "anything"))
        #expect(DisplayText.matches("HeLLo", "say hello"))
        #expect(DisplayText.matches("メール", "お礼", "メール"))
        #expect(!DisplayText.matches("zzz", "abc"))
    }
}
