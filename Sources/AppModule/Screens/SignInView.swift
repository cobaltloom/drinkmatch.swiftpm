import SwiftUI
import AuthenticationServices

/// The very first screen for a signed-out user. Apple requires Sign in with
/// Apple as an option whenever another third-party login is offered (App
/// Store Review Guideline 4.8); this app offers only Apple for now, which
/// keeps things simple and compliant from day one.
struct SignInView: View {
    var store: AppStore

    // MARK: - Temporary dev-only email sign-in
    //
    // Sign in with Apple needs a paid Apple Developer Program membership to
    // work at all (the capability can't be granted to a free account), which
    // this project doesn't have yet. This block is a stand-in so the rest of
    // the app can be tested in Swift Playgrounds in the meantime — delete it
    // once Apple sign-in is testable and keep only the button above it.
    @State private var devEmail = ""
    @State private var devPassword = ""
    @State private var devMessage: String?
    @State private var isDevSubmitting = false

    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("CREW BOARD").splitFlap(32, weight: .bold).foregroundStyle(Theme.amber)
                    Text("航空従事者限定・飲み会マッチング")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 80)

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let message = store.lastErrorMessage {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.red)
                }

                devSignInSection
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var devSignInSection: some View {
        VStack(spacing: 8) {
            Text("開発用テストログイン（Apple Developer Program登録までの暫定手段）")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            TextField("メールアドレス", text: $devEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14))
                .padding(10)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

            SecureField("パスワード（8文字以上）", text: $devPassword)
                .font(.system(size: 14))
                .padding(10)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

            HStack(spacing: 12) {
                Button("テスト登録") { Task { await submitDev(store.signUpWithEmail) } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isDevSubmitting))
                Button("テストログイン") { Task { await submitDev(store.signInWithEmail) } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isDevSubmitting))
            }
            .disabled(isDevSubmitting)

            if let devMessage {
                Text(devMessage).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 320)
        .padding(.top, 8)
    }

    private func submitDev(_ action: (String, String) async -> String?) async {
        isDevSubmitting = true
        defer { isDevSubmitting = false }
        devMessage = await action(devEmail, devPassword)
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                store.lastErrorMessage = "サインインに失敗しました。もう一度お試しください。"
                return
            }
            Task { await store.signInWithApple(idToken: idToken) }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            store.lastErrorMessage = "サインインに失敗しました。もう一度お試しください。"
        }
    }
}
