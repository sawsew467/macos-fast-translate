# Tech Stack

## Language & Platform
- **Swift 5.9+** — native macOS development
- **macOS 14+ (Sonoma)** — minimum deployment target
- **Xcode 15+** — build toolchain
- **XcodeGen** — generate Xcode project from YAML

## UI Framework
- **SwiftUI** — popover views, settings panel, translation results
- **AppKit** — menu bar (`NSStatusItem`), floating panel (`NSWindow`), system integration

## Core Apple Frameworks
- **Vision** — OCR text extraction (`VNRecognizeTextRequest`, supports Vietnamese `vi-VT`)
- **ScreenCaptureKit** — region-based screen capture (fallback: `CGWindowListCreateImage`)
- **NSPasteboard** — clipboard read/write
- **Carbon.HIToolbox** — global keyboard shortcuts (`RegisterEventHotKey`)
- **ServiceManagement** — launch at login (`SMAppService`)
- **Security** — Keychain API key storage

## Translation Providers
- **GPT-4o-mini (OpenAI API)** — default, fast, cheap (~$0.3/tháng), dịch tự nhiên
- **Claude Sonnet (Anthropic API)** — optional, cho văn bản phức tạp

## Context System
- **Persistent context** — set 1 lần trong Settings, gửi kèm mọi bản dịch
- **Per-message context** — user gõ trong popover cho 1 lần dịch cụ thể
- **Screenshot context** — OCR vùng rộng, toàn bộ text làm context cho bản dịch

## Architecture
- Menu bar-only app (no dock icon, `LSUIElement = true`)
- Provider protocol for swappable translation backends
- Async/await for all network + OCR operations
- No external dependencies — 100% Apple native frameworks

## Distribution
- Direct download (DMG) — avoids App Store sandbox restrictions
- Apple notarization required
- Pure native Swift — no Electron, no web tech (~10MB)
