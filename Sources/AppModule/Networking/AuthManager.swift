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

    /// Sends a password-reset email. Uses the Supabase project's default
    /// "Reset Password" template as-is — Supabase's built-in email
    /// delivery only allows editing templates once a custom SMTP provider
    /// is configured, which this project doesn't have. SignInView has the
    /// user paste the email's "Reset password" link back into the app;
    /// `resetPassword(resetLink:newPassword:)` below does the rest.
    func requestPasswordReset(email: String) async throws {
        try await RestClient.request(
            "auth/v1/recover",
            method: .post,
            body: try RestClient.encode(EmailOnlyBody(email: email)),
            authenticated: false
        )
    }

    /// Verifies a pasted "Reset password" email link, sets the new
    /// password, and signs the user in with the resulting session.
    ///
    /// The link is a GET endpoint Supabase's own server verifies and then
    /// 302-redirects from, appending the new session as a URL fragment
    /// (`#access_token=...&refresh_token=...`) on the project's configured
    /// redirect URL — not something `POST /auth/v1/verify`'s token/code
    /// exchange accepts directly (an earlier attempt reusing the link's
    /// `token=` query item that way failed on-device). Following the
    /// redirect exactly the way a browser would and reading the fragment
    /// off it sidesteps needing to reverse-engineer GoTrue's internal
    /// token format.
    func resetPassword(resetLink: String, newPassword: String) async throws -> UUID {
        // Temporary diagnostic detail in each thrown error's body (DrinkMatchStore
        // currently surfaces it raw) — remove once this flow is confirmed
        // working on-device, same as the earlier Sign in with Apple diagnostic.
        guard let redirectURL = try await Self.followRedirect(from: resetLink) else {
            throw RestClient.RequestError(status: 0, body: "no redirect captured — the pasted text may not be a valid URL")
        }
        guard let fragment = redirectURL.fragment, !fragment.isEmpty else {
            throw RestClient.RequestError(status: 0, body: "redirected to \(redirectURL.absoluteString), but it had no #fragment")
        }
        let params = Self.parseFragment(fragment)
        guard let accessToken = params["access_token"], let refreshToken = params["refresh_token"] else {
            throw RestClient.RequestError(status: 0, body: "fragment had no tokens: \(fragment)")
        }
        let expiresAt: Date
        if let expiresIn = params["expires_in"].flatMap(Double.init) {
            expiresAt = Date().addingTimeInterval(expiresIn)
        } else if let expiresAtEpoch = params["expires_at"].flatMap(Double.init) {
            expiresAt = Date(timeIntervalSince1970: expiresAtEpoch)
        } else {
            throw RestClient.RequestError(status: 0, body: "fragment had tokens but no expiry: \(fragment)")
        }

        // Not routed through the normal `authenticated: true` path (which
        // pulls the persisted session) since there's no signed-in session
        // yet at this point — this recovery session's own access token is
        // passed explicitly instead, the same way `logout(accessToken:)`
        // does below. GoTrue's user-update endpoint returns the updated
        // user object directly, so no separate fetch is needed for it.
        let updateData = try await RestClient.request(
            "auth/v1/user",
            method: .put,
            body: try RestClient.encode(PasswordUpdateBody(password: newPassword)),
            extraHeaders: ["Authorization": "Bearer \(accessToken)"],
            authenticated: false
        )
        let user: TokenResponse.UserInfo = try RestClient.decode(updateData)

        let newSession = AuthSessionData(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            userID: user.id,
            email: user.email
        )
        session = newSession
        KeychainStore.save(newSession)
        return newSession.userID
    }

    /// Visits `urlString` and captures the URL of its first HTTP redirect
    /// without actually following it (the redirect target is a
    /// `redirect_to` app URL, typically not a real reachable server, and
    /// its fragment — not sent in any further request — is the whole
    /// point). Returns nil if the string isn't a valid URL or the request
    /// never redirects.
    private static func followRedirect(from urlString: String) async throws -> URL? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let delegate = RedirectCapturingDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        _ = try? await session.data(from: url)
        return delegate.capturedURL
    }

    private final class RedirectCapturingDelegate: NSObject, URLSessionTaskDelegate {
        var capturedURL: URL?

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            capturedURL = request.url
            completionHandler(nil)
        }
    }

    /// URL fragments (`#key=value&key=value`) aren't sent to servers and
    /// have no built-in parser in Foundation the way query items do.
    private static func parseFragment(_ fragment: String) -> [String: String] {
        var result: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            result[String(parts[0])] = String(parts[1]).removingPercentEncoding ?? String(parts[1])
        }
        return result
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

    private struct EmailOnlyBody: Encodable {
        var email: String
    }

    private struct PasswordUpdateBody: Encodable {
        var password: String
    }

    private struct RefreshTokenBody: Encodable {
        var refreshToken: String
        enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
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
