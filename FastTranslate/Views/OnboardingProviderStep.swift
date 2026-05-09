import SwiftUI

struct OnboardingProviderStep: View {
    @AppStorage(Constants.UserDefaultsKey.defaultProvider)
    private var defaultProvider = ProviderType.googleTranslate.rawValue

    @ObservedObject private var authService = SupabaseAuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignup = false
    @State private var authMessage: String?
    @State private var trialMessage: String?
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testStatus: String?

    private var selectedProvider: ProviderType {
        ProviderType(rawValue: defaultProvider) ?? .googleTranslate
    }

    var body: some View {
        SetupCard(
            systemImage: "sparkles",
            tint: .purple,
            title: "Choose your translator",
            subtitle: "You can change this anytime in Settings."
        ) {
            VStack(spacing: 14) {
                ProviderOptionCard(
                    systemImage: "wand.and.stars",
                    title: "AI Translation",
                    subtitle: "High quality, 50 free translations",
                    badge: "Recommended",
                    isSelected: selectedProvider == .aiTranslation
                ) { defaultProvider = ProviderType.aiTranslation.rawValue }

                if selectedProvider == .aiTranslation {
                    aiAuthForm
                }

                ProviderOptionCard(
                    systemImage: "sparkles",
                    title: "OpenAI GPT",
                    subtitle: "Bring your own API key",
                    badge: nil,
                    isSelected: selectedProvider == .openAI
                ) { defaultProvider = ProviderType.openAI.rawValue }

                if selectedProvider == .openAI {
                    openAIKeyForm
                }

                ProviderOptionCard(
                    systemImage: "globe",
                    title: "Google Translate",
                    subtitle: "Free, no setup needed",
                    badge: nil,
                    isSelected: selectedProvider == .googleTranslate
                ) { defaultProvider = ProviderType.googleTranslate.rawValue }

                if selectedProvider == .googleTranslate {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Ready to go! No setup needed.")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - AI Auth Form

    @ViewBuilder
    private var aiAuthForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            if authService.authState.isLoggedIn {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Logged in as \(authService.authState.email ?? "")")
                        .font(.system(size: 13, weight: .medium))
                }
                if let msg = trialMessage {
                    Text(msg).font(.caption).foregroundStyle(.green)
                }
            } else {
                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.1)) }

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.1)) }

                HStack(spacing: 10) {
                    Button(isSignup ? "Sign Up" : "Log In") {
                        Task { await handleAuth() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty)

                    Button(isSignup ? "Have account? Log in" : "New? Sign up") {
                        isSignup.toggle()
                    }
                    .font(.caption)

                    if authService.authState == .loading { ProgressView().scaleEffect(0.7) }
                }

                if let error = authService.authError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if let msg = authMessage {
                    Text(msg).font(.caption).foregroundStyle(.blue)
                }
            }
        }
        .padding(.top, 4)
    }

    private func handleAuth() async {
        if isSignup {
            await authService.signup(email: email, password: password)
            if authService.authError == nil {
                authMessage = "Check your email to confirm, then log in."
            }
        } else {
            await authService.login(email: email, password: password)
            if authService.authState.isLoggedIn {
                let claimed = await CreditService.shared.claimTrial()
                trialMessage = claimed ? "50 free credits granted!" : nil
            }
        }
    }

    // MARK: - OpenAI Key Form

    @ViewBuilder
    private var openAIKeyForm: some View {
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
                Button("Save to Keychain") { saveAPIKey() }
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
        .padding(.top, 4)
    }

    private func saveAPIKey() {
        try? KeychainHelper.save(account: Constants.KeychainAccount.openAIAPIKey, value: apiKey)
        testStatus = "OK Saved"
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
