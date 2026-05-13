import Foundation

@MainActor
final class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()

    @Published var authState: AuthState = .loggedOut {
        didSet {
            if case .loggedIn = authState {
                let hadEverLoggedIn = UserDefaults.standard.bool(forKey: Constants.UserDefaultsKey.hasEverLoggedIn)
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.hasEverLoggedIn)
                selectAITranslationForFirstAccountLoginIfNeeded(hadEverLoggedIn: hadEverLoggedIn)
            } else if case .loggedIn = oldValue {
                fallbackFromAITranslationIfNeeded()
            }
        }
    }
    @Published var authError: String?

    private init() {
        restoreSession()
        // Silently refresh if the stored token is expiring soon.
        Task { await validateAndRefreshIfNeeded() }
        NotificationCenter.default.addObserver(
            forName: .sessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.authState = .loggedOut
            }
        }
    }

    // MARK: - Public API

    func login(email: String, password: String) async {
        authState = .loading
        authError = nil
        do {
            let response: AuthTokenResponse = try await SupabaseClient.shared.request(
                endpoint: "/auth/v1/token?grant_type=password",
                method: "POST",
                body: LoginBody(email: email, password: password),
                authenticated: false
            )
            await SupabaseClient.shared.saveTokens(
                access: response.access_token,
                refresh: response.refresh_token
            )
            try? KeychainHelper.save(
                account: Constants.KeychainAccount.supabaseUserEmail,
                value: email
            )
            authState = .loggedIn(email: email)
            Task { await DeviceTrackingService.shared.linkToUser() }
        } catch {
            authState = .loggedOut
            authError = parseAuthError(error)
        }
    }

    func signup(email: String, password: String) async {
        authState = .loading
        authError = nil
        do {
            let _: SignupResponse = try await SupabaseClient.shared.request(
                endpoint: "/auth/v1/signup",
                method: "POST",
                body: LoginBody(email: email, password: password),
                authenticated: false
            )
            authState = .loggedOut
            authError = nil
        } catch {
            authState = .loggedOut
            authError = parseAuthError(error)
        }
    }

    /// Verify 6-digit OTP sent to email after signup. On success, saves tokens and logs in.
    func verifySignupOTP(email: String, token: String) async {
        authState = .loading
        authError = nil
        do {
            let response: AuthTokenResponse = try await SupabaseClient.shared.request(
                endpoint: "/auth/v1/verify",
                method: "POST",
                body: OTPVerifyBody(type: "signup", email: email, token: token),
                authenticated: false
            )
            await SupabaseClient.shared.saveTokens(
                access: response.access_token,
                refresh: response.refresh_token
            )
            try? KeychainHelper.save(
                account: Constants.KeychainAccount.supabaseUserEmail,
                value: email
            )
            authState = .loggedIn(email: email)
            Task { await DeviceTrackingService.shared.linkToUser() }
        } catch {
            authState = .loggedOut
            authError = parseAuthError(error)
        }
    }

    func logout() {
        Task { await SupabaseClient.shared.clearTokens() }
        authState = .loggedOut
        authError = nil
    }

    func restoreSession() {
        if let email = KeychainHelper.load(account: Constants.KeychainAccount.supabaseUserEmail),
           KeychainHelper.load(account: Constants.KeychainAccount.supabaseAccessToken) != nil {
            authState = .loggedIn(email: email)
        } else {
            authState = .loggedOut
        }
    }

    /// Silently refreshes the access token on startup if it is expired or expiring soon.
    /// Logs out only when the refresh token itself is invalid (session truly ended).
    private func validateAndRefreshIfNeeded() async {
        guard case .loggedIn = authState else { return }
        let client = SupabaseClient.shared
        guard await client.isTokenExpiringSoon else { return }
        do {
            try await client.refreshTokenIfNeeded()
        } catch {
            // Refresh token expired — session is truly over.
            authState = .loggedOut
        }
    }

    // MARK: - Private

    private func fallbackFromAITranslationIfNeeded() {
        let key = Constants.UserDefaultsKey.defaultProvider
        let currentProvider = ProviderType(rawValue: UserDefaults.standard.string(forKey: key) ?? "")
        guard currentProvider == .aiTranslation else { return }

        let openAIKey = KeychainHelper.load(account: Constants.KeychainAccount.openAIAPIKey) ?? ""
        let fallbackProvider: ProviderType = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .googleTranslate
            : .openAI

        UserDefaults.standard.set(fallbackProvider.rawValue, forKey: key)
    }

    private func selectAITranslationForFirstAccountLoginIfNeeded(hadEverLoggedIn: Bool) {
        guard !hadEverLoggedIn else { return }

        let key = Constants.UserDefaultsKey.defaultProvider
        let storedProvider = UserDefaults.standard.string(forKey: key) ?? ""
        let currentProvider = ProviderType(rawValue: storedProvider)
        guard UserDefaults.standard.object(forKey: key) == nil || currentProvider == .googleTranslate else { return }

        UserDefaults.standard.set(ProviderType.aiTranslation.rawValue, forKey: key)
    }

    private func parseAuthError(_ error: Error) -> String {
        if let supaErr = error as? SupabaseError {
            switch supaErr {
            case .serverError(let raw):
                return friendlyAuthMessage(from: raw)
            case .notAuthenticated:
                return "Please log in to continue."
            case .invalidResponse:
                return "Something went wrong. Please try again."
            case .httpError(let code):
                return code >= 500
                    ? "Server is temporarily unavailable. Please try again later."
                    : "Something went wrong. Please try again."
            }
        }
        let nsErr = error as NSError
        if nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorNotConnectedToInternet {
            return "No internet connection. Please check your network."
        }
        return "Something went wrong. Please try again."
    }

    /// Maps raw Supabase server error strings to human-readable messages.
    private func friendlyAuthMessage(from raw: String) -> String {
        let msg = raw.lowercased()
        switch true {
        case msg.contains("invalid login credentials"), msg.contains("invalid email or password"):
            return "Incorrect email or password. Please try again."
        case msg.contains("email not confirmed"):
            return "Please verify your email before logging in. Check your inbox."
        case msg.contains("user not found"):
            return "No account found with this email."
        case msg.contains("user already registered"), msg.contains("already registered"):
            return "This email is already registered. Try logging in instead."
        case msg.contains("password should be"), msg.contains("password must be"):
            return "Password must be at least 6 characters."
        case msg.contains("token has expired"), msg.contains("otp has expired"):
            return "Verification code has expired. Please request a new one."
        case msg.contains("invalid otp"), msg.contains("token is invalid"):
            return "Invalid verification code. Please check and try again."
        case msg.contains("rate limit"), msg.contains("too many requests"):
            return "Too many attempts. Please wait a moment and try again."
        default:
            // Strip the [400] HTTP prefix if present, fall back to cleaned message
            let stripped = raw.replacingOccurrences(of: #"^\[\d+\]\s*"#, with: "", options: .regularExpression)
            return stripped.isEmpty ? "Something went wrong. Please try again." : stripped
        }
    }
}

// MARK: - Request/Response models

private struct LoginBody: Encodable {
    let email: String
    let password: String
}

private struct OTPVerifyBody: Encodable {
    let type: String
    let email: String
    let token: String
}

private struct AuthTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
}

private struct SignupResponse: Decodable {
    let id: String?
}
