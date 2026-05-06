# Plan: Lower macOS Deployment Target to 13.0 (Ventura)

Lower minimum deployment target from macOS 14.0 to 13.0 to expand user base. Replace 2 macOS 14+-only APIs with equivalent alternatives while preserving all existing functionality.

## Context

- Current target: macOS 14.0 (Sonoma)
- New target: macOS 13.0 (Ventura)
- macOS 13 still supported by Apple with significant user base

## Audit Summary

| API | Min macOS | File | Action |
|-----|-----------|------|--------|
| `SCScreenshotManager.captureImage` | 14.0 | `ScreenCaptureService.swift:171` | Replace with `CGWindowListCreateImage` |
| `.onChange(of:) { _, new in }` (2-param) | 14.0 | `SettingsView.swift:71`, `HistoryView.swift:41` | Use 1-param `.onChange(of:) { new in }` |
| `SCShareableContent`, `SCContentFilter` | 12.3 | `ScreenCaptureService.swift` | OK |
| `SMAppService` | 13.0 | `SettingsView.swift:76-82` | OK |
| `.scrollContentBackground(.hidden)` | 13.0 | `SettingsView.swift:47` | OK |
| `Task.sleep(for:)` | 13.0 | `ScreenCaptureService.swift:87` | OK |
| `URLSession.bytes(for:)` | 12.0 | `OpenAITranslationProvider.swift:75` | OK |
| `VNRecognizeTextRequest.automaticallyDetectsLanguage` | 13.0 | `OCRService.swift:50` | OK (already guarded) |
| `KeychainHelper` (Security framework) | 10.0+ | `KeychainHelper.swift` | OK |
| `ObservableObject/@Published` (Combine) | 10.15 | Multiple | OK |
| `GlassEffect` | 26.0 | Multiple | OK (already guarded) |

**Only 2 breaking changes to fix.** Everything else is already compatible with macOS 13+.

## Phases

| # | Phase | Status | Priority | Effort |
|---|-------|--------|----------|--------|
| 1 | [Update deployment target & configs](phase-01-update-deployment-target.md) | complete | P1 | 10min |
| 2 | [Replace SCScreenshotManager](phase-02-replace-screenshot-manager.md) | complete | P1 | 30min |
| 3 | [Fix onChange API signatures](phase-03-fix-onchange-signatures.md) | complete | P1 | 5min |
| 4 | [Update docs & README](phase-04-update-docs-readme.md) | complete | P2 | 10min |
| 5 | [Verify & test](phase-05-verify-test.md) | complete | P1 | 15min |

## Risk Assessment

- **Low risk:** Changes are minimal and well-scoped (2 API replacements + config)
- **OCR note:** Vietnamese OCR (`vi-VN`) only available from macOS 14.4+. On macOS 13, Vision still recognizes English/Latin text — GPT handles the rest. Code already handles this gracefully via `supportedRecognitionLanguages()`.
- **Screenshot quality:** `CGWindowListCreateImage(.bestResolution)` produces equivalent output to SCScreenshotManager on Retina displays.
