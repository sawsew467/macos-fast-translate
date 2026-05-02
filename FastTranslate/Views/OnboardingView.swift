import SwiftUI
import ApplicationServices

/// Three-step first-launch wizard: API key → permissions → done.
struct OnboardingView: View {
    let onDismiss: () -> Void
    @AppStorage(Constants.UserDefaultsKey.onboardingStep) private var step = 0
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testStatus: String?
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()

    var body: some View {
        VStack(spacing: 0) {
            stepDots.padding(.top, 24)
            Spacer()
            Group {
                switch step {
                case 0: apiKeyStep
                case 1: permissionsStep
                default: doneStep
                }
            }
            Spacer()
            navigationButtons.padding(24)
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - Step dots indicator

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Navigation buttons

    private var navigationButtons: some View {
        HStack {
            if step > 0 {
                Button("Back") { step -= 1 }.buttonStyle(.plain)
            }
            Spacer()
            if step > 0 {
                Button(step < 2 ? "Continue" : "Start Using FastTranslate") {
                    if step < 2 { step += 1 } else { onDismiss() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Step 1: API Key

    private var apiKeyStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill").font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text("Welcome to FastTranslate").font(.title2.bold())
            Text("Enter your OpenAI API key to get started.\nIt will be stored securely in Keychain.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 8) {
                SecureField("sk-proj-…", text: $apiKey)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
                HStack {
                    Button("Test Key") { testAPIKey() }
                        .disabled(apiKey.isEmpty || isTesting)
                    if isTesting { ProgressView().scaleEffect(0.7) }
                    if let status = testStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(status.hasPrefix("✓") ? Color.green : Color.red)
                    }
                    Spacer()
                    Button("Save to Keychain") { saveKey() }
                        .disabled(testStatus?.hasPrefix("✓") != true)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: 340)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield").font(.system(size: 40)).foregroundStyle(Color.accentColor)
            Text("Grant Permissions").font(.title2.bold())
            Text("FastTranslate needs these permissions to work.")
                .font(.body).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Required to read selected text  (⌃⌥T)",
                    isGranted: hasAccessibility,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                PermissionRow(
                    title: "Screen Recording",
                    detail: "Required for screenshot OCR  (⌃⌥S)",
                    isGranted: hasScreenRecording,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 40)
        .onAppear {
            // Trigger permission requests so macOS adds the app to both lists.
            CGRequestScreenCaptureAccess()
            if !AXIsProcessTrusted() {
                let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                AXIsProcessTrustedWithOptions(opts)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            hasAccessibility = AXIsProcessTrusted()
            hasScreenRecording = CGPreflightScreenCaptureAccess()
        }
    }

    // MARK: - Step 3: Done

    private var doneStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50)).foregroundStyle(.green)
            Text("You're all set!").font(.title2.bold())
            VStack(alignment: .leading, spacing: 8) {
                HotkeyBadgeRow(hotkey: "⌃⌥T", label: "Translate selected text")
                HotkeyBadgeRow(hotkey: "⌃⌥S", label: "Screenshot OCR + translate")
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private func saveKey() {
        try? KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: apiKey)
        testStatus = "✓ Saved"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { step += 1 }
    }

    private func testAPIKey() {
        isTesting = true
        testStatus = nil
        Task {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
                    testStatus = code == 200 ? "✓ Valid key" : "✗ Invalid (HTTP \(code))"
                    isTesting = false
                }
            } catch {
                await MainActor.run { testStatus = "✗ Network error"; isTesting = false }
            }
        }
    }
}

// MARK: - Shared subviews

struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !isGranted {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: settingsURL)!)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

struct HotkeyBadgeRow: View {
    let hotkey: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Text(hotkey)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)
            Text(label).font(.system(size: 13))
        }
    }
}
