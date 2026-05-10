import SwiftUI
import ServiceManagement

struct GeneralSettingsTab: View {
    @AppStorage(Constants.UserDefaultsKey.persistentContext) private var persistentContext = ""
    @AppStorage(Constants.UserDefaultsKey.defaultProvider) private var defaultProvider = ProviderType.googleTranslate.rawValue
    @AppStorage(Constants.UserDefaultsKey.defaultTargetLanguage) private var defaultTargetLanguage = Language.vietnamese.rawValue
    @AppStorage(Constants.UserDefaultsKey.showSelectionTranslateButton) private var showSelectionTranslateButton = false
    @AppStorage(Constants.UserDefaultsKey.appLanguage) private var appLanguage = Constants.AppLanguage.system.rawValue
    @ObservedObject private var authService = SupabaseAuthService.shared
    @State private var launchAtLogin = false

    var onSwitchToAccount: (() -> Void)?

    private var selectedProvider: ProviderType {
        ProviderType(rawValue: defaultProvider) ?? .googleTranslate
    }

    var body: some View {
        SettingsPage(title: String(localized: "General"), subtitle: String(localized: "Tune how HotLingo behaves across popover and floating panel.")) {
            SettingsCard(systemImage: "brain", title: String(localized: "Translation Engine"), subtitle: String(localized: "Google Translate is free with no setup. AI Translation offers high quality with 50 free credits.")) {
                Picker("Provider", selection: $defaultProvider) {
                    Text("Google Translate").tag(ProviderType.googleTranslate.rawValue)
                    Text("AI Translation ✨").tag(ProviderType.aiTranslation.rawValue)
                    Text("GPT-4o mini (BYOK)").tag(ProviderType.openAI.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                if selectedProvider == .aiTranslation && !authService.authState.isLoggedIn {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .foregroundStyle(.orange)
                        Text("Log in to use AI Translation")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Go to Account") { onSwitchToAccount?() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            SettingsCard(systemImage: "text.cursor", title: String(localized: "Selection Button"), subtitle: String(localized: "Show a small translate button after selecting text in other apps.")) {
                Toggle("Show translate button when text is selected", isOn: $showSelectionTranslateButton)
                    .toggleStyle(.switch)
            }

            SettingsCard(systemImage: "text.bubble", title: String(localized: "Translation Context"), subtitle: String(localized: "Included in every translation for better accuracy.")) {
                TextEditor(text: $persistentContext)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 94)
                    .background(.background.opacity(0.46), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.primary.opacity(0.10), lineWidth: 1)
                    }
            }

            SettingsCard(systemImage: "globe.asia.australia", title: String(localized: "Language"), subtitle: String(localized: "Default target used by popover and screenshot translation.")) {
                Picker("Default Target", selection: $defaultTargetLanguage) {
                    ForEach(Language.targetOptions) { language in
                        Text("\(language.shortName) - \(language.displayName)").tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsCard(systemImage: "power", title: String(localized: "Startup"), subtitle: String(localized: "Open HotLingo automatically when you sign in.")) {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            SettingsCard(
                systemImage: "globe",
                title: String(localized: "App Language"),
                subtitle: String(localized: "Choose the language for the app interface.")
            ) {
                Picker(String(localized: "App Language"), selection: $appLanguage) {
                    ForEach(Constants.AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("LaunchAtLogin: \(error.localizedDescription)")
        }
    }
}
