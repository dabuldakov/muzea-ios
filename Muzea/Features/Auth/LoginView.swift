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
            AuthScaffold {
                loginCard
            } footer: {
                AuthLegalFooter(open: open)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRegister) {
                RegisterView(container: container, email: email)
            }
        }
    }

    private var loginCard: some View {
        AuthCard(title: cardTitle, caption: cardCaption) {
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
    }

    private var cardTitle: String {
        viewModel.state.phase == .email ? L10n.loginTitle : L10n.codeTitle
    }

    private var cardCaption: String? {
        viewModel.state.phase == .email ? L10n.loginCaption : viewModel.state.info
    }

    @ViewBuilder
    private var emailStep: some View {
        TextField(L10n.emailField, text: $email)
            .authInput()
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)

        Button(action: requestCode) {
            if viewModel.state.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(L10n.getCode)
            }
        }
        .buttonStyle(AuthPrimaryButtonStyle())
        .disabled(email.isEmpty || viewModel.state.isLoading)

        AuthLinkButton(title: L10n.registerTitle) { showRegister = true }
            .frame(maxWidth: .infinity)
            .disabled(viewModel.state.isLoading)
    }

    @ViewBuilder
    private var codeStep: some View {
        TextField(L10n.codeField, text: $code)
            .authInput()
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)

        Button(action: verify) {
            if viewModel.state.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(L10n.signIn)
            }
        }
        .buttonStyle(AuthPrimaryButtonStyle())
        .disabled(code.isEmpty || viewModel.state.isLoading)

        AuthLinkButton(
            title: viewModel.resendSeconds > 0
                ? L10n.resendIn(viewModel.resendSeconds)
                : L10n.resendCode
        ) {
            Task { _ = await viewModel.resend() }
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.state.isLoading || viewModel.resendSeconds > 0)

        AuthLinkButton(title: L10n.changeEmail, color: AuthPalette.muted) {
            email = viewModel.state.email
            code = ""
            viewModel.backToEmail()
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.state.isLoading)
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
