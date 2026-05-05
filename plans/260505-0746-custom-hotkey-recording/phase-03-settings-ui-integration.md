---
phase: 3
title: "Settings UI Integration"
status: done
priority: P1
effort: "1h"
dependencies: [1, 2]
---

# Phase 3: Settings UI Integration

## Overview
Replace the read-only Hotkeys tab with interactive hotkey recorders and a reset button, using the existing SettingsCard/SettingsPage design system.

## Requirements
- Functional: Each hotkey action shows a HotkeyRecorderView with current binding
- Functional: "Reset to Defaults" button restores ⌃⌥T / ⌃⌥S
- Functional: Duplicate detection — warn if two actions use the same combo
- Non-functional: Match existing SettingsView visual style

## Related Code Files
- Modify: `FastTranslate/Views/SettingsView.swift` — rewrite `HotkeysSettingsTab`, update `HotkeyRow`

## Implementation Steps
1. Update `HotkeysSettingsTab`:
   - Add `@StateObject private var hotkeyStore = HotkeyStore.shared`
   - Replace static `HotkeyRow` with `HotkeyRecorderView` bound to store bindings
   - Keep existing `SettingsCard` wrapper with updated subtitle (remove "planned for later")
2. Update each row to show:
   - Left: icon + action label (same as current)
   - Right: `HotkeyRecorderView` bound to the action's binding
3. Add "Reset to Defaults" button at bottom using existing `SettingsButton` component
4. Add duplicate detection:
   - After recording, check if new binding conflicts with other action
   - Show inline warning text if duplicate detected
   - Still allow saving (user may want to change the other one next)
5. Remove old `HotkeyRow` view (replaced by recorder rows)

## Success Criteria
- [ ] Hotkeys tab shows interactive recorders instead of static text
- [ ] "Customization is planned for later" text removed
- [ ] Reset to Defaults button works
- [ ] Duplicate hotkey shows warning
- [ ] Visual style matches other settings tabs

## Risk Assessment
- HotkeyRecorderView (NSView) inside SettingsCard (SwiftUI) — may need frame sizing adjustments
