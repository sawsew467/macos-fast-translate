---
phase: 4
title: "HotkeyManager Re-registration"
status: done
priority: P1
effort: "1h"
dependencies: [1, 3]
---

# Phase 4: HotkeyManager Re-registration

## Overview
Wire HotkeyManager to read bindings from HotkeyStore and support live re-registration when user changes hotkeys in Settings.

## Requirements
- Functional: On launch, register hotkeys from HotkeyStore (not hardcoded Constants)
- Functional: When user changes a hotkey in Settings, unregister old + register new immediately
- Functional: If registration fails (key conflict with system), show error in Settings UI
- Non-functional: No app restart required for hotkey changes

## Architecture
```
HotkeyStore (publishes changes)
     │
     ▼ Combine sink / observation
HotkeyManager.reRegister()
  ├─ UnregisterEventHotKey(old refs)
  ├─ RegisterEventHotKey(new keyCode, new modifiers)
  └─ Report success/failure back
```

## Related Code Files
- Modify: `FastTranslate/Services/HotkeyManager.swift` — add reRegister(), read from HotkeyStore
- Modify: `FastTranslate/App/AppDelegate.swift` — pass HotkeyStore to HotkeyManager, observe changes
- Modify: `FastTranslate/Utils/Constants.swift` — keep HotkeyCode/HotkeyIDs as defaults only

## Implementation Steps
1. Update `HotkeyManager.register()`:
   - Read keyCode/modifiers from `HotkeyStore.shared` instead of `Constants.HotkeyCode`
   - Store mapping of hotkey ID → `EventHotKeyRef` for targeted unregistration
2. Add `HotkeyManager.reRegister()`:
   - Unregister all existing hotkeys (iterate `hotkeyRefs`, call `UnregisterEventHotKey`)
   - Clear refs array
   - Re-read from HotkeyStore and register fresh
   - Return success/failure per hotkey
3. Update `registerHotkey()` signature to accept modifiers parameter (currently hardcoded `controlKey | optionKey`)
4. In `AppDelegate.setupHotkeys()`:
   - Subscribe to `HotkeyStore.shared.$translateBinding` and `$screenshotBinding`
   - On change → call `hotkeyManager?.reRegister()`
5. Handle registration failures:
   - If `RegisterEventHotKey` returns error → HotkeyStore publishes error state
   - Settings UI shows inline error on the affected row

## Success Criteria
- [ ] App launch uses stored custom hotkeys (not hardcoded)
- [ ] Changing hotkey in Settings takes effect immediately
- [ ] Old hotkey stops working after change
- [ ] New hotkey works without app restart
- [ ] Registration failure shows feedback in Settings

## Risk Assessment
- Carbon `RegisterEventHotKey` can fail silently if another app holds the same combo — need to check return status
- Race condition: user rapidly changes hotkeys — debounce reRegister calls or use serial queue
