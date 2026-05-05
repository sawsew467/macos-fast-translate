import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            APIKeysSettingsTab()
                .tabItem { Label("API Keys", systemImage: "key") }
            HotkeysSettingsTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .padding(.top, 6)
        .frame(width: 560, height: 430)
        .background(SettingsBackground())
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage(Constants.UserDefaultsKey.persistentContext) private var persistentContext = ""
    @AppStorage(Constants.UserDefaultsKey.defaultTargetLanguage) private var defaultTargetLanguage = Language.vietnamese.rawValue
    @State private var launchAtLogin = false

    var body: some View {
        SettingsPage(title: "General", subtitle: "Tune how FastTranslate behaves across popover and floating panel.") {
            SettingsCard(systemImage: "text.bubble", title: "Translation Context", subtitle: "Included in every translation for better accuracy.") {
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

            SettingsCard(systemImage: "globe.asia.australia", title: "Language", subtitle: "Default target used by popover and screenshot translation.") {
                Picker("Default Target", selection: $defaultTargetLanguage) {
                    ForEach(Language.targetOptions) { language in
                        Text("\(language.shortName) - \(language.displayName)").tag(language.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsCard(systemImage: "power", title: "Startup", subtitle: "Open FastTranslate automatically when you sign in.") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
        } catch {
            print("LaunchAtLogin: \(error.localizedDescription)")
        }
    }
}

// MARK: - API Keys Tab

struct APIKeysSettingsTab: View {
    @State private var openAIKey = ""
    @State private var openAIStatus: String?
    @State private var isTesting = false

    var body: some View {
        SettingsPage(title: "API Keys", subtitle: "Store provider credentials securely in macOS Keychain.") {
            SettingsCard(systemImage: "sparkles", title: "OpenAI", subtitle: "Used for translation and streaming responses.") {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("sk-proj-...", text: $openAIKey)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(.background.opacity(0.50), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.primary.opacity(0.10), lineWidth: 1)
                        }

                    HStack(spacing: 10) {
                        SettingsButton("Save", systemImage: "lock.doc", isPrimary: true) { saveOpenAIKey() }
                            .disabled(openAIKey.isEmpty)
                        SettingsButton("Test", systemImage: "checkmark.seal") { testOpenAIKey() }
                            .disabled(openAIKey.isEmpty || isTesting)

                        if isTesting { ProgressView().scaleEffect(0.75) }
                        if let status = openAIStatus {
                            Text(status)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(status.hasPrefix("OK") ? Color.green : Color.red)
                        }
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            openAIKey = KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) ?? ""
        }
    }

    private func saveOpenAIKey() {
        do {
            try KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: openAIKey)
            openAIStatus = "OK Saved"
        } catch {
            openAIStatus = "Error \(error.localizedDescription)"
        }
    }

    private func testOpenAIKey() {
        isTesting = true
        openAIStatus = nil
        Task {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 5
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    openAIStatus = code == 200 ? "OK Valid key" : "Error HTTP \(code)"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    openAIStatus = "Error Network"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Hotkeys Tab

struct HotkeysSettingsTab: View {
    var body: some View {
        SettingsPage(title: "Hotkeys", subtitle: "Quick actions available globally while the app is running.") {
            SettingsCard(systemImage: "keyboard", title: "Current Shortcuts", subtitle: "Customization is planned for a later version.") {
                VStack(spacing: 10) {
                    HotkeyRow(title: "Translate Selected Text", value: "⌃⌥T", systemImage: "character.cursor.ibeam")
                    HotkeyRow(title: "Screenshot OCR", value: "⌃⌥S", systemImage: "viewfinder")
                }
            }
        }
    }
}

// MARK: - Shared UI

private struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)

                content()
            }
            .padding(22)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let systemImage: String
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content()
                .padding(.leading, 42)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct SettingsButton: View {
    let title: String
    let systemImage: String
    var isPrimary = false
    let action: () -> Void

    init(_ title: String, systemImage: String, isPrimary: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isPrimary = isPrimary
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(isPrimary ? Color.primary.opacity(0.08) : Color.clear, in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(.primary.opacity(0.10), lineWidth: 1)
        }
    }
}

private struct HotkeyRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.background.opacity(0.55), in: Capsule(style: .continuous))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(.background.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SettingsBackground: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [.primary.opacity(0.04), .clear, .primary.opacity(0.025)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
