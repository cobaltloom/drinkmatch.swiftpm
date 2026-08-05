import Foundation

/// Persisted locally (Keychain) between launches so signing in once is
/// enough. Supabase's refresh tokens rotate on every use — see AuthManager,
/// which is what actually keeps this current.
struct AuthSessionData: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: UUID
}
