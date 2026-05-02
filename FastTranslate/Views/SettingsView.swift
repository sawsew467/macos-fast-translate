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
        .frame(width: 460, height: 320)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage(Constants.UserDefaultsKey.persistentContext) private var persistentContext = ""
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Text("Persistent Context")
                    .font(.headline)
                Text("Included in every translation for better accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $persistentContext)
                    .font(.system(size: 13))
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor), lineWidth: 1))
            }

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
        }
        .padding(16)
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
        Form {
            Section("OpenAI API Key") {
                SecureField("sk-proj-…", text: $openAIKey)
                    .font(.system(size: 13, design: .monospaced))
                HStack(spacing: 8) {
                    Button("Save to Keychain") { saveOpenAIKey() }
                        .disabled(openAIKey.isEmpty)
                    Button("Test") { testOpenAIKey() }
                        .disabled(openAIKey.isEmpty || isTesting)
                    if isTesting { ProgressView().scaleEffect(0.7) }
                    if let status = openAIStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status.hasPrefix("✓") ? Color.green : Color.red)
                    }
                }
            }
        }
        .padding(16)
        .onAppear {
            openAIKey = KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) ?? ""
        }
    }

    private func saveOpenAIKey() {
        do {
            try KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: openAIKey)
            openAIStatus = "✓ Saved"
        } catch {
            openAIStatus = "✗ \(error.localizedDescription)"
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
                    openAIStatus = code == 200 ? "✓ Valid key" : "✗ Invalid (HTTP \(code))"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    openAIStatus = "✗ Network error"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Hotkeys Tab

struct HotkeysSettingsTab: View {
    var body: some View {
        Form {
            Section("Current Hotkeys") {
                LabeledContent("Translate Selected Text", value: "⌃⌥T")
                LabeledContent("Screenshot OCR", value: "⌃⌥S")
            }
            Text("Hotkey customization coming in v2.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}
