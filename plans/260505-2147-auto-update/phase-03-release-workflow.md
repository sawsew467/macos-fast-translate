---
phase: 3
title: "Release Workflow Update"
status: pending
priority: P2
effort: "30m"
dependencies: [1]
---

# Phase 3: Release Workflow Update

## Overview
Update the release workflow to include a `.zip` asset alongside the `.dmg`, since AppUpdater downloads and extracts `.zip` archives.

## Requirements
- Functional: Each GitHub Release includes both `FastTranslate.dmg` and `FastTranslate.zip`
- Non-functional: ZIP must contain the signed+notarized `.app` bundle

## Related Code Files
- Modify: `scripts/build-dmg.sh` — add zip creation step (or create separate helper)

## Implementation Steps

1. **After Xcode archive+export**, create ZIP from signed app:
   ```bash
   ditto -c -k --keepParent FastTranslate.app FastTranslate-1.1.0.zip
   ```

2. **Update release command** to upload both assets:
   ```bash
   gh release create v1.2.0 \
     FastTranslate.dmg#FastTranslate.dmg \
     FastTranslate-1.2.0.zip#FastTranslate-1.2.0.zip \
     --title "..." --notes "..."
   ```

3. **Verify naming convention**: AppUpdater looks for `{AppName}-{version}.zip` pattern in release assets. Confirm exact pattern expected.

## Success Criteria
- [ ] Release includes both .dmg and .zip
- [ ] ZIP contains properly signed+notarized app
- [ ] AppUpdater can find and download the ZIP asset from release

## Risk Assessment
- **Asset naming**: Must match AppUpdater's expected pattern. Test with a pre-release first.
