import Foundation

/// パネルに表示する文字列の整形と絞り込み（docs/specs/ui-and-paste.md）。
public enum DisplayText {
    public static let previewLength = 60
    public static let tooltipLength = 500

    /// 先頭の空白を除いた1行目を最大 `limit` 文字にする。続きがあれば「…」を付ける。
    public static func preview(_ text: String, limit: Int = previewLength) -> String {
        let trimmed = text.drop { $0.isWhitespace || $0.isNewline }
        let lines = trimmed.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let firstLine = (lines.first.map(String.init) ?? "").replacingOccurrences(of: "\t", with: "⇥")
        let hasMoreLines = lines.dropFirst().contains { !$0.allSatisfy(\.isWhitespace) }
        if firstLine.count > limit {
            return String(firstLine.prefix(limit)) + "…"
        }
        return hasMoreLines ? firstLine + "…" : firstLine
    }

    public static func tooltip(_ text: String, limit: Int = tooltipLength) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }

    /// 大文字と小文字を区別しない部分一致。空の検索語はすべてに一致する。
    public static func matches(_ query: String, _ fields: String...) -> Bool {
        guard !query.isEmpty else { return true }
        return fields.contains { $0.range(of: query, options: .caseInsensitive) != nil }
    }
}
