import SwiftUI
import UIKit

struct LoginView: View {
    let container: AppContainer

    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AuthViewModel
    @State private var email = ""
    @State private var code = ""
    @State private var showRegister = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AuthViewModel(repository: container.authRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.38, green: 0.0, blue: 0.93),
                        Color(red: 0.50, green: 0.22, blue: 0.98),
                        Color(red: 0.22, green: 0.0, blue: 0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 46, weight: .medium))
                            .foregroundColor(.white)
                            .padding(22)
                            .background(Circle().fill(Color.white.opacity(0.16)))

                        Text(L10n.appName)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)

                        Text(L10n.loginSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        loginCard
                            .padding(.top, 12)

                        legalNote
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(container: container, email: email)
            }
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.loginTitle)
                .font(.title3).bold()
                .foregroundColor(.primary)

            Text(L10n.loginCaption)
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.state.phase == .email {
                emailStep
            } else {
                codeStep
            }

            if let error = viewModel.state.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    @ViewBuilder
    private var emailStep: some View {
        TextField("Email", text: $email)
            .textFieldStyle(.plain)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)

        Button(action: requestCode) {
            if viewModel.state.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(L10n.getCode).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(email.isEmpty || viewModel.state.isLoading)

        Button(L10n.registerTitle) { showRegister = true }
            .font(.footnote)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.state.isLoading)
    }

    @ViewBuilder
    private var codeStep: some View {
        Text(L10n.codeTitle)
            .font(.headline)

        if let info = viewModel.state.info {
            Text(info)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }

        TextField(L10n.codeField, text: $code)
            .textFieldStyle(.plain)
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)

        Button(action: verify) {
            if viewModel.state.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text(L10n.signIn).frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(code.isEmpty || viewModel.state.isLoading)

        Button(viewModel.resendSeconds > 0
            ? L10n.resendIn(viewModel.resendSeconds)
            : L10n.resendCode) {
            Task { _ = await viewModel.resend() }
        }
        .font(.footnote)
        .disabled(viewModel.state.isLoading || viewModel.resendSeconds > 0)

        Button(L10n.changeEmail) {
            email = viewModel.state.email
            code = ""
            viewModel.backToEmail()
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .disabled(viewModel.state.isLoading)
    }

    private var legalNote: some View {
        VStack(spacing: 8) {
            Text(L10n.legalNote)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(L10n.termsLink) { open(Legal.termsURL) }
                Button(L10n.policyLink) { open(Legal.policyURL) }
            }
            .font(.caption)
            .foregroundColor(.white)
        }
    }

    private func open(_ url: String) {
        guard let target = URL(string: url) else { return }
        openURL(target)
    }

    private func requestCode() {
        Task {
            if await viewModel.requestLoginCode(email: email) {
                code = ""
            }
        }
    }

    private func verify() {
        Task {
            if await viewModel.verify(code: code) {
                container.didLogin()
            }
        }
    }
}
