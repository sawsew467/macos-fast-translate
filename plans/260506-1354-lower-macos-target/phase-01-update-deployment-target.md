---
phase: 1
title: "Update deployment target & configs"
status: complete
priority: P1
effort: "10min"
dependencies: []
---

# Phase 1: Update Deployment Target & Configs

## Overview
Change `MACOSX_DEPLOYMENT_TARGET` from 14.0 to 13.0 in all config files.

## Related Code Files
- Modify: `project.yml` (line 5, 12)
- Modify: `FastTranslate.xcodeproj/project.pbxproj` (line 340, 397)

## Implementation Steps

1. `project.yml` — update 2 locations:
   ```yaml
   # line 5: deploymentTarget
   macOS: "13.0"

   # line 12: settings
   MACOSX_DEPLOYMENT_TARGET: "13.0"
   ```

2. `project.pbxproj` — update 2 locations (Debug + Release):
   ```
   MACOSX_DEPLOYMENT_TARGET = 13.0;
   ```

3. Regenerate Xcode project if using XcodeGen:
   ```bash
   xcodegen generate
   ```

## Success Criteria
- [x] `project.yml` deployment target = 13.0
- [x] `project.pbxproj` MACOSX_DEPLOYMENT_TARGET = 13.0 (both Debug and Release)
- [x] Project builds successfully with target 13.0
