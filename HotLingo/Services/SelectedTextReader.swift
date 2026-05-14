import AppKit
import Carbon.HIToolbox

/// Reads the text currently selected in the frontmost application.
///
/// Strategy:
///   1. Try the Accessibility API (`kAXSelectedTextAttribute`) — fast, no side effects.
///   2. Fall back to clipboard simulation: backup clipboard → simulate ⌘+C → poll → restore.
/// Requires Accessibility permission.
struct SelectedTextReader {

    /// Lightweight read used by passive selection UI. It avoids clipboard simulation so
    /// simply selecting text never mutates the user's pasteboard or sends Cmd+C.
    static func readSelectedTextUsingAccessibilityOnly() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        return readViaAccessibilityAPI()
    }

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

        // Query only the active user-facing app. Scanning every regular app can pick up
        // stale selections from background apps and translate old clipboard/selection text.
        guard let app = frontmostUserApplication() else {
            return nil
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        if let text = selectedText(from: axApp) {
            return text
        }

        return nil
    }

    private static func frontmostUserApplication() -> NSRunningApplication? {
        let currentBundleID = Bundle.main.bundleIdentifier
        if let app = NSWorkspace.shared.frontmostApplication,
           app.bundleIdentifier != currentBundleID {
            return app
        }

        return NSWorkspace.shared.runningApplications.first {
            $0.isActive && $0.bundleIdentifier != currentBundleID
        }
    }

    private static func selectedText(from element: AXUIElement) -> String? {
        var focusedElement: CFTypeRef?
        let targetElement: AXUIElement
        if AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        ) == .success, let focusedElement,
           CFGetTypeID(focusedElement) == AXUIElementGetTypeID() {
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
        let backupItems = (pasteboard.pasteboardItems ?? []).map(clonePasteboardItem)
        let restorePasteboard = {
            pasteboard.clearContents()
            if !backupItems.isEmpty {
                pasteboard.writeObjects(backupItems)
            }
        }

        // Brief pause so the hotkey keystrokes settle before we inject Cmd+C.
        try? await Task.sleep(nanoseconds: 180_000_000) // 180 ms

        // Replace the current clipboard with a sentinel. If Cmd+C fails, the sentinel
        // remains and we return nil instead of translating the user's previous clipboard.
        let sentinel = "HotLingoPasteboardSentinel-\(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(sentinel, forType: .string)
        let sentinelChangeCount = pasteboard.changeCount

        // Use .privateState so physical modifier keys (⌃⌥ from the hotkey) don't leak into the event
        let source = CGEventSource(stateID: .privateState)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        else {
            print("[\(tag)] ❌ Failed to create CGEvent")
            restorePasteboard()
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
            if pasteboard.changeCount != sentinelChangeCount,
               let copied = pasteboard.string(forType: .string),
               copied != sentinel,
               !copied.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedText = copied
                break
            }
        }

        if selectedText == nil {
            print("[\(tag)] Clipboard did not change - Cmd+C may not have reached the target app")
        }

        // Restore original clipboard as completely as possible.
        restorePasteboard()

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
