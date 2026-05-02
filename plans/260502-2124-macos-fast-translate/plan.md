# Plan: macOS Fast Translate

## Overview
Native macOS menu bar app dịch nhanh Vietnamese ↔ English. Dùng GPT-4o-mini cho dịch thuật tự nhiên, Vision framework cho OCR. Global hotkeys để dịch text đang chọn, chụp màn hình OCR, và dịch clipboard — không cần mở browser hay AI chat.

## Problem
User dịch Vi↔En hàng ngày qua ChatGPT/Claude thủ công: gõ tiếng Việt → copy bản dịch → paste vào chat khách. Đọc tin khách thì chụp ảnh → upload AI → đọc dịch. Tạo nhiều ảnh rác, tốn 30-60s/lần.

## Solution
Menu bar app với hotkey dịch tức thì (~3-5s), hỗ trợ context để dịch chính xác hơn.

## Phases

| # | Phase | Status | Priority | Description |
|---|-------|--------|----------|-------------|
| 1 | Project Setup | completed | P0 | Xcode project (XcodeGen), menu bar scaffold, Info.plist |
| 2 | Translation Engine | completed | P0 | TranslationProvider protocol, GPT-4o-mini, language detection |
| 3 | UI Components | completed | P0 | Popover view with context box, translation result, copy |
| 4 | Global Hotkeys | pending | P0 | ⌃+⌥+T/S/V, selected text reader, floating result panel |
| 5 | Screenshot OCR | pending | P1 | Region capture → Vision OCR → translate pipeline |
| 6 | Clipboard Integration | pending | P2 | Translate clipboard content, replace with translation |
| 7 | Settings & Polish | pending | P2 | Persistent context, API key, history, launch at login |

## Key Decisions
- **Default provider:** GPT-4o-mini (~$0.3/tháng cho 100 tin/ngày)
- **Optional provider:** Claude Sonnet (cho văn bản phức tạp)
- **3 loại context:** persistent (Settings), per-message (popover), screenshot (OCR vùng rộng)
- **Hotkeys:** ⌃+⌥+T (translate), ⌃+⌥+S (screenshot OCR), ⌃+⌥+V (clipboard) — configurable
- **OCR:** Vision framework (native, miễn phí, hỗ trợ tiếng Việt từ macOS 14)
- **Không dùng lib bên ngoài** — toàn bộ native Apple frameworks
- **Distribution:** Direct DMG (không App Store — sandbox chặn global hotkey + screen capture)

## Tech Stack
- **Swift 5.9+** / **SwiftUI** + **AppKit**
- **Vision** framework (OCR)
- **ScreenCaptureKit** (chụp màn hình)
- **Carbon.HIToolbox** (global hotkeys)
- **OpenAI API** (GPT-4o-mini translation)
- **XcodeGen** (tạo Xcode project)
- **macOS 14+ (Sonoma)** minimum target

## Project Structure
```
FastTranslate/
├── App/
│   ├── FastTranslateApp.swift         # @main entry point
│   └── AppDelegate.swift              # NSStatusItem, popover, hotkey setup
├── Models/
│   └── TranslationModels.swift        # Language, TranslationResult, ProviderType
├── Views/
│   ├── TranslationPopoverView.swift   # Main popover UI
│   ├── FloatingPanelController.swift  # Floating result near cursor
│   └── SettingsView.swift             # Settings window
├── Services/
│   ├── TranslationProvider.swift      # Protocol definition
│   ├── OpenAITranslationProvider.swift # GPT-4o-mini implementation
│   ├── TranslationService.swift       # Service coordinator + context management
│   ├── LanguageDetector.swift         # Vi/En auto-detection
│   ├── HotkeyManager.swift            # Global hotkey registration (Carbon)
│   ├── SelectedTextReader.swift       # Read selected text via simulated ⌘+C
│   ├── OCRService.swift               # Vision framework OCR
│   ├── ScreenCaptureService.swift     # Region selection + capture
│   └── ClipboardService.swift         # NSPasteboard read/write
├── Utils/
│   └── Constants.swift                # App constants, UserDefaults keys
└── Resources/
    ├── Info.plist                      # LSUIElement=true, permissions
    ├── FastTranslate.entitlements      # App sandbox disabled
    └── Assets.xcassets/               # App icon, menu bar icon
```

## Dependencies
- macOS 14+ SDK (Xcode 15+)
- OpenAI API key (required)
- Accessibility permission (global hotkeys, read selected text)
- Screen Recording permission (screenshot OCR)

## Files
- [Phase 1: Project Setup](phase-01-project-setup.md)
- [Phase 2: Translation Engine](phase-02-translation-engine.md)
- [Phase 3: UI Components](phase-03-ui-components.md)
- [Phase 4: Global Hotkeys](phase-04-global-hotkeys.md)
- [Phase 5: Screenshot OCR](phase-05-screenshot-ocr.md)
- [Phase 6: Clipboard Integration](phase-06-clipboard-integration.md)
- [Phase 7: Settings & Polish](phase-07-polish-settings.md)
