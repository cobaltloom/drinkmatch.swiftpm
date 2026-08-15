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

    @State private var isResettingPassword = false
    @State private var resetCodeSent = false
    @State private var resetCode = ""
    @State private var newPassword = ""
    @State private var resetMessage: String?
    @State private var isResetSubmitting = false

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

                    Button(isResettingPassword ? "サインインに戻る" : "パスワードを忘れた場合") {
                        isResettingPassword.toggle()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)

                    if isResettingPassword {
                        passwordResetSection
                    }
                }
                .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var passwordResetSection: some View {
        VStack(spacing: 8) {
            if !resetCodeSent {
                Button("パスワード再設定メールを送信") { Task { await sendResetCode() } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isResetSubmitting))
                    .disabled(isResetSubmitting || email.isEmpty)
            } else {
                Text("メール内の「Reset password」リンクを長押しして「リンクをコピー」を選び、ここに貼り付けてください。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("コピーしたリンクを貼り付け", text: $resetCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                SecureField("新しいパスワード（8文字以上）", text: $newPassword)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                Button("パスワードを再設定") { Task { await submitResetPassword() } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isResetSubmitting))
                    .disabled(isResetSubmitting)
            }

            if let resetMessage {
                Text(resetMessage).font(.system(size: 12)).foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 4)
    }

    private func submit(_ action: (String, String) async -> String?) async {
        isSubmitting = true
        defer { isSubmitting = false }
        message = await action(email, password)
    }

    private func sendResetCode() async {
        isResetSubmitting = true
        defer { isResetSubmitting = false }
        resetMessage = await store.requestPasswordReset(email: email)
        resetCodeSent = true
    }

    private func submitResetPassword() async {
        isResetSubmitting = true
        defer { isResetSubmitting = false }
        let token = Self.token(fromPastedLinkOrCode: resetCode)
        resetMessage = await store.resetPassword(email: email, code: token, newPassword: newPassword)
    }

    /// The reset email's link embeds the same recovery token
    /// `/auth/v1/verify` accepts directly (`...?token=XXXX&type=recovery...`)
    /// — pulls it out of a pasted link, or passes the input through as-is
    /// if it doesn't look like a URL (e.g. a plain code, once/if the
    /// Supabase project's email template is customized to show one).
    private static func token(fromPastedLinkOrCode input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            return trimmed
        }
        return token
    }
}
