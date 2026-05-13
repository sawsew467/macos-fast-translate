import AppKit
import SwiftUI

struct OnboardingProviderStep: View {
    @AppStorage(Constants.UserDefaultsKey.defaultProvider)
    private var defaultProvider = ProviderType.googleTranslate.rawValue

    @ObservedObject private var authService = SupabaseAuthService.shared

    private var selectedProvider: ProviderType {
        ProviderType(rawValue: defaultProvider) ?? .googleTranslate
    }

    var body: some View {
        SetupCard(
            systemImage: "sparkles",
            tint: .purple,
            title: String(localized: "Choose your translator"),
            subtitle: String(localized: "You can change this anytime in Settings.")
        ) {
            VStack(spacing: 10) {
                ProviderOptionCard(
                    systemImage: "wand.and.stars",
                    title: String(localized: "AI Translation"),
                    subtitle: aiSubtitle,
                    badge: String(localized: "Recommended"),
                    isSelected: selectedProvider == .aiTranslation
                ) {
                    defaultProvider = ProviderType.aiTranslation.rawValue
                    if !authService.authState.isLoggedIn {
                        ProviderFormPanel.shared.openAI()
                    }
                }

                ProviderOptionCard(
                    systemImage: "sparkles",
                    title: String(localized: "OpenAI GPT"),
                    subtitle: String(localized: "Bring your own API key"),
                    badge: nil,
                    isSelected: selectedProvider == .openAI
                ) {
                    defaultProvider = ProviderType.openAI.rawValue
                    ProviderFormPanel.shared.openOpenAIKey()
                }

                ProviderOptionCard(
                    systemImage: "globe",
                    title: String(localized: "Google Translate"),
                    subtitle: String(localized: "Free, no setup needed"),
                    badge: nil,
                    isSelected: selectedProvider == .googleTranslate
                ) {
                    defaultProvider = ProviderType.googleTranslate.rawValue
                    ProviderFormPanel.shared.close()
                }
            }
        }
    }

    private var aiSubtitle: String {
        if authService.authState.isLoggedIn {
            return String(localized: "auth.loggedInAs \(authService.authState.email ?? "")")
        }
        return String(localized: "50 free translations to get started")
    }
}

// MARK: - Keyable Panel

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Floating Panel Manager

@MainActor
final class ProviderFormPanel {
    static let shared = ProviderFormPanel()
    private var panel: NSPanel?

    func openAI() {
        open(width: 300, height: 240) {
            AIAuthPanelView(onDismiss: { ProviderFormPanel.shared.close() })
        }
    }

    func openOpenAIKey() {
        open(width: 300, height: 200) {
            OpenAIKeyPanelView(onDismiss: { ProviderFormPanel.shared.close() })
        }
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func open<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) {
        close()

        let newPanel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: LocaleWrapper { content() })
        newPanel.contentView = hostingView
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.cornerRadius = 20
        newPanel.contentView?.layer?.cornerCurve = .continuous
        newPanel.contentView?.layer?.masksToBounds = true

        center(newPanel)
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = newPanel
    }

    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { panel.center(); return }
        let sf = screen.visibleFrame
        let pw = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: sf.midX - pw.width / 2,
            y: sf.midY - pw.height / 2
        ))
    }
}

// MARK: - AI Auth Panel View

struct AIAuthPanelView: View {
    let onDismiss: () -> Void

