import SwiftUI
import ServiceManagement

extension Notification.Name {
    static let openAboutTab = Notification.Name("HotLingo.openAboutTab")
    static let openAccountTab = Notification.Name("HotLingo.openAccountTab")
    static let sessionExpired = Notification.Name("HotLingo.sessionExpired")
}

struct SettingsView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(onSwitchToAccount: { selectedTab = 1 })
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            SettingsAccountTab()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(1)
            APIKeysSettingsTab()
                .tabItem { Label("API Keys", systemImage: "key") }
                .tag(2)
            HotkeysSettingsTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(3)
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(4)
        }
        .padding(.top, 6)
        .frame(width: 560, height: 500)
        .background(SettingsBackground())
        .onReceive(NotificationCenter.default.publisher(for: .openAboutTab)) { _ in
            selectedTab = 4
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAccountTab)) { _ in
            selectedTab = 1
        }
    }
}

// MARK: - API Keys Tab

struct APIKeysSettingsTab: View {
    @AppStorage(Constants.UserDefaultsKey.defaultProvider) private var defaultProvider = ProviderType.googleTranslate.rawValue
    @State private var openAIKey = ""
    @State private var openAIStatus: String?
    @State private var openAIStatusIsOK = false
    @State private var isTesting = false

    private var isUsingGoogle: Bool {
        ProviderType(rawValue: defaultProvider) == .googleTranslate
    }

    var body: some View {
        SettingsPage(title: String(localized: "API Keys"), subtitle: String(localized: "Store provider credentials securely in macOS Keychain.")) {
            if isUsingGoogle {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text("You're using Google Translate (free). Switch to OpenAI in General settings for AI-powered translation with context support.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.blue.opacity(0.12), lineWidth: 1)
                }
            }

            SettingsCard(systemImage: "sparkles", title: String(localized: "OpenAI"), subtitle: String(localized: "Used for translation and streaming responses.")) {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("sk-proj-...", text: $openAIKey)
                        .font(.system(size: 13, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(.background.opacity(0.50), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.primary.opacity(0.10), lineWidth: 1)
                        }

                    HStack(spacing: 10) {
                        SettingsButton(String(localized: "Save"), systemImage: "lock.doc", isPrimary: true) { saveOpenAIKey() }
                            .disabled(openAIKey.isEmpty)
                        SettingsButton(String(localized: "Test"), systemImage: "checkmark.seal") { testOpenAIKey() }
                            .disabled(openAIKey.isEmpty || isTesting)

                        if isTesting { ProgressView().scaleEffect(0.75) }
                        if let status = openAIStatus {
                            Text(status)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(openAIStatusIsOK ? Color.green : Color.red)
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
            openAIStatus = String(localized: "status.saved")
            openAIStatusIsOK = true
        } catch {
            openAIStatus = error.localizedDescription
            openAIStatusIsOK = false
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
                    openAIStatusIsOK = code == 200
                    openAIStatus = code == 200 ? String(localized: "status.validKey") : String(localized: "status.httpError \(code)")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    openAIStatus = String(localized: "status.networkError")
                    openAIStatusIsOK = false
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
        SettingsPage(title: String(localized: "Hotkeys"), subtitle: String(localized: "Quick actions available globally while the app is running.")) {
            SettingsCard(systemImage: "keyboard", title: String(localized: "Shortcuts"), subtitle: String(localized: "Click a shortcut field, then press your desired key combo.")) {
                VStack(spacing: 10) {
                    HotkeyRecorderRow(
                        title: String(localized: "Translate Selected Text"),
                        systemImage: "character.cursor.ibeam",
                        action: .translate,
                        binding: $hotkeyStore.translateBinding,
                        store: hotkeyStore
                    )
                    HotkeyRecorderRow(
                        title: String(localized: "Screenshot OCR"),
                        systemImage: "viewfinder",
                        action: .screenshot,
                        binding: $hotkeyStore.screenshotBinding,
                        store: hotkeyStore
                    )
                }
            }

            if let error = hotkeyStore.registrationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(String(localized: "Failed to register \(error.action.rawValue) hotkey: \(error.message)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }

            HStack {
                SettingsButton(String(localized: "Reset to Defaults"), systemImage: "arrow.counterclockwise") {
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
        SettingsPage(title: String(localized: "About"), subtitle: String(localized: "Version info and software updates.")) {
            SettingsCard(systemImage: "app.badge", title: String(localized: "HotLingo"), subtitle: String(localized: "Fast Vi↔En translation for macOS.")) {
                HStack(spacing: 16) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HotLingo").font(.system(size: 15, weight: .semibold))
                        Text("Version \(updateService.currentVersion)")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            SettingsCard(systemImage: "arrow.down.circle", title: String(localized: "Software Update"), subtitle: String(localized: "Check GitHub Releases for a newer version.")) {
                VStack(alignment: .leading, spacing: 12) {
                    updateStatusView
                    HStack(spacing: 10) {
                        checkButton
                        if case .available = updateService.state { installButton }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateService.state {
        case .idle: EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Checking for updates…").font(.caption).foregroundStyle(.secondary)
            }
        case .upToDate:
            Label("You're up to date.", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium)).foregroundStyle(.green)
        case .available(let version):
            Label("Version \(version) is available.", systemImage: "arrow.down.circle.fill")
                .font(.caption.weight(.medium)).foregroundStyle(.blue)
        case .installing:
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.75)
                Text("Downloading update…").font(.caption).foregroundStyle(.secondary)
            }
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checkButton: some View {
        let isBusy = updateService.state == .checking || updateService.state == .installing
        return SettingsButton(String(localized: "Check for Updates"), systemImage: "arrow.clockwise", isPrimary: true) {
            updateService.checkForUpdates()
        }
        .disabled(isBusy)
    }

    private var installButton: some View {
        SettingsButton(String(localized: "Install Update"), systemImage: "arrow.down.circle") {
            updateService.installUpdate()
        }
    }
}
