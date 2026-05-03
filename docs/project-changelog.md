# Project Changelog

## [Unreleased] - 2026-05-03

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
