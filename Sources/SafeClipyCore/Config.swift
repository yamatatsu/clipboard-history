import Foundation

/// 仕様で決めた値（docs/specs/README.md の「決まった値」）。
public enum Config {
    public static let bundleID = "local.safeclipy.SafeClipy"
    public static let maxHistoryItems = 30
    public static let historyRetention: TimeInterval = 7 * 24 * 60 * 60
    public static let maxTextBytes = 1_048_576
    /// SafeClipy 自身がクリップボードに書き込んだことを示す印。
    public static let markerType = "local.safeclipy.marker"
}
