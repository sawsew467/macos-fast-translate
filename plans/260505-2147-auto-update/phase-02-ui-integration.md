---
phase: 2
title: "UI Integration (Settings + Menu)"
status: pending
priority: P1
effort: "1h"
dependencies: [1]
---

# Phase 2: UI Integration (Settings + Menu)

## Overview
Add "Check for Updates" UI in two places: Settings window (About tab) and right-click status bar menu.

## Requirements
- Functional: Button in Settings, menu item in status bar, update available badge/indicator
- Non-functional: Non-blocking UI, clear feedback for "up to date" vs "update available"

## Architecture

```
SettingsView
  └── AboutSettingsTab (new tab)
        ├── App icon + version display
        ├── "Check for Updates" button
        └── Update status text (checking... / up to date / v1.2.0 available)

AppDelegate.showStatusItemMenu()
  └── "Check for Updates…" NSMenuItem → UpdateService.checkForUpdates()
```

## Related Code Files
- Modify: `FastTranslate/Views/SettingsView.swift` — add About tab with update button
- Modify: `FastTranslate/App/AppDelegate.swift` — add menu item to right-click menu

## Implementation Steps

1. **Add About tab to SettingsView**:
   - New `AboutSettingsTab` struct
   - Show app icon, version (`Bundle.main.infoDictionary`)
   - "Check for Updates" button bound to `UpdateService.shared`
   - Status label: idle / checking / up-to-date / update available + install button

2. **Add menu item to status bar right-click menu**:
   - In `showStatusItemMenu()`, add "Check for Updates…" item before "Settings…"
   - Action calls `UpdateService.shared.checkForUpdates()`

3. **Update Settings frame** if needed to accommodate new tab

## Success Criteria
- [ ] About tab shows app version and update button
- [ ] "Check for Updates" triggers GitHub API check
- [ ] Status feedback visible (checking → result)
- [ ] Right-click menu has "Check for Updates…" item
- [ ] Update available state shows install option

## Risk Assessment
- **Settings window size**: May need slight height increase for 4th tab — test layout
