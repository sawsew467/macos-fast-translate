---
title: "Custom Hotkey Recording"
status: completed
created: 2026-05-05
scope: project
blockedBy: []
blocks: []
---

# Custom Hotkey Recording

Allow users to customize global hotkeys via a native key-recording UI in Settings.

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [Hotkey Data Model & Storage](phase-01-hotkey-data-model.md) | done | P1 | 1h |
| 2 | [Hotkey Recorder NSView](phase-02-hotkey-recorder-view.md) | done | P1 | 2h |
| 3 | [Settings UI Integration](phase-03-settings-ui-integration.md) | done | P1 | 1h |
| 4 | [HotkeyManager Re-registration](phase-04-hotkey-manager-reregistration.md) | done | P1 | 1h |

## Architecture

```
UserDefaults (keyCode + modifiers per action)
       │
       ▼
HotkeyRecorderView ──save──▶ UserDefaults
       │                          │
       │                          ▼
       │              HotkeyManager.reRegister()
       │                 ├─ UnregisterEventHotKey (old)
       │                 └─ RegisterEventHotKey (new)
       ▼
SettingsView (Hotkeys tab)
```

## Key Decisions

- **Storage:** UserDefaults (keyCode: UInt32, modifiers: UInt32) per hotkey action — consistent with existing settings pattern
- **Recording:** NSView-based key recorder wrapped in NSViewRepresentable — SwiftUI can't capture global key events
- **Re-registration:** HotkeyManager gets `reRegister()` that unregisters all + registers with new keycodes
- **Validation:** Prevent duplicate hotkeys, require at least one modifier key
- **Defaults:** Fall back to ⌃⌥T / ⌃⌥S when no custom values stored
