import Foundation

@MainActor
final class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()

    @Published var authState: AuthState = .loggedOut {
        didSet {
            if case .loggedIn = authState {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKey.hasEverLoggedIn)
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
            self?.authState = .loggedOut
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

    private func parseAuthError(_ error: Error) -> String {
        if let supaErr = error as? SupabaseError {
            return supaErr.localizedDescription
        }
        return "Login failed. Check your credentials."
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
