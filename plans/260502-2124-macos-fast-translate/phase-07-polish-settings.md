---
phase: 7
title: "Settings & Polish"
status: pending
priority: P2
effort: "4h"
dependencies: [1, 2, 3]
---

# Phase 7: Settings & Polish

## Overview
Settings panel, persistent context, API key management (Keychain), translation history, launch at login, first-launch onboarding.

## Requirements
- **Functional:**
  - Settings window với tabs: General, API Keys, Hotkeys
  - Persistent context input (gửi kèm mọi bản dịch)
  - OpenAI API key entry (lưu Keychain, không UserDefaults)
  - Translation history (last 50, tìm kiếm được)
  - Launch at login toggle
  - First-launch onboarding: API key → permissions
  - Hotkey customization (đổi phím tắt)

## Architecture

### Files
```
Views/
└── SettingsView.swift           # Settings window (SwiftUI, tabs)

Services/ (modify existing)
├── TranslationService.swift     # Add history persistence
└── HotkeyManager.swift          # Add hotkey customization
```

### Settings Layout
```
┌─────────────────────────────────────────┐
│  [General]  [API Keys]  [Hotkeys]       │
├─────────────────────────────────────────┤
│                                         │
│  General Tab:                           │
│  ┌─ Default Provider ──────────────┐    │
│  │ [GPT-4o-mini ▼]                 │    │
│  └─────────────────────────────────┘    │
│  ┌─ Persistent Context ───────────┐    │
│  │ "I'm a software developer      │    │
│  │  communicating with English-    │    │
│  │  speaking clients. Professional │    │
│  │  but friendly tone."           │    │
│  └─────────────────────────────────┘    │
│  ☑ Launch at login                      │
│  ☐ Auto-dismiss floating panel (10s)    │
│                                         │
│  API Keys Tab:                          │
│  ┌─ OpenAI API Key ───────────────┐    │
│  │ sk-proj-•••••••••••••          │    │
│  │ [Save to Keychain] [Test]      │    │
│  └─────────────────────────────────┘    │
│  ┌─ Claude API Key (optional) ────┐    │
│  │ sk-ant-•••••••••••••           │    │
│  │ [Save to Keychain] [Test]      │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Hotkeys Tab:                           │
│  Translate selected: [⌃+⌥+T] [Record]  │
│  Screenshot OCR:     [⌃+⌥+S] [Record]  │
│  Translate clipboard:[⌃+⌥+V] [Record]  │
│                                         │
└─────────────────────────────────────────┘
```

### Keychain Storage
```swift
struct KeychainHelper {
    static func save(key: String, value: String) throws {
        // SecItemAdd / SecItemUpdate
        // Service: "com.fasttranslate.app"
        // Account: key (e.g. "openai-api-key")
    }

    static func load(key: String) -> String? {
        // SecItemCopyMatching
    }

    static func delete(key: String) throws {
        // SecItemDelete
    }
}
```

### Translation History
```swift
// Simple JSON file at ~/Library/Application Support/FastTranslate/history.json
// Struct: [{ source, translated, sourceLang, targetLang, provider, timestamp }]
// Max 50 entries, FIFO
// Search: filter by source or translated text
```

### First-Launch Onboarding
```
Step 1: "Welcome to FastTranslate"
  → Enter OpenAI API key
  → [Test Key] button validates key
  → [Save & Continue]

Step 2: "Grant Permissions"
  → Accessibility: [Open Settings] → hướng dẫn bật
  → Screen Recording: [Open Settings] → hướng dẫn bật
  → Show status: ✅ Granted / ❌ Not granted

Step 3: "You're all set!"
  → Show hotkey summary
  → [Start Using FastTranslate]
```

### Launch at Login
```swift
import ServiceManagement

// macOS 13+: SMAppService
SMAppService.mainApp.register()   // enable
SMAppService.mainApp.unregister() // disable
```

## Related Code Files
- Create: `FastTranslate/Views/SettingsView.swift`
- Create: `FastTranslate/Utils/KeychainHelper.swift`
- Create: `FastTranslate/Views/OnboardingView.swift`
- Modify: `FastTranslate/Services/TranslationService.swift` (history persistence, persistent context)
- Modify: `FastTranslate/Services/HotkeyManager.swift` (customizable keys)
- Modify: `FastTranslate/App/AppDelegate.swift` (show onboarding on first launch)

## Implementation Steps
1. Tạo `KeychainHelper.swift`:
   - save/load/delete API keys trong Keychain
   - Service identifier: "com.fasttranslate.app"
2. Tạo `SettingsView.swift` với TabView:
   - **General tab:** default provider picker, persistent context TextEditor, launch at login toggle, auto-dismiss toggle
   - **API Keys tab:** OpenAI key field (SecureField), Claude key field (optional), Test button (gọi API với text ngắn), Save button
   - **Hotkeys tab:** hiện current hotkeys, record new hotkey (stretch goal)
3. Persistent context:
   - Lưu trong UserDefaults (`@AppStorage`)
   - TranslationService đọc persistent context khi translate
4. Translation history:
   - Save to JSON file tại `~/Library/Application Support/FastTranslate/history.json`
   - Load on app start, append after each translation
   - Max 50 entries (FIFO — xóa cũ nhất khi vượt)
   - Thêm history popover/sheet trong main popover (click "History" button)
5. Launch at login:
   - `SMAppService.mainApp.register()` / `unregister()`
   - Bind to toggle trong Settings
6. Tạo `OnboardingView.swift`:
   - 3-step wizard: API key → permissions → done
   - Show on first launch (check UserDefaults flag)
   - API key test: call OpenAI API với "Hello" → verify response
   - Permission status: check `AXIsProcessTrusted()` + `CGPreflightScreenCaptureAccess()`
7. Wire Settings vào app:
   - Menu bar dropdown: "Settings..." item → open Settings window
   - ⌘+, keyboard shortcut opens Settings (standard macOS behavior, automatic with SwiftUI Settings scene)
8. Polish:
   - Menu bar tooltip hiện provider name
   - Error notifications dùng `NSUserNotification` hoặc system notification
   - Smooth animations trong popover (fade in/out)

## Success Criteria
- [ ] Settings window mở từ menu bar "Settings..."
- [ ] OpenAI API key lưu/đọc từ Keychain
- [ ] "Test" button verify API key hoạt động
- [ ] Persistent context gửi kèm mọi bản dịch
- [ ] Translation history lưu/đọc từ JSON file
- [ ] History hiện trong popover, tìm kiếm được
- [ ] Launch at login toggle hoạt động
- [ ] First-launch onboarding wizard hiện đúng lần đầu
- [ ] Onboarding guide permissions đúng
- [ ] ⌘+, mở Settings (standard macOS)

## Risk Assessment
- **Keychain permission:** App cần "keychain-access-groups" entitlement nếu dùng App Group. Không sandbox → dùng default keychain, đơn giản hơn
- **Hotkey customization complexity:** Recording new hotkeys non-trivial. Có thể defer sang v2, chỉ support default hotkeys trong v1
- **History file corruption:** Dùng try/catch khi read/write JSON. Nếu file corrupt → reset history
