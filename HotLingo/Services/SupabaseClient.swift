import Foundation

// MARK: - SupabaseClient

actor SupabaseClient {
    static let shared = SupabaseClient()
    private var isRefreshing = false

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
    /// Caller handles JSON parsing, "[DONE]" sentinel, and error events.
    func streamSSE<B: Encodable>(endpoint: String, body: B) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let token = self.accessToken else {
                    continuation.finish(throwing: SupabaseError.notAuthenticated)
                    return
                }

                let url = URL(string: "\(Constants.Supabase.url)\(endpoint)")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue(Constants.Supabase.anonKey, forHTTPHeaderField: "apikey")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.httpBody = try? JSONEncoder().encode(body)

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: SupabaseError.invalidResponse)
                        return
                    }
                    guard http.statusCode < 400 else {
                        continuation.finish(throwing: SupabaseError.httpError(http.statusCode))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        continuation.yield(payload)
                        if payload == "[DONE]" { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Token Management

    var accessToken: String? {
        KeychainHelper.load(account: Constants.KeychainAccount.supabaseAccessToken)
    }

    var isLoggedIn: Bool { accessToken != nil }

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

    private func refreshTokenIfNeeded() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

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
