---
phase: 1
title: "SPM Integration & UpdateService"
status: pending
priority: P1
effort: "1h"
dependencies: []
---

# Phase 1: SPM Integration & UpdateService

## Overview
Add s1ntoneli/AppUpdater via SPM and create an UpdateService wrapper that checks GitHub Releases for new versions.

## Requirements
- Functional: Check GitHub API for latest release, compare versions, download+install update
- Non-functional: No UI freeze during check, code signature verification enabled

## Architecture

```
UpdateService (ObservableObject)
  ├── appUpdater: AppUpdater (owner: "sawsew467", repo: "macos-fast-translate")
  ├── @Published updateAvailable: Bool
  ├── @Published latestVersion: String?
  ├── checkOnLaunch()    — silent check, no UI if up-to-date
  ├── checkForUpdates()  — explicit check from Settings, shows "up to date" if current
  └── install()          — download + replace + restart
```

## Related Code Files
- Create: `FastTranslate/Services/UpdateService.swift`
- Modify: `FastTranslate.xcodeproj/project.pbxproj` (SPM dependency)

## Implementation Steps

1. **Add SPM dependency** in Xcode:
   - File → Add Package Dependencies → `https://github.com/s1ntoneli/AppUpdater.git` → from version `0.1.5`

2. **Create `UpdateService.swift`**:
   ```swift
   import AppUpdater
   import Combine

   @MainActor
   final class UpdateService: ObservableObject {
       static let shared = UpdateService()

       private let appUpdater: AppUpdater
       @Published var updateAvailable = false
       @Published var latestVersion: String?

       private init() {
           appUpdater = AppUpdater(owner: "sawsew467", repo: "macos-fast-translate")
       }

       func checkOnLaunch() {
           appUpdater.check()
           // Observe state changes...
       }

       func checkForUpdates() { appUpdater.check() }
       func install() { appUpdater.install() }
   }
   ```

3. **Wire into AppDelegate**:
   - Call `UpdateService.shared.checkOnLaunch()` in `applicationDidFinishLaunching`

## Success Criteria
- [ ] SPM resolves and builds successfully
- [ ] UpdateService compiles and initializes
- [ ] `check()` hits GitHub API and returns version info
- [ ] Code signature verification is enabled (default)

## Risk Assessment
- **AppUpdater API changes**: Pin to specific version `0.1.5`
- **GitHub API rate limiting**: Unauthenticated limit is 60 req/hr — more than enough for launch check
- **ZIP vs DMG**: AppUpdater expects `.zip` assets. Release workflow must include a `.zip` alongside the `.dmg`
