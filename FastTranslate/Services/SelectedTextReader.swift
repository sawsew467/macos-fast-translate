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
        if let text = selectedText(from: AXUIElementCreateSystemWide()) {
            return text
        }

        // During debug the app can briefly become frontmost after the hotkey.
        // Prefer the real user-facing app instead of querying FastTranslate itself.
        let candidates = NSWorkspace.shared.runningApplications.filter { app in
            app.isActive && app.bundleIdentifier != Bundle.main.bundleIdentifier
        } + NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier
        }

        for app in candidates {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            if let text = selectedText(from: axApp) {
                return text
            }
        }

        return nil
    }

    private static func selectedText(from element: AXUIElement) -> String? {
        var focusedElement: CFTypeRef?
        let targetElement: AXUIElement
        if AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success, let focusedElement {
            targetElement = focusedElement as! AXUIElement
        } else {
            targetElement = element
        }

        var selectedText: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            targetElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        ) == .success else { return nil }

        return (selectedText as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Clipboard Simulation

    private static func readViaClipboard() async -> String? {
        let tag = "SelectedTextReader.clipboard"
        let pasteboard = NSPasteboard.general
        let changeCountBefore = pasteboard.changeCount
        let backupItems = (pasteboard.pasteboardItems ?? []).map(clonePasteboardItem)

        // Brief pause so the hotkey keystrokes settle before we inject Cmd+C.
        try? await Task.sleep(nanoseconds: 180_000_000) // 180 ms

        // Force a pasteboard change even when selected text matches existing clipboard text.
        pasteboard.clearContents()

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

        // Poll for clipboard content (up to 1.2s). Some apps copy asynchronously.
        var selectedText: String?
        for _ in 0 ..< 24 {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            if pasteboard.changeCount != changeCountBefore,
               let copied = pasteboard.string(forType: .string),
               !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedText = copied
                break
            }
        }

        if selectedText == nil {
            print("[\(tag)] Clipboard did not change - Cmd+C may not have reached the target app")
        }

        // Restore original clipboard as completely as possible.
        pasteboard.clearContents()
        if !backupItems.isEmpty {
            pasteboard.writeObjects(backupItems)
        }

        return selectedText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clonePasteboardItem(_ item: NSPasteboardItem) -> NSPasteboardItem {
        let clone = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                clone.setData(data, forType: type)
            } else if let string = item.string(forType: type) {
                clone.setString(string, forType: type)
            }
        }
        return clone
    }
}
