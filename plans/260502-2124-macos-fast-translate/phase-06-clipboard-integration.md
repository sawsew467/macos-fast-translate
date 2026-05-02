---
phase: 6
title: "Clipboard Integration"
status: pending
priority: P2
effort: "2h"
dependencies: [2, 3, 4]
---

# Phase 6: Clipboard Integration

## Overview
Dịch nội dung clipboard qua hotkey. Flow: copy text → `⌃+⌥+V` → dịch → hiện kết quả + option thay thế clipboard.

## Requirements
- **Functional:**
  - `⌃+⌥+V` đọc clipboard text hiện tại
  - Dịch và hiện floating panel
  - Button "Replace" thay clipboard bằng bản dịch
  - Button "Paste" thay clipboard + simulate ⌘+V paste luôn
  - Handle clipboard rỗng hoặc không phải text

## Architecture

### Files
```
Services/
└── ClipboardService.swift    # NSPasteboard read/write operations
```

### Flow
```
User copy text (⌘+C) ở bất kỳ app nào
  → Bấm ⌃+⌥+V
    → ClipboardService.readText()
      → NSPasteboard.general.string(forType: .string)
    → If nil/empty → show notification "Clipboard is empty"
    → TranslationService.translate(text)
    → FloatingPanelController.show(result)
      → [Copy] → copy translation to clipboard
      → [Replace & Paste] → replace clipboard + simulate ⌘+V
```

### ClipboardService
```swift
struct ClipboardService {
    static func readText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    static func writeText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Replace clipboard with translation + simulate paste
    static func replaceAndPaste(_ text: String) {
        writeText(text)
        // Simulate ⌘+V via CGEvent (same approach as SelectedTextReader)
        let source = CGEventSource(stateID: .hidSystemState)
        let vDown = CGEvent(keyboardEventSource: source,
                            virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        vDown?.flags = .maskCommand
        let vUp = CGEvent(keyboardEventSource: source,
                          virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
    }
}
```

### Floating Panel cho Clipboard
Floating panel thêm button "Replace & Paste" ngoài "Copy":
```
┌──────────────────────────────┐
│ I've finished the fix,       │
│ could you redeploy for me?   │
│                              │
│ [📋 Copy] [📝 Replace&Paste]│
└──────────────────────────────┘
```

## Related Code Files
- Create: `FastTranslate/Services/ClipboardService.swift`
- Modify: `FastTranslate/Services/HotkeyManager.swift` (wire ⌃+⌥+V handler)
- Modify: `FastTranslate/Views/FloatingPanelController.swift` (add Replace&Paste button)

## Implementation Steps
1. Tạo `ClipboardService.swift`:
   - `readText() -> String?`
   - `writeText(_ text: String)`
   - `replaceAndPaste(_ text: String)` — write + simulate ⌘+V
2. Wire vào HotkeyManager:
   - `⌃+⌥+V` → `handleTranslateClipboard()`
   - Read clipboard → translate → show floating panel
3. Update FloatingPanelController:
   - Thêm "Replace & Paste" button (chỉ hiện cho clipboard flow)
   - Click → replaceAndPaste → dismiss panel
4. Edge cases:
   - Clipboard rỗng → notification "No text in clipboard"
   - Clipboard chứa image (không phải text) → notification "No text in clipboard"
   - Clipboard chứa text quá dài (>5000 chars) → truncate hoặc warning

## Success Criteria
- [ ] ⌃+⌥+V đọc clipboard và hiện bản dịch
- [ ] "Copy" copy translation vào clipboard
- [ ] "Replace & Paste" thay clipboard + paste vào app đang active
- [ ] Clipboard rỗng → thông báo lỗi, không crash
- [ ] Clipboard không phải text → thông báo lỗi

## Risk Assessment
- **Simulate ⌘+V timing:** Cần đợi clipboard write hoàn tất trước khi simulate paste. Thêm small delay
- **App focus:** Sau khi floating panel dismiss, focus phải trả về app gốc để paste hoạt động
