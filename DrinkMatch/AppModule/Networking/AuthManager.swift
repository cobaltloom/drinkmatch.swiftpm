import Foundation

/// Talks to Supabase Auth (GoTrue)'s plain REST endpoints directly —
/// `/auth/v1/token` (sign-in and refresh) and `/auth/v1/logout` — see
/// RestClient's header comment for why this isn't the official SDK.
///
/// An actor rather than a class: Supabase's refresh tokens rotate on every
/// use (each refresh invalidates the previous refresh token), so two
/// concurrent callers both seeing a near-expired token must not both fire a
/// refresh — the second would fail against an already-rotated token. Actor
/// isolation plus `refreshTask` below collapses concurrent refreshes into
/// one in-flight request that everyone awaits.
actor AuthManager {
    static let shared = AuthManager()

    private var session: AuthSessionData?
    private var refreshTask: Task<String, Error>?

    private init() {
        session = KeychainStore.loadSession()
    }

    var currentUserID: UUID? { session?.userID }
    var currentUserEmail: String? { session?.email }

    /// Returns nil when GoTrue requires email confirmation before a session
    /// exists (the caller should prompt the user to check their inbox).
    func signUpWithEmail(email: String, password: String) async throws -> UUID? {
        let data = try await RestClient.request(
            "auth/v1/signup",
            method: .post,
            body: try RestClient.encode(EmailPasswordBody(email: email, password: password)),
            authenticated: false
        )
        let response: SignUpResponse = try RestClient.decode(data)
        guard let accessToken = response.accessToken,
              let refreshToken = response.refreshToken,
              let expiresAt = response.expiresAt,
              let user = response.user else {
            return nil
        }
        let newSession = AuthSessionData(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(expiresAt)),
            userID: user.id,
            email: user.email
        )
        session = newSession
        KeychainStore.save(newSession)
        return newSession.userID
    }

    func signInWithEmail(email: String, password: String) async throws -> UUID {
        let response = try await Self.exchange(grantType: "password", body: EmailPasswordBody(email: email, password: password))
        let newSession = Self.session(from: response)
        session = newSession
        KeychainStore.save(newSession)
        return newSession.userID
    }

    /// `nonce` is the raw (unhashed) nonce SignInView's SignInWithAppleButton
    /// generated (via AppleNonceGenerator) — GoTrue hashes it itself and
    /// compares against the hash embedded in `idToken`'s claims, rejecting
    /// the request if they don't match.
    func signInWithApple(idToken: String, nonce: String) async throws -> UUID {
        let response = try await Self.exchange(grantType: "id_token", body: IDTokenBody(idToken: idToken, provider: "apple", nonce: nonce))
        let newSession = Self.session(from: response)
        session = newSession
        KeychainStore.save(newSession)
        return newSession.userID
    }

    func signOut() async throws {
        if let token = session?.accessToken {
            try? await Self.logout(accessToken: token)
        }
        session = nil
        refreshTask = nil
        KeychainStore.clear()
    }

    /// nil if never signed in. Refreshes first if the current token is
    /// expired or expiring within a minute. If the refresh itself fails
    /// (e.g. the refresh token was revoked), the stale session is cleared
    /// before rethrowing, so the next launch correctly shows sign-in
    /// instead of getting stuck on a session that can never work again.
    func validAccessToken() async throws -> String? {
        guard let session else { return nil }
        if session.expiresAt.timeIntervalSinceNow > 60 {
            return session.accessToken
        }
        do {
            return try await refreshedAccessToken()
        } catch {
            self.session = nil
            KeychainStore.clear()
            throw error
        }
    }

    private func refreshedAccessToken() async throws -> String {
        if let refreshTask { return try await refreshTask.value }
        let task = Task<String, Error> {
            guard let refreshToken = session?.refreshToken else {
                throw RestClient.RequestError(status: 0, body: "not_authenticated")
            }
            let response = try await Self.exchange(grantType: "refresh_token", body: RefreshTokenBody(refreshToken: refreshToken))
            let newSession = Self.session(from: response)
            session = newSession
            KeychainStore.save(newSession)
            return newSession.accessToken
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private static func session(from response: TokenResponse) -> AuthSessionData {
        AuthSessionData(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(response.expiresAt)),
            userID: response.user.id,
            email: response.user.email
        )
    }

    // MARK: - Wire format (GoTrue's actual REST contract, not the SDK's)

    private struct EmailPasswordBody: Encodable {
        var email: String
        var password: String
    }

    private struct RefreshTokenBody: Encodable {
        var refreshToken: String
        enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
    }

    private struct IDTokenBody: Encodable {
        var idToken: String
        var provider: String
        var nonce: String
        enum CodingKeys: String, CodingKey {
            case idToken = "id_token"
            case provider, nonce
        }
    }

    /// `/auth/v1/signup`'s response shape when email confirmation is
    /// required: a user object with no session fields at all, rather than
    /// TokenResponse's guaranteed access/refresh tokens.
    private struct SignUpResponse: Decodable {
        var accessToken: String?
        var refreshToken: String?
        var expiresAt: Int?
        var user: TokenResponse.UserInfo?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt = "expires_at"
            case user
        }
    }

    private struct TokenResponse: Decodable {
        var accessToken: String
        var refreshToken: String
        /// Unix epoch seconds, per GoTrue's OpenAPI spec — not a date string.
        var expiresAt: Int
        var user: UserInfo

        struct UserInfo: Decodable { var id: UUID; var email: String? }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresAt = "expires_at"
            case user
        }
    }

    /// `grant_type` is a query parameter, not a body field — GoTrue routes
    /// on it. Not authenticated (there's no session yet at this point): the
    /// bearer token here is the publishable key, matching anon-role access.
    private static func exchange(grantType: String, body: some Encodable) async throws -> TokenResponse {
        let data = try await RestClient.request(
            "auth/v1/token",
            method: .post,
            queryItems: [URLQueryItem(name: "grant_type", value: grantType)],
            body: try RestClient.encode(body),
            authenticated: false
        )
        return try RestClient.decode(data)
    }

    private static func logout(accessToken: String) async throws {
        try await RestClient.request(
            "auth/v1/logout",
            method: .post,
            extraHeaders: ["Authorization": "Bearer \(accessToken)"],
            authenticated: false
        )
    }
}
