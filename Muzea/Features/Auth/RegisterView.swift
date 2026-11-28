import SwiftUI
import UIKit

struct RegisterView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AuthViewModel

    @State private var email = ""
    @State private var username = ""
    @State private var displayName = ""
    @State private var code = ""
    @State private var consentAccepted = false

    init(container: AppContainer, email: String = "") {
        self.container = container
        _viewModel = StateObject(wrappedValue: AuthViewModel(repository: container.authRepository))
        _email = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            AuthScaffold {
                AuthCard(title: cardTitle, caption: cardCaption) {
                    if viewModel.state.phase == .email {
                        registrationForm
                    } else {
                        confirmationForm
                    }

                    if let error = viewModel.state.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                        .foregroundColor(AuthPalette.purple)
                }
            }
        }
    }

    private var cardTitle: String {
        viewModel.state.phase == .email ? L10n.registerTitle : L10n.codeTitle
    }

    private var cardCaption: String? {
        viewModel.state.phase == .email ? L10n.registerCaption : viewModel.state.info
    }

    @ViewBuilder
    private var registrationForm: some View {
        TextField(L10n.emailField, text: $email)
            .authInput()
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.emailAddress)

        TextField(L10n.usernameField, text: $username)
            .authInput()
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)

        TextField(L10n.displayNameField, text: $displayName)
            .authInput()

        Toggle(L10n.consentToggle, isOn: $consentAccepted)
            .font(.footnote)
            .foregroundColor(AuthPalette.ink)
            .tint(AuthPalette.purple)

        AuthLegalLinks(open: open)

        Button(action: register) {
            if viewModel.state.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(L10n.registerAction)
            }
        }
        .buttonStyle(AuthPrimaryButtonStyle())
        .disabled(!isValid || viewModel.state.isLoading)
    }

    @ViewBuilder
    private var confirmationForm: some View {
        TextField(L10n.codeField, text: $code)
            .authInput()
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)

        Button(action: verify) {
            if viewModel.state.isLoading {
                ProgressView().tint(.white)
            } else {
                Text(L10n.confirmAction)
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

        AuthLinkButton(title: L10n.changeData, color: AuthPalette.muted) {
            code = ""
            viewModel.backToEmail()
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.state.isLoading)
    }

    private var isValid: Bool {
        let mail = AuthViewModel.normalizeEmail(email)
        return AuthViewModel.isValidEmail(mail)
            && AuthViewModel.isValidUsername(username.trimmingCharacters(in: .whitespacesAndNewlines))
            && consentAccepted
    }

    private func open(_ url: String) {
        guard let target = URL(string: url) else { return }
        openURL(target)
    }

    private func register() {
        Task {
            if await viewModel.register(email: email, username: username, displayName: displayName) {
                code = ""
            }
        }
    }

    private func verify() {
        Task {
            if await viewModel.verify(code: code) {
                container.didLogin()
                dismiss()
            }
        }
    }
}