    @ObservedObject private var authService = SupabaseAuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var otp = ""
    @State private var pendingOTPEmail: String?
    @State private var pendingPasswordResetEmail: String?
    @State private var resetOTP = ""
    @State private var newPassword = ""
    @State private var showPasswordResetAction = false
    @State private var trialMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text(panelTitle)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if authService.authState.isLoggedIn {
                loggedInView
            } else if let resetEmail = pendingPasswordResetEmail {
                passwordResetView(email: resetEmail)
            } else if let otpEmail = pendingOTPEmail {
                otpView(email: otpEmail)
            } else {
                authForm
            }
        }
        .padding(18)
        .glassPanel()
    }

    private var panelTitle: String {
        if authService.authState.isLoggedIn { return String(localized: "Signed in") }
        if pendingPasswordResetEmail != nil { return String(localized: "Reset password") }
        if pendingOTPEmail != nil { return String(localized: "Enter verification code") }
        return isSignup ? String(localized: "Create account") : String(localized: "Sign in to AI Translation")
    }

    // MARK: - Logged in

    private var loggedInView: some View {
        VStack(spacing: 10) {
            Label(String(localized: "auth.loggedInAs \(authService.authState.email ?? "")"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
            if let msg = trialMessage {
                Text(msg).font(.caption).foregroundStyle(.green)
            }
            Button("Done", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }

    // MARK: - OTP step

    private func otpView(email: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("We sent a 6-digit code to")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.system(size: 12, weight: .semibold))
            }

            TextField("000000", text: $otp)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(10)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12)) }
                .onChange(of: otp) { newValue in
                    otp = String(newValue.filter(\.isNumber).prefix(6))
                }

            HStack(spacing: 8) {
                Button("Verify") {
                    Task { await handleOTP(email: email) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(otp.count < 6)

                Button("Resend code") {
                    Task { await resendSignupOTP(email: email) }
                }
                .font(.caption)
                .controlSize(.small)
                .buttonStyle(.plain)
                .disabled(authService.authState == .loading)

                Button("Back") {
                    pendingOTPEmail = nil
                    otp = ""
                    authService.authError = nil
                }
                .controlSize(.small)
                .buttonStyle(.plain)

                if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
            }

            if let error = authService.authError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Password reset step

    private func passwordResetView(email: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("We sent a 6-digit code to")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(email)
                    .font(.system(size: 12, weight: .semibold))
            }

            TextField("000000", text: $resetOTP)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(10)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12)) }
                .onChange(of: resetOTP) { newValue in
                    resetOTP = String(newValue.filter(\.isNumber).prefix(6))
                }

            SecureField("New password", text: $newPassword)
                .textFieldStyle(.plain)
                .padding(9)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12)) }

            HStack(spacing: 8) {
                Button("Update") {
                    Task { await handlePasswordReset(email: email) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(resetOTP.count < 6 || newPassword.count < 6)

                Button("Resend code") {
                    Task { await resendPasswordResetOTP(email: email) }
                }
                .font(.caption)
                .controlSize(.small)
                .buttonStyle(.plain)
                .disabled(authService.authState == .loading)

                Button("Back") {
                    pendingPasswordResetEmail = nil
                    resetOTP = ""
                    newPassword = ""
                    authService.authError = nil
                }
                .controlSize(.small)
                .buttonStyle(.plain)

                if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
            }

            if let error = authService.authError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Auth form

    private var authForm: some View {
        VStack(spacing: 8) {
            TextField("Email", text: $email)
                .textFieldStyle(.plain)
                .padding(9)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12)) }

            SecureField("Password", text: $password)
                .textFieldStyle(.plain)
                .padding(9)
                .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(.primary.opacity(0.12)) }

            HStack(spacing: 8) {
                Button(isSignup ? "Sign Up" : "Log In") {
                    Task { await handleAuth() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(email.isEmpty || password.isEmpty)

                Button(isSignup ? String(localized: "Have account?") : String(localized: "New? Sign up")) {
                    isSignup.toggle()
                    showPasswordResetAction = false
                    authService.authError = nil
                }
                    .font(.caption)
                    .buttonStyle(.plain)

                if !isSignup && showPasswordResetAction {
                    Button("Reset password") {
                        Task { await startPasswordReset() }
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .disabled(email.isEmpty || authService.authState == .loading)
                }

                if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
            }

            if let error = authService.authError {
                Text(error).font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Actions

    private func handleAuth() async {
        if isSignup {
            showPasswordResetAction = false
            await authService.signup(email: email, password: password)
            if authService.authError == nil {
                pendingOTPEmail = email
            }
        } else {
            await authService.login(email: email, password: password)
            if authService.authState.isLoggedIn {
                showPasswordResetAction = false
                let claimed = await CreditService.shared.claimTrial()
                trialMessage = claimed ? "50 free credits granted!" : nil
            } else {
                showPasswordResetAction = authService.authError != nil
            }
        }
    }

    private func startPasswordReset() async {
        await authService.sendPasswordResetOTP(email: email)
        if authService.authError == nil {
            pendingPasswordResetEmail = email
            resetOTP = ""
            newPassword = ""
            showPasswordResetAction = false
        }
    }

    private func handlePasswordReset(email: String) async {
        await authService.resetPassword(email: email, token: resetOTP, newPassword: newPassword)
        if authService.authState.isLoggedIn {
            pendingPasswordResetEmail = nil
            resetOTP = ""
            newPassword = ""
            let claimed = await CreditService.shared.claimTrial()
            trialMessage = claimed ? "50 free credits granted!" : nil
        }
    }

    private func resendSignupOTP(email: String) async {
        await authService.resendSignupOTP(email: email)
        if authService.authError == nil { otp = "" }
    }

    private func resendPasswordResetOTP(email: String) async {
        await authService.sendPasswordResetOTP(email: email)
        if authService.authError == nil { resetOTP = "" }
    }

    private func handleOTP(email: String) async {
        await authService.verifySignupOTP(email: email, token: otp)
        if authService.authState.isLoggedIn {
            let claimed = await CreditService.shared.claimTrial()
            trialMessage = claimed ? "50 free credits granted!" : nil
        }
    }
}

// MARK: - OpenAI Key Panel View

struct OpenAIKeyPanelView: View {
    let onDismiss: () -> Void

    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testStatus: String?
    @State private var isValidKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "key")
                Text("OpenAI API Key")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            SecureField("sk-proj-...", text: $apiKey)
                .font(.system(size: 13, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(.background.opacity(0.62), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.primary.opacity(0.10)) }

            HStack(spacing: 8) {
                Button("Test") { testAPIKey() }
                    .controlSize(.small)
                    .disabled(apiKey.isEmpty || isTesting)

                Button("Save") { saveAPIKey() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidKey)

                if isTesting { ProgressView().scaleEffect(0.7) }

                if let status = testStatus {
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isValidKey ? .green : .red)
                }
            }
        }
        .padding(18)
        .glassPanel()
    }

    private func saveAPIKey() {
        try? KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: apiKey)
        testStatus = String(localized: "status.saved")
        isValidKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { onDismiss() }
    }

    private func testAPIKey() {
        isTesting = true; testStatus = nil
        Task {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": "gpt-4o-mini",
                "messages": [["role": "user", "content": "Hi"]],
                "max_tokens": 5
            ])
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    isValidKey = code == 200
                    testStatus = code == 200 ? String(localized: "status.validKey") : String(localized: "status.httpError \(code)")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testStatus = String(localized: "status.networkError")
                    isValidKey = false
                    isTesting = false
                }
            }
        }
    }
}
