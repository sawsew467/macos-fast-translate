import Foundation

enum Constants {
    // MARK: - Hotkey key codes (Carbon / kVK_*)
    enum HotkeyCode {
        static let translate: UInt32 = 17   // kVK_ANSI_T
        static let screenshot: UInt32 = 1   // kVK_ANSI_S
    }

    // MARK: - Hotkey IDs (unique per registered hotkey, used in Carbon EventHotKeyID)
    enum HotkeyIDs {
        static let translate: UInt32 = 1
        static let screenshot: UInt32 = 2
    }

    // MARK: - Keychain account names (not UserDefaults)
    enum KeychainAccount {
        static let openAIAPIKey = "openai_api_key"
    }

    // MARK: - UserDefaults keys
    enum UserDefaultsKey {
        static let persistentContext = "persistent_context"
        static let defaultProvider = "default_provider"
        static let defaultTargetLanguage = "default_target_language"
        static let hasLaunchedBefore = "has_launched_before"
        static let onboardingStep = "onboarding_step"
        static let translateHotkeyKeyCode = "translate_hotkey_key_code"
        static let translateHotkeyModifiers = "translate_hotkey_modifiers"
        static let screenshotHotkeyKeyCode = "screenshot_hotkey_key_code"
        static let screenshotHotkeyModifiers = "screenshot_hotkey_modifiers"
        static let showSelectionTranslateButton = "show_selection_translate_button"
    }

    // MARK: - UI
    enum UI {
        static let popoverWidth: CGFloat = 380
        static let popoverHeight: CGFloat = 340
        static let popoverHeightWithContext: CGFloat = 420
        static let floatingPanelWidth: CGFloat = 300
        static let floatingPanelHeight: CGFloat = 90
        static let floatingPanelDismissDelay: TimeInterval = 10
    }
}
