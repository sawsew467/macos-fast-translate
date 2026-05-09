# Project Changelog

## [1.6.0] - 2026-05-09

### Added
- Optional selection translate button for quick translate from text selection
- Quick translate displayed as centered window for better visibility

### Fixed
- Prevent screenshot overlay spam and ensure ESC properly cancels capture

## [1.5.0] - 2026-05-06

### Added
- Google Translate as free default provider — no API key or setup needed
- Provider picker in Settings > General ("Translation Engine" card)
- Contextual info banner in API Keys tab when Google Translate is active
- Redesigned onboarding Step 1: provider choice (Google Translate / OpenAI) replaces mandatory API key
- `ProviderOptionCard` component for onboarding provider selection
- `GoogleTranslateProvider` using unofficial `translate.googleapis.com` endpoint

### Changed
- New installs default to Google Translate (existing users with saved OpenAI preference keep OpenAI)
- Onboarding "Continue" button always enabled (no longer blocked by missing API key)
- Onboarding window height increased (570→640px) to fit provider choice + OpenAI key entry without clipping

## [1.4.0] - 2026-05-06

### Changed
- Lowered minimum macOS requirement from 14.0 (Sonoma) to 13.0 (Ventura)
- Replaced `SCScreenshotManager` with `CGWindowListCreateImage` for broader compatibility
- Removed `ScreenCaptureKit` framework dependency

### Note
- Vietnamese OCR accuracy may be reduced on macOS 13 (full `vi-VN` support from macOS 14.4+)

## [1.3.0] - 2026-05-06

### Added
- Show Settings window (About tab) when user opens app from Spotlight/Applications after onboarding
- `applicationShouldHandleReopen` — reopening the running app brings up Settings instead of doing nothing
- Login-item detection via Apple Events — auto-launch at login stays silent (no intrusive window on startup)

## [1.2.0] - 2026-05-05

### Added
- `UpdateService` — DIY GitHub Releases checker (zero external dependencies)
  - Silent background check on launch; explicit check from Settings/menu
  - Downloads versioned `.zip` asset, extracts, replaces `.app`, relaunches
  - Falls back to browser (GitHub Releases page) if install fails
- "About" tab in Settings — app icon, version, "Check for Updates" button, live status indicator
- "Check for Updates…" item in status bar right-click menu
- `build-dmg.sh` now produces `FastTranslate-{version}.zip` alongside `.dmg` (using `ditto`)

## [1.1.0] - 2026-05-05

### Added
- Customizable hotkey recording — users can now rebind translate/screenshot shortcuts in Settings
- Selectable history deletion — delete individual translation entries from history
- Smart multilingual target language detection — auto-switches target based on source language
- OCR chat translation formatting — structured output for screenshot translations
- Vertical resize for floating panel
- Branded DMG packaging script (`scripts/build-dmg.sh`)
- Uninstall script (`scripts/uninstall-fasttranslate.sh`)

### Changed
- Refreshed app icon artwork with updated design
- Native glass effect for floating panel (vibrancy/blur)
- Native glass onboarding window with refreshed setup UI
- Floating panel rounded corners UI polish
- Improved history and selected text handling

### Fixed
- Clipboard restored correctly with cloned items (no longer clobbered)
- Popover translations stay inline instead of resetting
- Floating panel resize clamped to valid bounds

## [1.0.0] - 2026-05-03

### Added
- App icon with Vi↔En speech bubbles and flag design
- All required macOS icon sizes (16–1024px) for App Store submission
- `LSApplicationCategoryType` (Productivity) for App Store validation
- App Sandbox entitlement enabled for App Store distribution
- Info.plist version variables synced to build settings (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`)

## [Unreleased] - 2026-05-03

### Added
- Streaming translation UX: panel appears instantly on ⌃⌥T/⌃⌥S with loading state, tokens stream progressively from OpenAI SSE
- `StreamingTranslationState` observable model for reactive panel updates
- `translateStream()` protocol method with default single-shot fallback
- `translateStreaming()` on TranslationService for hotkey/screenshot flows
- Floating panel drag-to-move and edge/corner resize
- `scripts/clean-reset.sh` for quick app data reset (Keychain, UserDefaults, history, DerivedData)

### Changed
- Panel no longer auto-dismisses on outside click — close via X button, Copy, or new translation
- Streaming panel uses fixed 200px height with ScrollView + auto-scroll instead of per-token window resize

### Fixed
- Streaming panel jitter caused by per-token window resize recalculating position
- Panel shrinking/text overflow after stream completion (`fittingSize` returns near-zero for ScrollView)

### Fixed
- ⌃⌥T hotkey always showing "No text selected" — root cause: `CGEventSource(.hidSystemState)` leaked physical ⌃⌥ modifiers into simulated ⌘+C
- Added AX API (`kAXSelectedTextAttribute`) as primary text reader (fast, no clipboard side effects); clipboard simulation kept as fallback with `.privateState`

### Removed
- Claude/Anthropic provider support: removed `.claude` case from `ProviderType` enum, keychain constant, API key settings UI section, and doc comments
- Provider picker from General Settings (only OpenAI remains, picker was redundant)
- Clipboard translate hotkey placeholder (⌃⌥V) — unused after Phase 6 scope change

### Changed
- App now exclusively uses OpenAI (GPT-4o mini) as translation backend

---

## [0.6.0] - 2026-05-03
### Added
- Settings window with General, API Keys, and Hotkeys tabs
- Onboarding wizard (API key setup, permissions, done)
- Translation history (capped at 50, persisted to disk)
- Keychain-based API key storage via `KeychainHelper`

## [0.5.0] - 2026-05-02
### Added
- Screenshot OCR pipeline (Phase 5): region capture, Vision OCR, auto-translate

## [0.4.0] - 2026-05-02
### Added
- Global hotkeys (Ctrl+Opt+T translate, Ctrl+Opt+S screenshot)
- Floating result panel with auto-dismiss

## [0.3.0] - 2026-05-01
### Added
- Translation popover UI with context input
- Floating panel controller for quick results

## [0.2.0] - 2026-05-01
### Added
- Translation engine: OpenAI GPT-4o mini provider, language detection, 3-layer context system

## [0.1.0] - 2026-04-30
### Added
- Initial project setup, product overview, architecture docs
