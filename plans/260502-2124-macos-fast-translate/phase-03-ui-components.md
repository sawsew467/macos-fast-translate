---
phase: 3
title: "UI Components"
status: completed
priority: P0
effort: "4h"
dependencies: [1, 2]
---

# Phase 3: UI Components

## Overview
Popover UI chính từ menu bar: input text, context box, output, copy button, provider picker. Và floating panel hiển thị kết quả dịch khi dùng hotkey.

## Requirements
- **Functional:**
  - Popover mở từ menu bar icon
  - Input text area (editable, auto-focus)
  - Context box (tùy chọn, collapsible)
  - Output text area (read-only, selectable)
  - Copy to clipboard button
  - Swap language button (Vi↔En)
  - Provider selector (GPT-4o-mini / Claude)
  - Loading spinner khi đang dịch
  - Floating panel hiện kết quả gần cursor (cho hotkey flow)
- **Non-functional:**
  - Keyboard-driven: Enter dịch, ⌘+C copy kết quả
  - Responsive, không lag
  - Popover size: ~380x400

## Architecture

### Files
```
Views/
├── TranslationPopoverView.swift     # Main popover (1 file, SwiftUI)
└── FloatingPanelController.swift    # Floating result panel (AppKit)
```

Giữ đơn giản — 1 file cho popover (SwiftUI), 1 file cho floating panel (AppKit). Không split nhỏ hơn trừ khi vượt 200 dòng.

### Popover Layout
```
┌──────────────────────────────────┐
│ [Vi → En ⇄]         [GPT-4o ▼]  │
├──────────────────────────────────┤
│ 📎 Context (tap to expand):     │
│ ┌──────────────────────────────┐ │
│ │ "discussing production bug"  │ │
│ └──────────────────────────────┘ │
├──────────────────────────────────┤
│ Input:                           │
│ ┌──────────────────────────────┐ │
│ │ Em đã fix xong rồi, anh     │ │
│ │ deploy lại giúp em nhé       │ │
│ └──────────────────────────────┘ │
├──────────────────────────────────┤
│ Translation:                     │
│ ┌──────────────────────────────┐ │
│ │ I've finished the fix, could │ │
│ │ you redeploy for me?         │ │
│ └──────────────────────────────┘ │
├──────────────────────────────────┤
│ [📋 Copy]   [✕ Clear]   [⏱ 50] │
└──────────────────────────────────┘
```

### Popover SwiftUI Structure
```swift
struct TranslationPopoverView: View {
    @EnvironmentObject var translationService: TranslationService
    @State private var inputText = ""
    @State private var contextText = ""
    @State private var showContext = false

    var body: some View {
        VStack(spacing: 8) {
            // 1. Header: language direction + provider picker
            headerBar

            // 2. Context box (collapsible)
            if showContext {
                contextEditor
            }

            // 3. Input text editor
            inputEditor

            // 4. Translate button or auto-translate
            // (translate on Enter key press)

            // 5. Output display
            outputDisplay

            // 6. Footer: copy, clear, history count
            footerBar
        }
        .padding(12)
        .frame(width: 380, height: showContext ? 420 : 340)
    }
}
```

### Floating Panel (cho hotkey flow)
```swift
/// Borderless floating window hiện kết quả dịch gần cursor
class FloatingPanelController {
    private var window: NSWindow?

    /// Hiện panel tại vị trí cursor
    func show(result: TranslationResult, near: NSPoint) {
        // 1. Create borderless NSWindow (NSWindow.StyleMask = [])
        // 2. Set window level = .floating
        // 3. Position near cursor point
        // 4. Show SwiftUI content: translated text + copy button
        // 5. Auto-dismiss after 10s or on click-copy
        // 6. Click anywhere else → dismiss
    }

    func dismiss() { ... }
}
```

### Floating Panel Layout
```
┌─────────────────────────────┐
│ I've finished the fix,      │
│ could you redeploy for me?  │
│                             │
│ [📋 Copy]  [Vi→En · GPT-4o]│
└─────────────────────────────┘
  ↑ Hiện gần cursor, auto-dismiss 10s
```

## Related Code Files
- Create: `FastTranslate/Views/TranslationPopoverView.swift`
- Create: `FastTranslate/Views/FloatingPanelController.swift`
- Modify: `FastTranslate/App/AppDelegate.swift` (wire popover + floating panel)

## Implementation Steps
1. Tạo `TranslationPopoverView.swift`:
   - Header bar: language swap button + provider Picker
   - Context disclosure group (collapsible TextEditor)
   - Input TextEditor với placeholder text
   - Output text display (selectable, read-only)
   - Footer: Copy button, Clear button, history count badge
2. Wire vào AppDelegate:
   - NSPopover.contentViewController = NSHostingController(rootView: TranslationPopoverView)
   - EnvironmentObject: TranslationService
3. Keyboard shortcuts trong popover:
   - Enter (hoặc ⌘+Enter): trigger translate
   - ⌘+C khi output focused: copy translation
   - Escape: close popover
4. Loading state: ProgressView overlay khi translationService.isTranslating
5. Error state: Text đỏ hiện error message
6. Tạo `FloatingPanelController.swift`:
   - NSWindow borderless, `.floating` level
   - Content: SwiftUI view với translated text + copy button
   - Position: NSEvent.mouseLocation offset
   - Auto-dismiss timer 10s
   - Click copy → copy to clipboard + dismiss
   - Click outside → dismiss
7. Expose FloatingPanelController trong AppDelegate cho hotkey flow (Phase 4)

## Success Criteria
- [ ] Popover mở/đóng từ menu bar icon
- [ ] Gõ text → Enter → hiện bản dịch
- [ ] Context box expand/collapse, text được gửi kèm khi dịch
- [ ] Copy button copy translation vào clipboard
- [ ] Clear button xóa input + output
- [ ] Provider picker chuyển đổi GPT-4o / Claude
- [ ] Loading spinner hiện khi đang dịch
- [ ] Error message hiện khi lỗi (đỏ)
- [ ] Floating panel hiện gần cursor, auto-dismiss 10s
- [ ] Floating panel click copy → copy + dismiss

## Risk Assessment
- **NSPopover + SwiftUI:** Đôi khi focus bị mất khi mở popover. Fix: `popover.contentViewController?.view.window?.makeKey()`
- **Floating panel positioning:** Cần handle edge cases (cursor gần mép màn hình). Adjust position để panel không bị cắt
- **TextEditor placeholder:** SwiftUI TextEditor không có native placeholder. Dùng overlay Text khi input rỗng
