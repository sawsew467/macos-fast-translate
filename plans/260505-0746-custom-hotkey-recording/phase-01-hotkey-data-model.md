---
phase: 1
title: "Hotkey Data Model & Storage"
status: done
priority: P1
effort: "1h"
dependencies: []
---

# Phase 1: Hotkey Data Model & Storage

## Overview
Define a data model for user-customizable hotkeys and persist them in UserDefaults. Provide defaults matching current hardcoded values (⌃⌥T, ⌃⌥S).

## Requirements
- Functional: Store/retrieve keyCode (UInt32) + modifiers (UInt32) per hotkey action
- Functional: Fall back to default keycodes when no custom value stored
- Functional: Provide human-readable display string (e.g. "⌃⌥T") from stored values
- Non-functional: Consistent with existing @AppStorage / UserDefaults pattern

## Architecture
- `HotkeyBinding` struct: `keyCode: UInt32`, `modifiers: UInt32`, computed `displayString`
- `HotkeyAction` enum: `.translate`, `.screenshot` — each has a default binding
- `HotkeyStore` class: reads/writes UserDefaults, publishes changes via Combine/`@Published`

## Related Code Files
- Modify: `FastTranslate/Utils/Constants.swift` — add UserDefaults keys for custom hotkeys
- Create: `FastTranslate/Models/HotkeyBinding.swift` — HotkeyBinding struct + HotkeyAction enum
- Create: `FastTranslate/Services/HotkeyStore.swift` — UserDefaults read/write + ObservableObject

## Implementation Steps
1. Add UserDefaults keys to `Constants.UserDefaultsKey`: `translateHotkeyKeyCode`, `translateHotkeyModifiers`, `screenshotHotkeyKeyCode`, `screenshotHotkeyModifiers`
2. Create `HotkeyBinding` struct with:
   - `keyCode: UInt32`, `modifiers: UInt32`
   - `displayString: String` computed property that converts Carbon modifiers + keyCode to symbols (⌃⌥⌘⇧ + key letter)
   - Static `defaultTranslate` and `defaultScreenshot` presets
3. Create `HotkeyAction` enum (`.translate`, `.screenshot`) with associated default bindings
4. Create `HotkeyStore: ObservableObject` with:
   - `@Published var translateBinding: HotkeyBinding`
   - `@Published var screenshotBinding: HotkeyBinding`
   - `func save(_ binding: HotkeyBinding, for action: HotkeyAction)`
   - `func resetToDefaults()`
   - Init reads from UserDefaults, falls back to defaults
5. Add a static helper to map Carbon keyCode → display character (kVK_ANSI_T → "T", etc.)

## Success Criteria
- [ ] HotkeyBinding can represent any modifier+key combo
- [ ] HotkeyStore reads/writes UserDefaults correctly
- [ ] Default values match current hardcoded ⌃⌥T / ⌃⌥S
- [ ] displayString produces correct symbols

## Risk Assessment
- Carbon keyCode mapping table must cover common keys (A-Z, 0-9, F1-F12, punctuation)
- Missing keys → show raw keyCode as fallback, not crash
