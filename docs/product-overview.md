# FastTranslate — Product Overview

## What is it?
A native macOS menu bar app for instant Vietnamese ↔ English translation. Powered by GPT-4o-mini with real-time streaming, smart context system, and screenshot OCR — all accessible via global hotkeys without leaving your current app.

## Problem
Vietnamese professionals communicating with English-speaking clients daily face a slow, repetitive workflow:

1. Open ChatGPT → type Vietnamese → copy translation → paste into chat (**30-60s per message**)
2. Screenshot client messages → upload to AI → read translation (**30-60s per message**)
3. Desktop cluttered with junk screenshot files

**FastTranslate reduces each translation to 2-3 seconds with zero context switching and zero junk files.**

## Target Users
- Vietnamese professionals working with English-speaking clients or colleagues
- Developers, freelancers, support staff, sales teams
- Anyone who needs fast, natural AI translation integrated into their daily workflow

## Core Features

### 1. Translate Selected Text (default `⌃⌥T`)
Select text in **any app** → press hotkey → floating panel streams the translation near your cursor.

Works both ways: select Vietnamese text to translate to English, or select English text to translate to Vietnamese. Smart multilingual detection auto-switches target language.

### 2. Screenshot OCR → Translate (default `⌃⌥S`)
Press hotkey → drag to select a screen region → Vision OCR extracts text → translation streams instantly.

- No screenshot files saved to disk (processed in memory)
- Capture a wider area (full chat thread) for better context-aware translation

### 3. Customizable Hotkeys
Rebind translate and screenshot shortcuts to any key combination in Settings → Hotkeys.

### 4. Menu Bar Popover
Click the menu bar icon → type or paste text with optional context → get translation. Best for longer passages or when you need specific context.

## Smart Context System

A key advantage over Google Translate: provide **context** for more accurate, natural translations.

| Context Layer | How to Use | Example |
|:-------------|:-----------|:--------|
| **Persistent** | Set once in Settings, sent with every translation | "Professional but friendly tone" |
| **Per-message** | Type in the popover for a specific translation | "Discussing a production database bug" |
| **Screenshot** | Capture a wider area — AI uses the full text as context | Capture the entire chat thread, not just one message |

**Real-world example:**
- Without context: "Em deploy lại giúp em" → "Please help me deploy again" (generic)
- With context "production server bug fix": "Em deploy lại giúp em" → "Could you redeploy the fix for me?" (accurate)

## Technical Highlights
- **Native macOS** — Swift + SwiftUI + AppKit, ~10MB binary, no Electron
- **Real-time streaming** — translations appear token-by-token via SSE
- **Offline OCR** — Apple Vision framework, supports Vietnamese and English
- **Auto language detection** — type Vietnamese → translates to English, and vice versa
- **Global hotkeys** — work from any app via Carbon Events API
- **Zero junk files** — screenshots processed in memory
- **Low cost** — ~$0.30/month with GPT-4o-mini at 100 translations/day
- **Zero external dependencies** — 100% Apple native frameworks

## System Requirements
- macOS 13 (Ventura) or later
- OpenAI API key
- Accessibility permission (for global hotkeys + reading selected text)
- Screen Recording permission (for screenshot OCR)

## Keyboard Shortcuts

| Shortcut | Action |
|:---------|:-------|
| `⌃⌥T` (default) | Translate selected text |
| `⌃⌥S` (default) | Screenshot region → OCR → translate |
| `⌘,` | Open Settings |

All hotkeys are customizable in Settings → Hotkeys.
