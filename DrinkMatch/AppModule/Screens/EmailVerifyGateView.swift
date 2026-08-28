import SwiftUI

/// Identity verification required before "new match" (stranger) search
/// unlocks: either a company email domain, or a senior's referral code.
/// Both routes are server-verified (`verify_email_domain` /
/// `redeem_referral_code`) — this view never decides validity itself.
struct EmailVerifyGateView: View {
    var onSubmitEmail: (String) async -> Bool
    var onSubmitReferralCode: (String) async -> String?

    private enum Mode: String, CaseIterable, Hashable { case email, referral }

    @State private var mode: Mode = .email
    @State private var email = ""
    @State private var code = ""
    @State private var errorMessage = ""
    @State private var isSubmitting = false

    var body: some View {
        BoardCard {
            VStack(spacing: 6) {
                Text("本人確認が必要です")
                    .splitFlap(14, weight: .bold)
                    .foregroundStyle(Theme.amber)
                Text("知らない航空従事者と会う機能のため、本人確認をお願いしています。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            Picker("認証方法", selection: $mode) {
                Text("会社メールで認証").tag(Mode.email)
                Text("本人確認コードで認証").tag(Mode.referral)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { errorMessage = "" }
            .padding(.bottom, 14)

            if mode == .email {
                TextField("name@ana.co.jp", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(Theme.red).padding(.top, 10)
                }

                Button("確認して新しい人を探す") { Task { await submitEmail() } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting))
                    .disabled(isSubmitting)
                    .padding(.top, 10)
            } else {
                Text("すでに本人確認済みの航空従事者から発行された本人確認コードをお持ちの場合、入力してください。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                TextField("例: SENPAI-T7K2", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 14))
                    .padding(10)
                    .background(Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Theme.fieldBorder))

                if !errorMessage.isEmpty {
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(Theme.red).padding(.top, 10)
                }

                Button("確認して新しい人を探す") { Task { await submitReferral() } }
                    .buttonStyle(BoardButtonStyle(isDisabled: isSubmitting))
                    .disabled(isSubmitting)
                    .padding(.top, 10)
            }
        }
    }

    private func submitEmail() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        let succeeded = await onSubmitEmail(trimmed)
        errorMessage = succeeded ? "" : "会社ドメインのメールアドレスを入力してください(例: name@ana.co.jp)"
    }

    private func submitReferral() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        if let error = await onSubmitReferralCode(trimmed) {
            errorMessage = error
        } else {
            errorMessage = ""
        }
    }
}
