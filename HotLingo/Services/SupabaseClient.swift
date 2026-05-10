import Foundation

// MARK: - SupabaseClient

actor SupabaseClient {
    static let shared = SupabaseClient()
    /// Coalesces concurrent refresh attempts — all callers await the same in-flight task.
    private var refreshTask: Task<Void, Error>?

    // MARK: - Public API

    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> T {
        let data = try await performRequest(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
        return try JSONDecoder().decode(T.self, from: data)
    }

    func requestRaw(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authenticated: Bool = true
    ) async throws -> Data {
        try await performRequest(
            endpoint: endpoint, method: method,
            body: body, authenticated: authenticated
        )
    }

    /// Stream SSE events from a POST endpoint.
    /// Yields raw payload strings from `data: <payload>` lines (prefix stripped).
    /// Automatically refreshes the access token when it is expiring soon or when
    /// the server returns 401. Retries the stream once after a successful refresh.
    func streamSSE<B: Encodable>(endpoint: String, body: B) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Proactively refresh before the stream starts if token is close to expiry.
                    if self.isTokenExpiringSoon {
                        try await self.refreshTokenIfNeeded()
                    }
                    try await self.runSSEStream(
                        endpoint: endpoint, body: body,
                        continuation: continuation, isRetry: false
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Executes the SSE stream request. On 401, refreshes token and retries once.
    private func runSSEStream<B: Encodable>(
        endpoint: String,
        body: B,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        isRetry: Bool
    ) async throws {
        guard let token = accessToken else { throw SupabaseError.notAuthenticated }

        var req = URLRequest(url: URL(string: "\(Constants.Supabase.url)\(endpoint)")!)
        req.httpMethod = "POST"
        req.setValue(Constants.Supabase.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }

        if http.statusCode == 401 && !isRetry {
            // Token expired mid-flight — refresh and retry once.
            try await refreshTokenIfNeeded()
            try await runSSEStream(endpoint: endpoint, body: body, continuation: continuation, isRetry: true)
            return
        }
        guard http.statusCode < 400 else { throw SupabaseError.httpError(http.statusCode) }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            // Consume the sentinel internally — do not leak it to callers.
            if payload == "[DONE]" { break }
            continuation.yield(payload)
        }
        continuation.finish()
    }

    // MARK: - Token Management

    var accessToken: String? {
        KeychainHelper.load(account: Constants.KeychainAccount.supabaseAccessToken)
    }

    var isLoggedIn: Bool { accessToken != nil }

    /// Returns true when the access token is missing or expires within 60 seconds.
    var isTokenExpiringSoon: Bool {
        guard let token = accessToken, let expiry = jwtExpiry(from: token) else { return true }
        return expiry.timeIntervalSinceNow < 60
    }

    /// Decodes the `exp` claim from a JWT without external dependencies.
    private func jwtExpiry(from token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem != 0 { base64 += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    func saveTokens(access: String, refresh: String) {
        try? KeychainHelper.save(account: Constants.KeychainAccount.supabaseAccessToken, value: access)
        try? KeychainHelper.save(account: Constants.KeychainAccount.supabaseRefreshToken, value: refresh)
    }

    func clearTokens() {
        try? KeychainHelper.delete(account: Constants.KeychainAccount.supabaseAccessToken)
        try? KeychainHelper.delete(account: Constants.KeychainAccount.supabaseRefreshToken)
        try? KeychainHelper.delete(account: Constants.KeychainAccount.supabaseUserEmail)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionExpired, object: nil)
        }
    }

    // MARK: - Private

    private func performRequest(
        endpoint: String,
        method: String,
        body: (any Encodable)?,
        authenticated: Bool
    ) async throws -> Data {
        var req = buildURLRequest(endpoint: endpoint, method: method, body: body, authenticated: authenticated)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }

        if http.statusCode == 401 && authenticated {
            try await refreshTokenIfNeeded()
            req = buildURLRequest(endpoint: endpoint, method: method, body: body, authenticated: true)
            let (retryData, retryResp) = try await URLSession.shared.data(for: req)
            guard let retryHttp = retryResp as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
            guard retryHttp.statusCode < 400 else {
            throw SupabaseError.parse(data: retryData, statusCode: retryHttp.statusCode)
        }
            return retryData
        }

        guard http.statusCode < 400 else {
            throw SupabaseError.parse(data: data, statusCode: http.statusCode)
        }
        return data
    }

    private func buildURLRequest(
        endpoint: String,
        method: String,
        body: (any Encodable)?,
        authenticated: Bool
    ) -> URLRequest {
        let url = URL(string: "\(Constants.Supabase.url)\(endpoint)")!
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(Constants.Supabase.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authenticated, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = try? JSONEncoder().encode(body) }
        return req
    }

    /// Refreshes the access token using the stored refresh token.
    /// Concurrent callers coalesce on the same in-flight Task so only one
    /// HTTP request is made regardless of how many callers race simultaneously.
    func refreshTokenIfNeeded() async throws {
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<Void, Error> { [self] in
            defer { self.refreshTask = nil }
            try await self.performRefresh()
        }
        refreshTask = task
        try await task.value
    }

    private func performRefresh() async throws {
        guard let refreshToken = KeychainHelper.load(account: Constants.KeychainAccount.supabaseRefreshToken) else {
            clearTokens()
            throw SupabaseError.notAuthenticated
        }

        struct RefreshBody: Encodable { let refresh_token: String }
        struct TokenResponse: Decodable { let access_token: String; let refresh_token: String }

        let url = URL(string: "\(Constants.Supabase.url)/auth/v1/token?grant_type=refresh_token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(Constants.Supabase.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(RefreshBody(refresh_token: refreshToken))

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode < 400 else {
            clearTokens()
            throw SupabaseError.notAuthenticated
        }
        let tokens = try JSONDecoder().decode(TokenResponse.self, from: data)
        saveTokens(access: tokens.access_token, refresh: tokens.refresh_token)
    }
}

// MARK: - SupabaseError

enum SupabaseError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "Please log in to use AI Translation."
        case .invalidResponse:      return "Invalid server response."
        case .httpError(let code):  return "Server error (HTTP \(code))."
        case .serverError(let msg): return msg
        }
    }

    /// Parse Supabase error body to extract a human-readable message.
    /// Supabase returns: { "msg": "..." } or { "error_description": "..." } or { "message": "..." }
    static func parse(data: Data, statusCode: Int) -> SupabaseError {
        struct SupabaseErrorBody: Decodable {
            let msg: String?
            let message: String?
            let error_description: String?
            let error: String?
        }
        if let body = try? JSONDecoder().decode(SupabaseErrorBody.self, from: data) {
            let detail = body.msg ?? body.message ?? body.error_description ?? body.error
            if let detail, !detail.isEmpty {
                return .serverError("[\(statusCode)] \(detail)")
            }
        }
        if let raw = String(data: data, encoding: .utf8), !raw.isEmpty {
            return .serverError("[\(statusCode)] \(raw)")
        }
        return .httpError(statusCode)
    }
}
