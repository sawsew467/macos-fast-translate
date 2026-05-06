---
phase: 5
title: "Verify & test"
status: complete
priority: P1
effort: "15min"
dependencies: [1, 2, 3]
---

# Phase 5: Verify & Test

## Overview
Build project and verify all features work correctly after lowering deployment target.

## Implementation Steps

1. **Build verification:**
   ```bash
   xcodegen generate && xcodebuild build \
     -project FastTranslate.xcodeproj \
     -scheme FastTranslate \
     -destination 'platform=macOS' \
     -quiet
   ```

2. **Check for compiler warnings** about deprecated/unavailable APIs on macOS 13.

3. **Grep for remaining macOS 14+ APIs:**
   ```bash
   grep -rn "SCScreenshotManager" FastTranslate/
   # Should return 0 results
   ```

4. **Feature checklist** (manual or smoke test):
   - [ ] App launches, menu bar icon appears
   - [ ] Popover opens on click, translation works
   - [ ] Hotkeys (translate + screenshot) register
   - [ ] Screenshot OCR: select region, capture, OCR text, translate
   - [ ] Settings: all tabs render correctly
   - [ ] Launch at Login toggle works
   - [ ] History view opens and displays entries
   - [ ] Auto-update check works
   - [ ] Onboarding flow works

5. **Verify `#available` guards** still function:
   - macOS 26.0 glass effects — guarded with fallback
   - macOS 13.0 `automaticallyDetectsLanguage` — guarded

## Success Criteria
- [x] Clean build with 0 errors
- [x] No new warnings related to API availability
- [ ] All features functional (requires manual smoke test)
- [x] `SCScreenshotManager` completely removed from codebase
