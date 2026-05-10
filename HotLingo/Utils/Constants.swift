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

    // MARK: - Supabase configuration
    enum Supabase {
        static let url = "https://mlsqckwozkbbloviohfl.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sc3Fja3dvemtiYmxvdmlvaGZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMTY3NzQsImV4cCI6MjA5Mzg5Mjc3NH0.tpnF4K4lXgCeqywuQALfvsoUiYNj9XYXDh3AXNhTHPg"
    }

    // MARK: - Keychain account names (not UserDefaults)
    enum KeychainAccount {
        static let openAIAPIKey = "openai_api_key"
        static let supabaseAccessToken = "supabase_access_token"
        static let supabaseRefreshToken = "supabase_refresh_token"
        static let supabaseUserEmail = "supabase_user_email"
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
        static let googleTranslateCount = "google_translate_count"
        static let hasSeenAINudgeBanner = "has_seen_ai_nudge_banner"
        static let hasClaimedTrial = "has_claimed_trial"
        static let hasEverLoggedIn = "has_ever_logged_in"
        static let lastKnownCreditBalance = "last_known_credit_balance"
        static let appLanguage = "app_language"
    }

    // MARK: - App Language

    enum AppLanguage: String, CaseIterable, Identifiable {
        case system = "system"
        case english = "en"
        case vietnamese = "vi"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: return String(localized: "System Default")
            case .english: return "English"
            case .vietnamese: return "Tiếng Việt"
            }
        }

        /// Returns the Locale to apply, or nil for system default.
        var locale: Locale? {
            switch self {
            case .system: return nil
            case .english: return Locale(identifier: "en")
            case .vietnamese: return Locale(identifier: "vi")
            }
        }
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
