import AppKit
import Carbon.HIToolbox

/// Reads the text currently selected in the frontmost application.
///
/// Strategy:
///   1. Try the Accessibility API (`kAXSelectedTextAttribute`) — fast, no side effects.
///   2. Fall back to clipboard simulation: backup clipboard → simulate ⌘+C → poll → restore.
/// Requires Accessibility permission.
struct SelectedTextReader {

    /// Returns the selected text, or `nil` if nothing is selected or Accessibility is not granted.
    static func readSelectedText() async -> String? {
        let tag = "SelectedTextReader"

        guard AXIsProcessTrusted() else {
            print("[\(tag)] ❌ No Accessibility permission")
            return nil
        }

        // --- Try 1: Accessibility API (fast, no clipboard side effects) ---
        if let text = readViaAccessibilityAPI(), !text.isEmpty {
            print("[\(tag)] ✅ Got text via AX API (\(text.count) chars)")
            return text
        }

        // --- Try 2: Clipboard simulation fallback ---
        print("[\(tag)] AX API returned nil, falling back to clipboard simulation")
        return await readViaClipboard()
    }

    // MARK: - Accessibility API

    private static func readViaAccessibilityAPI() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success else { return nil }

        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        ) == .success else { return nil }

        return selectedText as? String
    }

    // MARK: - Clipboard Simulation

    private static func readViaClipboard() async -> String? {
        let tag = "SelectedTextReader.clipboard"
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount
        let backup = pasteboard.string(forType: .string)

        // Brief pause so the hotkey keystrokes settle before we inject ⌘+C
        try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms

        // Use .privateState so physical modifier keys (⌃⌥ from the hotkey) don't leak into the event
        let source = CGEventSource(stateID: .privateState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            print("[\(tag)] ❌ Failed to create CGEvent")
            return nil
        }

        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)

        // Poll for clipboard change (up to 500 ms)
        var selectedText: String?
        for _ in 0 ..< 10 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            if pasteboard.changeCount != changeCountBefore {
                selectedText = pasteboard.string(forType: .string)
                break
            }
        }

        if selectedText == nil {
            print("[\(tag)] ❌ Clipboard did not change — ⌘+C may not have reached the target app")
        }

        // Restore original clipboard
        pasteboard.clearContents()
        if let backup {
            pasteboard.setString(backup, forType: .string)
        }

        return selectedText
    }
}
