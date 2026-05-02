import Foundation

enum Constants {
    // MARK: - Hotkey key codes (Carbon / kVK_*)
    enum HotkeyCode {
        static let translate: UInt32 = 17   // kVK_ANSI_T
        static let screenshot: UInt32 = 1   // kVK_ANSI_S
        static let clipboard: UInt32 = 9    // kVK_ANSI_V
    }

    // MARK: - UserDefaults keys
    enum UserDefaultsKey {
        static let apiKey = "openai_api_key"
        static let persistentContext = "persistent_context"
        static let defaultProvider = "default_provider"
        static let launchAtLogin = "launch_at_login"
    }

    // MARK: - UI
    enum UI {
        static let popoverWidth: CGFloat = 360
        static let popoverHeight: CGFloat = 300
    }
}
