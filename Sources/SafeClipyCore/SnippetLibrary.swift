import Foundation

/// snippets.json の形式（docs/specs/snippets.md）。
public struct SnippetLibrary: Codable, Equatable {
    public var version: Int
    public var folders: [SnippetFolder]

    public init(version: Int = 1, folders: [SnippetFolder]) {
        self.version = version
        self.folders = folders
    }

    public static let empty = SnippetLibrary(folders: [])

    public static let sample = SnippetLibrary(folders: [
        SnippetFolder(title: "サンプル", snippets: [
            Snippet(title: "あいさつ", content: "お世話になっております。"),
            Snippet(title: "", content: "タイトルが空のときは、この1行目が表示されます。\n2行目以降も貼り付けられます。"),
        ]),
    ])

    public static func decode(_ data: Data) throws -> SnippetLibrary {
        try JSONDecoder().decode(SnippetLibrary.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public struct SnippetFolder: Codable, Equatable {
    public var title: String
    public var snippets: [Snippet]

    public init(title: String, snippets: [Snippet]) {
        self.title = title
        self.snippets = snippets
    }
}

public struct Snippet: Codable, Equatable {
    public var title: String
    public var content: String

    public init(title: String, content: String) {
        self.title = title
        self.content = content
    }

    /// title が空なら content の1行目を使う。
    public var displayTitle: String {
        title.isEmpty ? DisplayText.preview(content) : title
    }
}

extension SnippetLibrary {
    /// 読み込みに失敗したときに通知する説明。どこが悪いかだけを示す。
    public static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
        }
        switch decodingError {
        case .dataCorrupted(let context):
            let underlying = (context.underlyingError as NSError?)?.userInfo[NSDebugDescriptionErrorKey] as? String
            return underlying ?? context.debugDescription
        case .keyNotFound(let key, let context):
            return "\(path(context)) に \(key.stringValue) がありません"
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "\(path(context)): \(context.debugDescription)"
        @unknown default:
            return "形式が正しくありません"
        }
    }
}
