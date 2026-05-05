---
phase: 2
title: "Hotkey Recorder NSView"
status: done
priority: P1
effort: "2h"
dependencies: [1]
---

# Phase 2: Hotkey Recorder NSView

## Overview
Build a native key-recording component: user clicks the field, presses a key combo, the field captures and displays it. Requires NSView because SwiftUI cannot intercept raw key events with modifier flags.

## Requirements
- Functional: Click to enter recording mode, press key combo to capture, Escape to cancel
- Functional: Display current binding as symbols (⌃⌥T), show "Record shortcut..." when recording
- Functional: Require at least one modifier (⌃/⌥/⌘/⇧) — reject bare letter keys
- Functional: Visual feedback for recording state (highlighted border, pulsing text)
- Non-functional: Wrap in NSViewRepresentable for SwiftUI integration

## Architecture
```
HotkeyRecorderView (SwiftUI)
  └─ NSViewRepresentable
       └─ HotkeyRecorderNSView (NSView subclass)
            ├─ keyDown() → capture keyCode + modifiers
            ├─ flagsChanged() → show live modifier preview
            └─ resignFirstResponder() → cancel recording
```

## Related Code Files
- Create: `FastTranslate/Views/HotkeyRecorderView.swift` — NSView + NSViewRepresentable wrapper

## Implementation Steps
1. Create `HotkeyRecorderNSView: NSView` subclass:
   - Properties: `isRecording: Bool`, `currentBinding: HotkeyBinding?`, `onRecord: (HotkeyBinding) -> Void`
   - Override `acceptsFirstResponder` → true
   - Override `becomeFirstResponder` → set `isRecording = true`, update visual
   - Override `resignFirstResponder` → set `isRecording = false`, cancel recording
   - Override `keyDown(with:)` → extract `event.keyCode` + `event.modifierFlags`, validate has modifier, call `onRecord`, resign first responder
   - Override `flagsChanged(with:)` → show live modifier preview while recording (e.g. "⌃⌥..." as user holds keys)
   - Handle Escape key → cancel recording, restore previous binding
   - Handle Delete/Backspace → clear binding (optional: allow unsetting)
   - `draw(_ rect:)` → render rounded rect background, binding text or "Record shortcut..." placeholder
2. Create `HotkeyRecorderView: NSViewRepresentable`:
   - `@Binding var binding: HotkeyBinding`
   - `makeNSView` → create HotkeyRecorderNSView
   - `updateNSView` → sync binding changes
   - Coordinator handles `onRecord` callback → update binding
3. Convert Carbon modifier flags from NSEvent.modifierFlags:
   - `.control` → `controlKey`
   - `.option` → `optionKey`
   - `.command` → `cmdKey`
   - `.shift` → `shiftKey`

## Success Criteria
- [ ] Click field → enters recording mode with visual change
- [ ] Press modifier+key → captures and displays correctly
- [ ] Bare key (no modifier) → rejected, stays in recording mode
- [ ] Escape → cancels recording
- [ ] Click outside → cancels recording
- [ ] Displays current binding symbols when not recording

## Risk Assessment
- NSView focus management in a SwiftUI settings window can be tricky — test first responder chain
- Modifier-only combos (e.g. just ⌃⌥ without a letter) should be rejected — need a real key
