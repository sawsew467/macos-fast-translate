---
phase: 3
title: "Fix onChange API signatures"
status: complete
priority: P1
effort: "5min"
dependencies: [1]
---

# Phase 3: Fix onChange API Signatures

## Overview
SwiftUI `.onChange(of:) { oldValue, newValue in }` (2 params) requires macOS 14+.
Switch to `.onChange(of:) { newValue in }` (1 param) — available since macOS 12+.

## Related Code Files
- Modify: `FastTranslate/Views/SettingsView.swift` (line 71)
- Modify: `FastTranslate/Views/HistoryView.swift` (line 41)

## Implementation Steps

1. **SettingsView.swift:71** — Launch at Login toggle:
```swift
// Before (macOS 14+):
.onChange(of: launchAtLogin) { _, newValue in
    setLaunchAtLogin(newValue)
}

// After (macOS 12+):
.onChange(of: launchAtLogin) { newValue in
    setLaunchAtLogin(newValue)
}
```

2. **HistoryView.swift:41** — History list auto-selection:
```swift
// Before (macOS 14+):
.onChange(of: filtered.map(\.id)) { _, ids in
    if let selectedID, ids.contains(selectedID) { return }
    selectedID = ids.first
}

// After (macOS 12+):
.onChange(of: filtered.map(\.id)) { ids in
    if let selectedID, ids.contains(selectedID) { return }
    selectedID = ids.first
}
```

3. **FloatingPanelController.swift:311** — Already uses 1-param form `{ _ in }`, no change needed.

## Success Criteria
- [x] SettingsView onChange uses 1-param closure
- [x] HistoryView onChange uses 1-param closure
- [x] Build succeeds with no deprecation warnings on macOS 13
