import Foundation

/// Raw HTTP plumbing for talking to Supabase's PostgREST (`/rest/v1/`) and
/// Edge Functions (`/functions/v1/`) APIs directly over `URLSession`.
///
/// This exists instead of the official `supabase-swift` package because that
/// package cannot be built in Swift Playgrounds: it depends transitively on
/// `swift-crypto`, which has C-language targets (`CCryptoBoringSSL`,
/// `CXKCP`), and Swift Playgrounds categorically refuses to build any SPM
/// package containing a C/C++/Objective-C target (confirmed via Apple's own
/// developer forums — this is a hard platform limitation, not a version or
/// configuration issue). PostgREST and GoTrue (Supabase Auth) are both plain
/// JSON-over-HTTP APIs, so talking to them with nothing but Foundation
/// sidesteps the problem entirely.
enum RestClient {
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    struct RequestError: Error, CustomStringConvertible {
        var status: Int
        var body: String
        /// `BackendErrorCode.from(_:)` pattern-matches against this string —
        /// PostgREST's error body includes the original `RAISE EXCEPTION`
        /// message verbatim (e.g. `{"message":"not_authenticated",...}`).
        var description: String { "HTTP \(status): \(body)" }
    }

    static let encoder: JSONEncoder = JSONEncoder()
    static let decoder: JSONDecoder = JSONDecoder()

    /// Builds a URL under the project's base URL (`SupabaseConfig.projectURL`).
    /// `pathAndQuery` is everything after the host, e.g. `"rest/v1/users"`.
    private static func url(_ pathAndQuery: String, queryItems: [URLQueryItem]) -> URL {
        var components = URLComponents(
            url: SupabaseConfig.projectURL.appendingPathComponent(pathAndQuery),
            resolvingAgainstBaseURL: false
        )!
        if !queryItems.isEmpty { components.queryItems = queryItems }
        return components.url!
    }

    /// Low-level request against any Supabase HTTP API. `authenticated: true`
    /// (the default) attaches the signed-in user's access token so RLS
    /// policies relying on `auth.uid()` apply; `false` sends the
    /// publishable key as the bearer token instead, matching anon-role
    /// access (used only for the sign-in exchange itself, before any user
    /// session exists).
    @discardableResult
    static func request(
        _ pathAndQuery: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        extraHeaders: [String: String] = [:],
        authenticated: Bool = true
    ) async throws -> Data {
        var request = URLRequest(url: url(pathAndQuery, queryItems: queryItems))
        request.httpMethod = method.rawValue
        request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")

        let bearerToken: String
        if authenticated, let token = try await AuthManager.shared.validAccessToken() {
            bearerToken = token
        } else {
            bearerToken = SupabaseConfig.publishableKey
        }
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RequestError(status: -1, body: "no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw RequestError(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }

    static func eq<V: CustomStringConvertible>(_ column: String, _ value: V) -> URLQueryItem {
        URLQueryItem(name: column, value: "eq.\(value)")
    }

    static func gte<V: CustomStringConvertible>(_ column: String, _ value: V) -> URLQueryItem {
        URLQueryItem(name: column, value: "gte.\(value)")
    }

    static func lt<V: CustomStringConvertible>(_ column: String, _ value: V) -> URLQueryItem {
        URLQueryItem(name: column, value: "lt.\(value)")
    }

    static func inList<V: CustomStringConvertible>(_ column: String, _ values: [V]) -> URLQueryItem {
        URLQueryItem(name: column, value: "in.(\(values.map(\.description).joined(separator: ",")))")
    }
}
