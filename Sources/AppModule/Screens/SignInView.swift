import SwiftUI
import AuthenticationServices

/// The very first screen for a signed-out user. Apple requires Sign in with
/// Apple as an option whenever another third-party login is offered (App
/// Store Review Guideline 4.8); this app offers only Apple for now, which
/// keeps things simple and compliant from day one.
struct SignInView: View {
    var store: DrinkMatchStore

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
                    handleAppleSignInResult(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let message = store.lastErrorMessage {
                    Text(message).font(.system(size: 12)).foregroundStyle(Theme.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
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
