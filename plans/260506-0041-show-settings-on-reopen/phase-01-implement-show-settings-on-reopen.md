---
phase: 1
title: "Implement show-settings-on-reopen"
status: pending
priority: P2
effort: "1h"
dependencies: []
---

# Phase 1: Implement show-settings-on-reopen

## Overview

Add logic to AppDelegate so that the Settings window (About tab) opens when the user manually launches or reopens the app, but NOT when it's auto-launched as a login item.

## Requirements

- Functional:
  - When user clicks app icon (Spotlight/Finder) while app is already running -> show Settings -> About tab
  - When user opens app from Applications/Spotlight (fresh launch, post-onboarding) -> show Settings -> About tab
  - Login-item auto-launch at login -> do NOT show Settings, stay silent in menu bar
- Non-functional:
  - No flicker or double-window on first launch with onboarding
  - Settings window reuses existing `openSettings()` + `.openAboutTab` notification

## Architecture

```
applicationDidFinishLaunching
  -> checkFirstLaunch() (existing - shows onboarding if needed)
  -> NEW: if onboarding done AND not login-item launch -> openSettingsOnAboutTab()

applicationShouldHandleReopen(_:hasVisibleWindows:)
  -> NEW: if no visible windows -> openSettingsOnAboutTab()
```

**Login-item detection:** Use Apple Events API to check if the launch was triggered by SMAppService login item:
```swift
private var isLaunchedAsLoginItem: Bool {
    guard let event = NSAppleEventManager.shared().currentAppleEvent,
          let propData = event.paramDescriptor(forKeyword: keyAEPropData)
    else { return false }
    return propData.enumCodeValue == UInt32(keyAELaunchedAsLogInItem)
}
```

## Related Code Files

- Modify: `FastTranslate/App/AppDelegate.swift`

## Implementation Steps

1. Add `applicationShouldHandleReopen(_:hasVisibleWindows:)` to AppDelegate:
   - If `hasVisibleWindows` is false, call `openSettings()` then post `.openAboutTab` notification
   - Return `true`

2. Add `isLaunchedAsLoginItem` computed property using Apple Events:
   - Check `NSAppleEventManager.shared().currentAppleEvent` for `keyAEPropData`
   - Compare against `keyAELaunchedAsLogInItem`

3. Modify `applicationDidFinishLaunching`:
   - After `checkFirstLaunch()`, add:
   - If `hasLaunchedBefore == true` (onboarding done) AND `!isLaunchedAsLoginItem` -> call `openSettings()` + post `.openAboutTab`

4. Extract shared helper `openSettingsOnAboutTab()` to avoid duplication between the two entry points

5. Build and verify:
   - Manual launch from Xcode -> Settings/About should appear
   - Kill app -> open from Applications -> Settings/About should appear
   - Verify onboarding flow still works (reset `hasLaunchedBefore` to test)

## Success Criteria

- [ ] `applicationShouldHandleReopen` shows Settings -> About when no windows visible
- [ ] Fresh manual launch (post-onboarding) shows Settings -> About
- [ ] Login-item launch does NOT show Settings
- [ ] Onboarding flow unaffected (first launch still shows onboarding, not settings)
- [ ] Builds without errors

## Risk Assessment

- **Apple Event detection may not work with SMAppService**: Fallback is acceptable - worst case, Settings shows on login-item launch too (minor annoyance). Can be refined later.
- **Race condition with onboarding window**: The `checkFirstLaunch()` guard (`hasLaunchedBefore == false`) ensures onboarding and settings logic are mutually exclusive.
