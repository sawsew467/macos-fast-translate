---
phase: 2
title: "Replace SCScreenshotManager with CGWindowListCreateImage"
status: complete
priority: P1
effort: "30min"
dependencies: [1]
---

# Phase 2: Replace SCScreenshotManager

## Overview
`SCScreenshotManager.captureImage` requires macOS 14+. Replace with `CGWindowListCreateImage` — available since macOS 10.5+, supports Retina via `.bestResolution`.

## Requirements
- Screenshot OCR still works correctly: select region → capture → OCR → translate
- Retina display captures at correct resolution
- Multi-monitor support preserved
- Overlay already dismissed before capture (current flow guarantees this)

## Related Code Files
- Modify: `FastTranslate/Services/ScreenCaptureService.swift`

## Architecture

Current flow (unchanged):
```
User drag region → overlay dismiss → capture screenshot → return CGImage
```

Only the capture function changes:
```
// Before (macOS 14+):
SCScreenshotManager.captureImage(contentFilter:configuration:)

// After (macOS 10.5+):
CGWindowListCreateImage(cgRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
```

## Implementation Steps

1. In `ScreenCaptureService.swift`, replace method `captureWithSCKit`:

```swift
private static func captureRegionImage(cgRect: CGRect) -> CGImage? {
    // .bestResolution handles Retina (2x/3x) automatically
    return CGWindowListCreateImage(
        cgRect,
        .optionOnScreenOnly,
        kCGNullWindowID,
        .bestResolution
    )
}
```

2. Update `captureRect(_:)` to call new method (synchronous, no async needed):

```swift
func captureRect(_ viewRect: NSRect) {
    // ... coordinate conversion unchanged ...

    // Dismiss overlay first
    win.orderOut(nil)
    window = nil

    // Capture synchronously — no need for Task/async
    let image = Self.captureRegionImage(cgRect: cgRect)
    finish(image)
}
```

3. Remove `import ScreenCaptureKit` — no longer needed.

4. Delete old `captureWithSCKit` method.

## Risk Assessment
- **Retina:** `.bestResolution` flag ensures correct pixel density capture
- **Multi-monitor:** `CGWindowListCreateImage` uses global CG coordinates, compatible with multi-monitor — current coordinate conversion already outputs CG coords
- **Performance:** `CGWindowListCreateImage` is synchronous, faster than SCScreenshotManager (no async display enumeration)
- **Permissions:** Still requires Screen Recording permission (already handled in `hasPermission()` / `requestPermission()`)

## Success Criteria
- [x] `import ScreenCaptureKit` removed
- [x] `captureWithSCKit` replaced with `CGWindowListCreateImage`
- [x] Screenshot OCR works on macOS 13+
- [x] Retina display captures at correct resolution (`.bestResolution` flag)
- [x] Build succeeds with no new warnings
