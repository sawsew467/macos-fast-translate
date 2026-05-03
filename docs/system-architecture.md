# System Architecture

## App Type
macOS menu bar-only app (no dock icon, no main window). Luôn chạy nền, truy cập qua icon trên menu bar hoặc global hotkeys.

## High-Level Architecture
```
┌─────────────────────────────────────────────────┐
│                    macOS                         │
│                                                  │
│  ┌──────────────┐  ┌────────────────────────┐   │
│  │  Menu Bar     │  │  Any App (Chrome,      │   │
│  │  Icon ⌘click  │  │  Slack, VSCode...)     │   │
│  └──────┬───────┘  └──────────┬─────────────┘   │
│         │                      │                  │
│         ▼                      │ ⌃+⌥+T/S/V       │
│  ┌──────────────┐              ▼                  │
│  │   Popover    │    ┌──────────────────┐         │
│  │   (SwiftUI)  │    │  HotkeyManager   │         │
│  │              │    │  (Carbon API)    │         │
│  │ Input+Context│    └────────┬─────────┘         │
│  │ Output+Copy  │             │                   │
│  └──────┬───────┘             │                   │
│         │                     │                   │
│         ▼                     ▼                   │
│  ┌─────────────────────────────────────┐         │
│  │         TranslationService          │         │
│  │  - Language detection               │         │
│  │  - Context merging (3 layers)       │         │
│  │  - Provider coordination            │         │
│  │  - History management               │         │
│  └──────────────┬──────────────────────┘         │
│                 │                                  │
│       ┌─────────┼──────────┐                      │
│       ▼         ▼          ▼                      │
│  ┌──────────────────┐  ┌──────────┐              │
│  │ OpenAI GPT-4o    │  │  OCR     │              │
│  │ -mini (SSE       │  │ Service  │              │
│  │  streaming)      │  │ (Vision) │              │
│  └──────────────────┘  └──────────┘              │
│                                                   │
│  ┌─────────────────────────────────────┐         │
│  │         FloatingPanelController     │         │
│  │  Borderless window near cursor      │         │
│  │  Copy / Replace&Paste / Auto-dismiss│         │
│  └─────────────────────────────────────┘         │
└─────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| **FastTranslateApp** | `App/FastTranslateApp.swift` | @main entry, SwiftUI lifecycle |
| **AppDelegate** | `App/AppDelegate.swift` | NSStatusItem, NSPopover, wiring |
| **TranslationService** | `Services/TranslationService.swift` | Translation coordinator, context merging, history |
| **TranslationProvider** | `Services/TranslationProvider.swift` | Protocol for swappable backends |
| **OpenAITranslationProvider** | `Services/OpenAITranslationProvider.swift` | GPT-4o-mini API calls |
| **LanguageDetector** | `Services/LanguageDetector.swift` | Vi/En detection via Unicode analysis |
| **HotkeyManager** | `Services/HotkeyManager.swift` | Carbon global hotkey registration |
| **SelectedTextReader** | `Services/SelectedTextReader.swift` | Read selected text via simulated ⌘+C |
| **OCRService** | `Services/OCRService.swift` | Vision framework text recognition |
| **ScreenCaptureService** | `Services/ScreenCaptureService.swift` | Region selection overlay + capture |
| **ClipboardService** | `Services/ClipboardService.swift` | NSPasteboard read/write |
| **TranslationPopoverView** | `Views/TranslationPopoverView.swift` | Main popover UI |
| **StreamingTranslationState** | `Models/StreamingTranslationState.swift` | Observable state for streaming panel (loading → tokens → done) |
| **FloatingPanelController** | `Views/FloatingPanelController.swift` | Floating result window (static + streaming modes) |
| **SettingsView** | `Views/SettingsView.swift` | Settings window with tabs |

## Data Flow

### 1. Popover Translation (manual)
```
User types text in popover
  → Enter key
  → TranslationService.translate(text, perMessageContext)
    → LanguageDetector.detect(text) → Vi or En
    → Merge context (persistent + perMessage)
    → OpenAITranslationProvider.translate(...)
      → POST api.openai.com/v1/chat/completions
    → Return TranslationResult
  → Display in popover output area
```

### 2. Hotkey Translation (⌃+⌥+T) — Streaming
```
User selects text in any app → ⌃+⌥+T
  → HotkeyManager receives Carbon event
  → SelectedTextReader.readSelectedText()
    → AX API (primary) or clipboard simulation (fallback)
  → TranslationService.translateStreaming(text)
    → Returns (source, target, AsyncThrowingStream)
  → FloatingPanelController.showStreaming(state, near: cursor) ← instant
  → for await chunk in stream → state.streamedText += chunk ← progressive
  → TranslationService.addToHistory(result) ← after stream done
```

### 3. Screenshot OCR Translation (⌃+⌥+S) — Streaming
```
User presses ⌃+⌥+S
  → ScreenCaptureService.captureRegion()
    → Fullscreen overlay → user drags selection → CGImage
  → OCRService.recognizeText(cgImage)
    → VNRecognizeTextRequest → extracted text
  → TranslationService.translateStreaming(text)
  → FloatingPanelController.showStreaming(state, near: cursor) ← instant
  → for await chunk in stream → state.streamedText += chunk ← progressive
```


## Context System (3 Layers)
```
TranslationContext {
  persistent    ← Settings (always sent, e.g. "professional tone")
  perMessage    ← Popover context box (one-time, user types for specific translation)
  screenshot    ← OCR full text (conversation context from screenshot)
}
```
All 3 merged into system prompt sent to GPT-4o-mini.

## Permissions Required
| Permission | Why | When Requested |
|------------|-----|----------------|
| **Accessibility** | Simulate ⌘+C to read selected text, global hotkeys | First hotkey use |
| **Screen Recording** | Capture screen region for OCR | First screenshot OCR use |

## Storage
| Data | Location | Format |
|------|----------|--------|
| API keys | macOS Keychain | Secure |
| Settings | UserDefaults | @AppStorage |
| Translation history | ~/Library/Application Support/FastTranslate/history.json | JSON |
