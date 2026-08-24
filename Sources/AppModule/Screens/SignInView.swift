import SwiftUI

/// The very first screen for a signed-out user. Email/password (Supabase
/// Auth) rather than Sign in with Apple: this app doesn't offer any other
/// third-party login, so Apple's Guideline 4.8 requirement (offer Sign in
/// with Apple whenever another third-party login is present) doesn't apply,
/// and email/password needs no App Store entitlement or paid Developer
/// Program capability to work.
struct SignInView: View {
    var store: DrinkMatchStore

    @State private var email = ""
    @State private var password = ""
    @State private var message: String?
    @State private var isSubmitting = false

    var body: some View {
        BoardScreenContainer {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("Crew Board").splitFlap(32, weight: .bold).foregroundStyle(Theme.amber)
                    Text("航空従事者限定・飲み会マッチング")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 80)

                VStack(spacing: 8) {
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
}
