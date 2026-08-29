import CryptoKit
import Foundation

/// Nonce generation for Sign in with Apple: a random raw string sent to
/// Apple only as its SHA256 hash (via ASAuthorizationAppleIDRequest.nonce
/// in SignInView), with the raw string itself sent to the backend
/// (SupabaseRepository.signInWithApple) for it to hash and compare —
/// proves this specific sign-in request produced the token, not a replayed
/// one.
enum AppleNonceGenerator {
    static func random(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            precondition(status == errSecSuccess)
            for random in randoms where remainingLength > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}
