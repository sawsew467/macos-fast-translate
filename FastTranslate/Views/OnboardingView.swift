import SwiftUI
import ApplicationServices

/// First-launch setup flow: API key, permissions, and hotkey primer.
struct OnboardingView: View {
    let onDismiss: () -> Void
    @AppStorage(Constants.UserDefaultsKey.onboardingStep) private var step = 0
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testStatus: String?
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()

    private let steps = ["API Key", "Permissions", "Ready"]

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                header

                ZStack {
                    switch step {
                    case 0: apiKeyStep
                    case 1: permissionsStep
                    default: doneStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 34)

                navigationButtons
                    .padding(24)
            }
        }
        .frame(width: 760, height: 540)
    }

    private var onboardingBackground: some View {
        Color(NSColor.windowBackgroundColor).ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FastTranslate")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Quick setup for menu bar translation")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 310, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    StepPill(title: steps[index], index: index + 1, isActive: index == step, isComplete: index < step)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
            }

            Spacer()

            Button(step < 2 ? "Continue" : "Start Using FastTranslate") {
                if step < 2 { step += 1 } else { onDismiss() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var apiKeyStep: some View {
        SetupCard(systemImage: "key.viewfinder", tint: .teal, title: "Connect OpenAI", subtitle: "Your key is stored securely in Keychain and never written to project files.") {
            VStack(alignment: .leading, spacing: 12) {
                SecureField("sk-proj-...", text: $apiKey)
                    .font(.system(size: 13, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.primary.opacity(0.10), lineWidth: 1)
                    }

                HStack(spacing: 10) {
                    Button("Test Key") { testAPIKey() }
                        .disabled(apiKey.isEmpty || isTesting)
                    Button("Save to Keychain") { saveKey() }
                        .disabled(testStatus?.hasPrefix("OK") != true)
                        .buttonStyle(.borderedProminent)

                    if isTesting { ProgressView().scaleEffect(0.72) }
                    if let status = testStatus {
                        Text(status)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(status.hasPrefix("OK") ? .green : .red)
                    }
                    Spacer()
                }
            }
        }
    }

    private var permissionsStep: some View {
        SetupCard(systemImage: "lock.shield", tint: .orange, title: "Grant permissions", subtitle: "macOS needs approval before FastTranslate can read selected text or capture OCR screenshots.") {
            VStack(spacing: 12) {
                PermissionRow(
                    title: "Accessibility",
                    detail: "Read selected text with Control + Option + T",
                    isGranted: hasAccessibility,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                PermissionRow(
                    title: "Screen Recording",
                    detail: "Capture OCR regions with Control + Option + S",
                    isGranted: hasScreenRecording,
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                )
            }
        }
        .onAppear {
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

    private var doneStep: some View {
        SetupCard(systemImage: "checkmark.seal.fill", tint: .green, title: "You're ready", subtitle: "FastTranslate lives in the menu bar. Use the hotkeys below whenever you need instant translation.") {
            VStack(spacing: 12) {
                HotkeyBadgeRow(hotkey: "⌃⌥T", label: "Translate selected text")
                HotkeyBadgeRow(hotkey: "⌃⌥S", label: "Screenshot OCR + translate")
                HotkeyBadgeRow(hotkey: "Menu Bar", label: "Type longer text with optional context")
            }
        }
    }

    private func saveKey() {
        try? KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: apiKey)
        testStatus = "OK Saved"
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
                    testStatus = code == 200 ? "OK Valid key" : "Invalid HTTP \(code)"
                    isTesting = false
                }
            } catch {
                await MainActor.run { testStatus = "Network error"; isTesting = false }
            }
        }
    }
}


private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.10), radius: 28, x: 0, y: 16)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.70), lineWidth: 1) }
                .overlay { shape.stroke(.primary.opacity(0.08), lineWidth: 1) }
                .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 14)
        }
    }
}

private struct LiquidGlassCapsuleModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        let shape = Capsule(style: .continuous)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay { shape.stroke(.white.opacity(0.65), lineWidth: 1) }
                .overlay { shape.stroke(.primary.opacity(isActive ? 0.16 : 0.07), lineWidth: 1) }
        }
    }
}

private struct StepPill: View {
    let title: String
    let index: Int
    let isActive: Bool
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(isComplete ? Color.green : (isActive ? Color.accentColor : Color.secondary.opacity(0.18)))
                if isComplete {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(index)").font(.system(size: 10, weight: .bold)).foregroundStyle(isActive ? .white : .secondary)
                }
            }
            .frame(width: 18, height: 18)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 94)
        .frame(height: 30)
        .modifier(LiquidGlassCapsuleModifier(isActive: isActive))
    }
}

private struct SetupCard<Content: View>: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 6) {
                Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content()
                .frame(maxWidth: 430)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassCardModifier(cornerRadius: 30))
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let settingsURL: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(isGranted ? Color.green : Color.orange)
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .bold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Text("Granted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: settingsURL)!)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(12)
        .background(.background.opacity(0.50), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct HotkeyBadgeRow: View {
    let hotkey: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            Text(hotkey)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 86, height: 30)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.primary.opacity(0.10), lineWidth: 1) }
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(.background.opacity(0.38), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
