---
phase: 4
title: "Global Hotkeys"
status: pending
priority: P0
effort: "4h"
dependencies: [2, 3]
---

# Phase 4: Global Hotkeys

## Overview
Đăng ký global keyboard shortcuts dịch nhanh từ bất kỳ app nào. Core flow: hotkey → đọc text → dịch → hiện floating panel.

## Requirements
- **Functional:**
  - `⌃+⌥+T` — dịch text đang bôi đen
  - `⌃+⌥+S` — chụp màn hình OCR → dịch (triggers Phase 5)
  - `⌃+⌥+V` — dịch clipboard (triggers Phase 6)
  - Hiện kết quả trong floating panel gần cursor
  - Phím tắt configurable trong Settings (Phase 7)
- **Non-functional:**
  - Yêu cầu Accessibility permission (cho read selected text)
  - Hoạt động từ bất kỳ app nào (Chrome, Slack, VSCode...)
  - Không conflict với shortcuts của app đang active

## Architecture

### Files
```
Services/
├── HotkeyManager.swift          # Carbon RegisterEventHotKey registration
└── SelectedTextReader.swift     # Read selected text via simulated ⌘+C
```

### Hotkey Registration (Carbon API)
```swift
class HotkeyManager {
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private let translationService: TranslationService
    private let floatingPanel: FloatingPanelController

    func register() {
        // Register 3 hotkeys using Carbon RegisterEventHotKey
        // Each with unique ID (see Constants.HotkeyIDs)
        //
        // Carbon approach:
        // 1. Create EventTypeSpec for kEventHotKeyPressed
        // 2. InstallEventHandler on GetApplicationEventTarget()
        // 3. RegisterEventHotKey for each shortcut
    }
}
```

#### Tại sao Carbon thay vì CGEventTap?
- `RegisterEventHotKey` đơn giản hơn, không cần Accessibility permission chỉ để đăng ký hotkey
- `CGEventTap` cần Accessibility permission ngay khi đăng ký
- Carbon API deprecated nhưng vẫn hoạt động ổn trên macOS 14+ và được nhiều app dùng (Raycast, Alfred, etc.)

### Selected Text Reader
```swift
struct SelectedTextReader {
    /// Đọc text đang được bôi đen trong bất kỳ app nào
    /// Cách: backup clipboard → simulate ⌘+C → read clipboard → restore clipboard
    static func readSelectedText() async -> String? {
        // 1. Backup current clipboard content
        let backup = NSPasteboard.general.string(forType: .string)
        let backupChangeCount = NSPasteboard.general.changeCount

        // 2. Simulate ⌘+C via CGEvent
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source,
                              virtualKey: CGKeyCode(kVK_ANSI_C),
                              keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source,
                            virtualKey: CGKeyCode(kVK_ANSI_C),
                            keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdDown?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)

        // 3. Wait briefly for clipboard to update
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // 4. Read clipboard
        let selectedText = NSPasteboard.general.string(forType: .string)

        // 5. Restore original clipboard
        if let backup = backup {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(backup, forType: .string)
        }

        // 6. Return selected text (nil if clipboard didn't change)
        if NSPasteboard.general.changeCount == backupChangeCount {
            return nil // No text was selected
        }
        return selectedText
    }
}
```

**Quan trọng:** Cần Accessibility permission để `CGEvent.post()` hoạt động.

### Translate Selected Text Flow
```
User bôi đen text ở bất kỳ app nào
  → Bấm ⌃+⌥+T
    → HotkeyManager nhận event
      → SelectedTextReader.readSelectedText()
        → Backup clipboard
        → Simulate ⌘+C
        → Read clipboard
        → Restore clipboard
      → LanguageDetector.detect(text)
      → TranslationService.translate(text, perMessageContext: nil)
      → FloatingPanelController.show(result, near: mouseLocation)
        → User click Copy → copy to clipboard + dismiss
        → Hoặc auto-dismiss sau 10s
```

### Permission Handling
```swift
struct AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestIfNeeded() {
        if !isGranted {
            // Show dialog hướng dẫn user bật Accessibility
            // Open System Settings → Privacy → Accessibility
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }
}
```

## Related Code Files
- Create: `FastTranslate/Services/HotkeyManager.swift`
- Create: `FastTranslate/Services/SelectedTextReader.swift`
- Modify: `FastTranslate/App/AppDelegate.swift` (init HotkeyManager, pass dependencies)
- Modify: `FastTranslate/Utils/Constants.swift` (hotkey key codes + IDs đã có)

## Implementation Steps
1. Tạo `SelectedTextReader.swift`:
   - Backup clipboard → simulate ⌘+C → read clipboard → restore
   - Handle case: không có text bôi đen (clipboard không thay đổi)
   - Yêu cầu Accessibility permission
2. Tạo `HotkeyManager.swift`:
   - Carbon `RegisterEventHotKey` cho 3 shortcuts
   - Event handler dispatch theo hotkey ID
   - `⌃+⌥+T` → `handleTranslateSelected()`
   - `⌃+⌥+S` → `handleScreenshotOCR()` (Phase 5, placeholder)
   - `⌃+⌥+V` → `handleTranslateClipboard()` (Phase 6, placeholder)
3. Implement `handleTranslateSelected()`:
   - Call SelectedTextReader
   - If no text → show brief notification "No text selected"
   - If text → translate → show FloatingPanelController
4. Permission handling:
   - Check `AXIsProcessTrusted()` on app launch
   - If not trusted → show dialog hướng dẫn enable Accessibility
   - Log warning nếu hotkey registered nhưng không có permission
5. Wire trong AppDelegate:
   - `hotkeyManager = HotkeyManager(translationService, floatingPanel)`
   - `hotkeyManager.register()` trong `applicationDidFinishLaunching`
6. Test: bôi đen text trong Chrome/Slack → ⌃+⌥+T → floating panel hiện bản dịch

## Success Criteria
- [ ] ⌃+⌥+T dịch text bôi đen từ bất kỳ app nào
- [ ] Floating panel hiện gần cursor với bản dịch
- [ ] Click copy trên panel → copy vào clipboard
- [ ] Panel auto-dismiss sau 10s
- [ ] Không có text bôi đen → thông báo "No text selected"
- [ ] Clipboard gốc được restore sau khi đọc selected text
- [ ] Accessibility permission dialog hiện đúng lúc
- [ ] ⌃+⌥+S và ⌃+⌥+V registered (placeholder cho Phase 5, 6)

## Risk Assessment
- **Clipboard restore race condition:** 100ms wait có thể không đủ trên máy chậm. Thêm retry loop check `changeCount` thay vì fixed delay
- **Accessibility permission UX:** User có thể quên bật. Thêm check + reminder trong menu bar dropdown
- **Carbon API deprecation:** Vẫn hoạt động trên macOS 14+. Nếu Apple remove trong tương lai, migrate sang `CGEventTap` hoặc `NSEvent.addGlobalMonitorForEvents`
- **Hotkey conflict:** ⌃+⌥+T/S/V ít conflict nhưng không zero. Phase 7 cho phép customize
