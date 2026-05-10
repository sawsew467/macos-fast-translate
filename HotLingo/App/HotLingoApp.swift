import SwiftUI

@main
struct HotLingoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            LocaleWrapper { SettingsView() }
        }
    }
}

// MARK: - LocaleWrapper

/// Reactively applies the user's language preference to all descendant SwiftUI views.
struct LocaleWrapper<Content: View>: View {
    @AppStorage(Constants.UserDefaultsKey.appLanguage) private var appLanguage = Constants.AppLanguage.system.rawValue
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var effectiveLocale: Locale {
        let lang = Constants.AppLanguage(rawValue: appLanguage) ?? .system
        return lang.locale ?? Locale.current
    }

    var body: some View {
        content.environment(\.locale, effectiveLocale)
    }
}
