# FastTranslate

A lightweight native macOS menu bar app for instant Vietnamese ↔ English translation, powered by AI.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Why?

If you communicate with English-speaking clients daily but don't write English well, you probably do this a lot:

1. Open ChatGPT/Claude → type Vietnamese → copy translation → paste into chat (**30-60s**)
2. Screenshot client messages → upload to AI → read translation (**30-60s**)
3. End up with tons of junk screenshot files

**FastTranslate reduces this to 3-5 seconds with zero junk files.**

## Features

### Translate Selected Text (`⌃+⌥+T`)
Select text in any app → press hotkey → floating panel shows translation near your cursor.

### Screenshot OCR → Translate (`⌃+⌥+S`)
Press hotkey → drag to select screen region → OCR extracts text → translates automatically. No screenshot files saved to disk.

### Translate Clipboard (`⌃+⌥+V`)
Copy text → press hotkey → see translation → optionally replace clipboard and paste.

### Manual Translation (Click Menu Bar)
Click the menu bar icon → type text with optional context → get translation.

### Smart Context System
Send additional context for more accurate translations:

| Context Type | Description |
|-------------|-------------|
| **Persistent** | Set once in Settings, sent with every translation (e.g., "professional but friendly tone") |
| **Per-message** | Type in the popover for a specific translation (e.g., "discussing a production bug") |
| **Screenshot** | Capture a wider area — AI uses the full conversation as context |

## Installation

### Prerequisites
- macOS 14 (Sonoma) or later
- [OpenAI API key](https://platform.openai.com/api-keys)

### Build from Source
```bash
# Clone
git clone https://github.com/YOUR_USERNAME/macos-fast-translate.git
cd macos-fast-translate

# Generate Xcode project
xcodegen generate

# Open in Xcode
open FastTranslate.xcodeproj

# Build & Run (⌘+R)
```

### First Launch
1. Enter your OpenAI API key
2. Grant **Accessibility** permission (for global hotkeys + reading selected text)
3. Grant **Screen Recording** permission (for screenshot OCR)

## Usage

| Shortcut | Action |
|----------|--------|
| `⌃+⌥+T` | Translate selected text |
| `⌃+⌥+S` | Screenshot region → OCR → translate |
| `⌃+⌥+V` | Translate clipboard content |
| `⌘+,` | Open Settings |

All shortcuts are customizable in Settings.

## Cost

Uses **GPT-4o-mini** by default — extremely cheap:

| Usage | Monthly Cost |
|-------|-------------|
| 50 messages/day | ~$0.15 |
| 100 messages/day | ~$0.30 |
| 200 messages/day | ~$0.60 |

Optionally switch to **Claude Sonnet** for complex/nuanced translations.

## Tech Stack

- **Swift + SwiftUI + AppKit** — pure native, ~10MB, no Electron
- **GPT-4o-mini** — fast, cheap, natural translations
- **Apple Vision** — offline OCR, supports Vietnamese
- **Zero external dependencies** — all Apple native frameworks

## Permissions

| Permission | Why |
|-----------|-----|
| Accessibility | Read selected text via simulated ⌘+C, register global hotkeys |
| Screen Recording | Capture screen regions for OCR |

## Contributing

Contributions are welcome! Please read the docs:

- [`docs/product-overview.md`](docs/product-overview.md) — product features and use cases
- [`docs/system-architecture.md`](docs/system-architecture.md) — architecture and data flows
- [`docs/code-standards.md`](docs/code-standards.md) — coding conventions
- [`docs/tech-stack.md`](docs/tech-stack.md) — technology choices

## License

MIT
