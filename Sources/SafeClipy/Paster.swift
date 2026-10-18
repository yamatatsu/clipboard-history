import AppKit
import ApplicationServices
import Carbon
import SafeClipyCore

/// 選んだテキストをクリップボードに入れて ⌘V を送る（docs/specs/ui-and-paste.md）。
@MainActor
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// ⌘V を送れたら true。アクセシビリティの許可がなければ、クリップボードに入れるだけ。
    @discardableResult
    static func paste(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let marker = NSPasteboard.PasteboardType(Config.markerType)
        pasteboard.declareTypes([.string, marker], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: marker)

        guard isTrusted else { return false }
        // 元のアプリにフォーカスが戻るのを待つ。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            sendCommandV()
        }
        return true
    }

    static func promptForAccessibilityIfNeeded() {
        guard !isTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        for keyDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
