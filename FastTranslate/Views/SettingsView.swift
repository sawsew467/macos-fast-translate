import SwiftUI
import ServiceManagement

extension Notification.Name {
    static let openAboutTab = Notification.Name("FastTranslate.openAboutTab")
}

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            APIKeysSettingsTab()
                .tabItem { Label("API Keys", systemImage: "key") }
                .tag(1)
            HotkeysSettingsTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(2)
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(3)
        }
        .padding(.top, 6)
        .frame(width: 560, height: 430)
        .background(SettingsBackground())
        .onReceive(NotificationCenter.default.publisher(for: .openAboutTab)) { _ in
            selectedTab = 3
        }
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
    @StateObject private var hotkeyStore = HotkeyStore.shared

    var body: some View {
        SettingsPage(title: "Hotkeys", subtitle: "Quick actions available globally while the app is running.") {
            SettingsCard(systemImage: "keyboard", title: "Shortcuts", subtitle: "Click a shortcut field, then press your desired key combo.") {
                VStack(spacing: 10) {
                    HotkeyRecorderRow(
                        title: "Translate Selected Text",
                        systemImage: "character.cursor.ibeam",
                        action: .translate,
                        binding: $hotkeyStore.translateBinding,
                        store: hotkeyStore
                    )
                    HotkeyRecorderRow(
                        title: "Screenshot OCR",
                        systemImage: "viewfinder",
                        action: .screenshot,
                        binding: $hotkeyStore.screenshotBinding,
                        store: hotkeyStore
                    )
                }
            }

            if let error = hotkeyStore.registrationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Failed to register \(error.action.rawValue) hotkey: \(error.message)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            HStack {
                SettingsButton("Reset to Defaults", systemImage: "arrow.counterclockwise") {
                    hotkeyStore.resetToDefaults()
                }
                Spacer()
            }
        }
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    @ObservedObject private var updateService = UpdateService.shared

    var body: some View {
        SettingsPage(title: "About", subtitle: "Version info and software updates.") {
            // App identity card
            SettingsCard(systemImage: "app.badge", title: "FastTranslate", subtitle: "Fast Vi↔En translation for macOS.") {
                HStack(spacing: 16) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FastTranslate")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Version \(updateService.currentVersion)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            // Update card
            SettingsCard(systemImage: "arrow.down.circle", title: "Software Update", subtitle: "Check GitHub Releases for a newer version.") {
                VStack(alignment: .leading, spacing: 12) {
                    updateStatusView
                    HStack(spacing: 10) {
                        checkButton
                        if case .available = updateService.state {
                            installButton
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateService.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Checking for updates…").font(.caption).foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("You're up to date.", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        case .available(let version):
            Label("Version \(version) is available.", systemImage: "arrow.down.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
        case .installing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Downloading update…").font(.caption).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkButton: some View {
        let isBusy = updateService.state == .checking || updateService.state == .installing
        return SettingsButton("Check for Updates", systemImage: "arrow.clockwise", isPrimary: true) {
            updateService.checkForUpdates()
        }
        .disabled(isBusy)
    }

    private var installButton: some View {
        SettingsButton("Install Update", systemImage: "arrow.down.circle") {
            updateService.installUpdate()
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

private struct HotkeyRecorderRow: View {
    let title: String
    let systemImage: String
    let action: HotkeyAction
    @Binding var binding: HotkeyBinding
    let store: HotkeyStore

    private var isDuplicate: Bool {
        store.duplicateAction(for: binding, excluding: action) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                HotkeyRecorderView(binding: Binding(
                    get: { binding },
                    set: { newBinding in
                        binding = newBinding
                        store.save(newBinding, for: action)
                    }
                ))
                .frame(width: 120, height: 28)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(.background.opacity(0.34), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if isDuplicate {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text("Conflicts with another shortcut")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.orange)
                .padding(.leading, 44)
            }
        }
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
