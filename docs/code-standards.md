# Code Standards

## Swift Conventions

### Naming
- **Files:** PascalCase — `TranslationService.swift`, `FloatingPanelController.swift`
- **Types:** PascalCase — `struct TranslationResult`, `class HotkeyManager`
- **Functions/Properties:** camelCase — `func translateText()`, `var isTranslating`
- **Constants:** camelCase in enum namespace — `AppConstants.maxHistoryCount`
- **Protocols:** PascalCase, noun/adjective — `TranslationProvider`, `Configurable`

### File Organization
```
HotLingo/
├── App/          # Entry point, AppDelegate
├── Models/       # Data structs, enums
├── Views/        # SwiftUI views, AppKit controllers
├── Services/     # Business logic, API calls, system integration
├── Utils/        # Constants, helpers
└── Resources/    # Info.plist, entitlements, assets
```

### File Size
- **Max 200 lines per file.** Split if larger.
- Prefer composition over inheritance.
- One primary type per file (helpers OK if small).

### Code Style
```swift
// MARK: - sections for logical grouping
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods
```

### Error Handling
- Use Swift `throws` / `async throws` for operations that can fail
- Define domain-specific error enums (`TranslationError`, `OCRError`)
- Catch at UI boundary, display user-friendly messages
- Never silently swallow errors

### Concurrency
- Use `async/await` for all async operations
- `@MainActor` for UI-bound classes
- Avoid `DispatchQueue` unless interfacing with legacy APIs (Carbon)

### SwiftUI
- `@EnvironmentObject` for shared services (TranslationService)
- `@State` / `@Binding` for local view state
- `@AppStorage` for UserDefaults-backed preferences
- Keep views < 100 lines body, extract subviews as computed properties

### Dependencies
- **Zero external dependencies.** All Apple native frameworks.
- If a dependency is ever needed: Swift Package Manager only, no CocoaPods/Carthage.

## Git
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- No AI references in commit messages
- Keep commits focused and atomic
