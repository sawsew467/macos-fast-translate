import AppKit
import Carbon.HIToolbox

/// Reads the text currently selected in the frontmost application.
///
/// Strategy: backup clipboard → simulate ⌘+C → poll until clipboard changes → restore clipboard.
/// Requires Accessibility permission so CGEvent.post() can inject the keypress.
struct SelectedTextReader {

    /// Returns the selected text, or `nil` if nothing is selected or Accessibility is not granted.
    static func readSelectedText() async -> String? {
        let tag = "SelectedTextReader"

        // --- Permission check ---
        let trusted = AXIsProcessTrusted()
        print("[\(tag)] AXIsProcessTrusted = \(trusted)")
        if !trusted {
            print("[\(tag)] ❌ No Accessibility permission — CGEvent.post() will be ignored")
            return nil
        }

        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount
        let backup = pasteboard.string(forType: .string)
        print("[\(tag)] clipboard changeCount before = \(changeCountBefore), backup = \(backup?.prefix(40) ?? "nil")")

        // Brief pause so the hotkey press doesn't disturb the selection in the frontmost app
        try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms

        // --- Simulate ⌘+C ---
        let source = CGEventSource(stateID: .hidSystemState)
        print("[\(tag)] CGEventSource = \(source != nil ? "OK" : "nil")")

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            print("[\(tag)] ❌ Failed to create CGEvent")
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand
        print("[\(tag)] Posting ⌘+C keyDown via cgSessionEventTap…")
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        print("[\(tag)] ⌘+C posted")

        // --- Poll for clipboard change (up to 500 ms, 10 × 50 ms) ---
        var selectedText: String?
        for i in 0 ..< 10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            let current = pasteboard.changeCount
            print("[\(tag)] poll \(i+1)/10 — changeCount = \(current)")
            if current != changeCountBefore {
                selectedText = pasteboard.string(forType: .string)
                print("[\(tag)] ✅ Clipboard changed! text = \(selectedText?.prefix(80) ?? "nil")")
                break
            }
        }

        if selectedText == nil {
            print("[\(tag)] ❌ Clipboard did not change after 500 ms — no text was selected or ⌘+C was not received")
        }

        // --- Restore original clipboard ---
        pasteboard.clearContents()
        if let backup {
            pasteboard.setString(backup, forType: .string)
        }
        print("[\(tag)] clipboard restored")

        return selectedText
    }
}
