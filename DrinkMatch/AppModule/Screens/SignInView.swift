import AuthenticationServices
import SwiftUI

/// The very first screen for a signed-out user: Sign in with Apple only
/// (talking to Supabase Auth/GoTrue's native id_token flow — see
/// AuthManager). Every user of this iOS-only, App Store-distributed app
/// already has an Apple ID, so this is the sole sign-in method — no
/// password to forget, reset, or store.
struct SignInView: View {
    var store: DrinkMatchStore

    @State private var message: String?
    @State private var isSubmitting = false
    @State private var currentAppleNonce = ""

    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("CrewBoard").splitFlap(32, weight: .bold).foregroundStyle(Theme.amber)
                }
                .padding(.top, 80)

                VStack(spacing: 8) {
                    SignInWithAppleButton(.signIn) { request in
                        currentAppleNonce = AppleNonceGenerator.random()
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleNonceGenerator.sha256(currentAppleNonce)
                    } onCompletion: { result in
                        Task { await handleAppleSignIn(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .disabled(isSubmitting)

                    if let message {
                        Text(message).font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }

                    if let storeMessage = store.lastErrorMessage {
                        Text(storeMessage).font(.system(size: 12)).foregroundStyle(Theme.red)
                    }

                    VStack(spacing: 4) {
                        Text("登録・サインインすることで、利用規約とプライバシーポリシーに同意したものとみなされます。")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 16) {
                            Link("利用規約", destination: termsOfUseURL)
                            Link("プライバシーポリシー", destination: privacyPolicyURL)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isSubmitting = true
        defer { isSubmitting = false }
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                message = "サインインに失敗しました。"
                return
            }
            message = await store.signInWithApple(idToken: idToken, rawNonce: currentAppleNonce)
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                message = "サインインに失敗しました: \(error)"
            }
        }
    }
}
