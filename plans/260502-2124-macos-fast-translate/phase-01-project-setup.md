---
phase: 1
title: "Project Setup"
status: completed
priority: P0
effort: "2h"
dependencies: []
---

# Phase 1: Project Setup

## Overview
Tạo Xcode project (via XcodeGen) cho macOS menu bar-only app. Scaffold cấu trúc thư mục, Info.plist, entitlements, và basic menu bar icon.

## Requirements
- Xcode project với Swift 5.9+, macOS 14+ deployment target
- Menu bar-only app (no dock icon, no main window)
- `LSUIElement = true` trong Info.plist
- App sandbox disabled (cần cho global hotkeys + screen capture)
- SF Symbol icon trên menu bar

## Architecture

### Project Structure
```
project.yml                            # XcodeGen config
FastTranslate/
├── App/
│   ├── FastTranslateApp.swift         # @main, SwiftUI App entry
│   └── AppDelegate.swift              # NSStatusItem, NSPopover management
├── Models/
│   └── TranslationModels.swift        # Language enum, TranslationResult struct
├── Views/                             # (placeholder, Phase 3)
├── Services/                          # (placeholder, Phase 2)
├── Utils/
│   └── Constants.swift                # App constants, hotkey codes, UserDefaults keys
└── Resources/
    ├── Info.plist                      # LSUIElement=true
    ├── FastTranslate.entitlements      # Sandbox disabled
    └── Assets.xcassets/
        └── AppIcon.appiconset/
```

### XcodeGen project.yml
```yaml
name: FastTranslate
options:
  bundleIdPrefix: com.fasttranslate
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.9"
targets:
  FastTranslate:
    type: application
    platform: macOS
    sources: [FastTranslate]
    settings:
      base:
        INFOPLIST_FILE: FastTranslate/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: FastTranslate/Resources/FastTranslate.entitlements
        PRODUCT_BUNDLE_IDENTIFIER: com.fasttranslate.app
```

### Info.plist key points
```xml
<key>LSUIElement</key>
<true/>               <!-- Hide dock icon -->
```

### Entitlements
```xml
<key>com.apple.security.app-sandbox</key>
<false/>              <!-- Disable sandbox for hotkeys + screen capture -->
```

### AppDelegate skeleton
```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Create NSStatusItem with SF Symbol "character.bubble"
        // 2. Create NSPopover with TranslationPopoverView (placeholder)
        // 3. Button action toggles popover
        // 4. Global click monitor closes popover when clicking outside
    }
}
```

### FastTranslateApp entry
```swift
@main
struct FastTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { SettingsView() }  // Settings window (Phase 7)
    }
}
```

## Related Code Files
- Create: `project.yml`
- Create: `FastTranslate/App/FastTranslateApp.swift`
- Create: `FastTranslate/App/AppDelegate.swift`
- Create: `FastTranslate/Models/TranslationModels.swift`
- Create: `FastTranslate/Utils/Constants.swift`
- Create: `FastTranslate/Resources/Info.plist`
- Create: `FastTranslate/Resources/FastTranslate.entitlements`
- Create: `FastTranslate/Resources/Assets.xcassets/`

## Implementation Steps
1. Tạo directory structure theo project structure ở trên
2. Viết `project.yml` cho XcodeGen
3. Viết `Info.plist` với `LSUIElement=true`
4. Viết `FastTranslate.entitlements` với sandbox disabled
5. Viết `FastTranslateApp.swift` — @main entry, NSApplicationDelegateAdaptor
6. Viết `AppDelegate.swift` — NSStatusItem + NSPopover + click-outside monitor
7. Viết `TranslationModels.swift` — Language enum (vi/en), TranslationResult struct, ProviderType enum
8. Viết `Constants.swift` — hotkey codes, UserDefaults keys
9. Tạo `Assets.xcassets` với AppIcon placeholder
10. Chạy `xcodegen generate` để tạo .xcodeproj
11. Build & run, verify menu bar icon hiện, click mở popover, không có dock icon

## Success Criteria
- [x] `xcodegen generate` chạy thành công
- [x] `xcodebuild build` không lỗi
- [ ] App hiện icon trên menu bar (SF Symbol "character.bubble")
- [ ] Click icon mở popover (placeholder view)
- [ ] Click ngoài popover → popover đóng
- [ ] Không có dock icon
- [x] macOS 14+ target

## Risk Assessment
- **XcodeGen version mismatch:** Verify `xcodegen --version` tương thích với Xcode 26.3
- **Swift 6 strict concurrency:** project.yml set `SWIFT_VERSION: "5.9"` để tránh strict concurrency issues ban đầu. Upgrade sau khi app ổn định
