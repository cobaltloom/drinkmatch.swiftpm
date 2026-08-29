import AuthenticationServices
import SwiftUI

/// The very first screen for a signed-out user: email/password (Supabase
/// Auth) or Sign in with Apple, both talking to the same GoTrue backend
/// (see AuthManager). Apple's Guideline 4.8 doesn't actually require Sign
/// in with Apple here (no other third-party login is offered), but it's a
/// convenient, password-free option for users who prefer it.
struct SignInView: View {
    var store: DrinkMatchStore

    @State private var email = ""
    @State private var password = ""
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

                    HStack {
                        Rectangle().fill(Theme.fieldBorder).frame(height: 1)
                        Text("または").font(.system(size: 11)).foregroundStyle(Theme.faint)
                        Rectangle().fill(Theme.fieldBorder).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                    SecureField("パスワード（8文字以上）", text: $password)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Theme.field)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                    HStack(spacing: 12) {
                        Button("新規登録") { Task { await submit(store.signUpWithEmail) } }
                            .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting))
                        Button("サインイン") { Task { await submit(store.signInWithEmail) } }
                            .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting))
                    }
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

    private func submit(_ action: (String, String) async -> String?) async {
        isSubmitting = true
        defer { isSubmitting = false }
        message = await action(email, password)
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
