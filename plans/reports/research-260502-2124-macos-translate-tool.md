# Research Report: macOS Fast Translate Tool

## Problem
User translates Vi↔En daily via ChatGPT/Claude manually. Workflow: type Vietnamese → AI translate → copy/paste to client chat. Reverse for reading. Creates junk screenshots. Very repetitive.

## Key Findings

### macOS Menu Bar App Architecture
- **Swift + SwiftUI + AppKit hybrid** — best for utility tools
- `NSStatusItem` for menu bar, `LSUIElement = true` hides dock icon
- Global hotkeys via `CGEventTap` or `KeyboardShortcuts` library (sindresorhus)
- Needs Accessibility + Screen Recording permissions
- **Direct distribution (DMG)** preferred — App Store sandbox blocks global hotkeys + screen capture
- Reference projects: [ShotX](https://github.com/aimen08/shotx), [ShotBar](https://github.com/aneesahammed/shotbar), [macshot](https://github.com/sw33tLie/macshot)

### OCR — Vision Framework
- **Vietnamese (`vi-VT`) supported** since macOS 14.4 (Sonoma)
- `VNRecognizeTextRequest` with `.accurate` level — works offline, free
- ScreenCaptureKit (macOS 12.3+) for modern screen capture with region selection
- No external dependency needed

### Translation API Comparison

| Provider | Vietnamese | Quality | Speed | Cost |
|----------|-----------|---------|-------|------|
| Claude API (Haiku) | Yes | Excellent contextual | ~1-2s | ~$0.25/1M input tokens |
| OpenAI (GPT-4o-mini) | Yes | Good | ~1s | ~$0.15/1M input |
| Google Translate | Yes | Good general | <0.5s | $20/1M chars |
| DeepL | **No** | N/A | N/A | N/A |
| Apple Translation | Yes (macOS 14+) | Decent | Instant | Free/offline |

- **Recommendation:** Multi-provider. Default: Google Translate (fast+cheap for simple msgs). Optional: Claude/OpenAI for contextual translation. Apple Translation as offline fallback.
- DeepL excluded — no Vietnamese support.

## Recommended Tech Stack
- **Language:** Swift 5.9+
- **UI:** SwiftUI (popover/panel) + AppKit (system integration)
- **OCR:** Apple Vision framework (native, free, Vi supported)
- **Screen Capture:** ScreenCaptureKit
- **Translation:** Google Translate (default) + Claude API (quality) + Apple Translation (offline)
- **Hotkeys:** KeyboardShortcuts or CGEventTap
- **Clipboard:** NSPasteboard
- **Min target:** macOS 14 (Sonoma)
- **Distribution:** Direct DMG, notarized

## Core Features (MVP)
1. Menu bar app — always accessible, lightweight
2. Global hotkey → translate selected text (auto-detect Vi↔En)
3. Screenshot region → OCR → translate
4. Translate clipboard content
5. Floating popup shows result, one-click copy
6. Translation history (recent 50)

## Unresolved Questions
- Which Google Translate approach? Official API (paid) vs free endpoint?
- Should we support custom prompts for Claude translation (e.g., formal/informal tone)?
