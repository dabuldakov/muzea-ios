import SwiftUI
import UIKit

struct LoginView: View {
    let container: AppContainer

    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AuthViewModel
    @State private var email = ""
    @State private var code = ""
    @State private var showRegister = false
    @State private var showReauthNotice = false

    private let noticeStore = AuthNoticeStore()

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AuthViewModel(repository: container.authRepository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("Muzea")
                        .font(.largeTitle).bold()

                    if viewModel.state.phase == .email {
                        emailStep
                    } else {
                        codeStep
                    }

                    if let error = viewModel.state.error {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }

                    legalNote
                }
                .padding()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(container: container)
            }
            .alert(L10n.reauthTitle, isPresented: $showReauthNotice) {
                Button(L10n.reauthRegister) {
                    noticeStore.markPasswordlessNoticeShown()
                    showRegister = true
                }
                Button(L10n.reauthOk, role: .cancel) {
                    noticeStore.markPasswordlessNoticeShown()
                }
            } message: {
                Text(L10n.reauthBody)
            }
            .onAppear {
                guard noticeStore.shouldShowPasswordlessNotice else { return }
                showReauthNotice = true
            }
        }
    }

    @ViewBuilder
    private var emailStep: some View {
        TextField("Email", text: $email)
            .textFieldStyle(.roundedBorder)
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
        .disabled(email.isEmpty || viewModel.state.isLoading)

        Button(L10n.registerTitle) { showRegister = true }
            .disabled(viewModel.state.isLoading)
    }

    @ViewBuilder
    private var codeStep: some View {
        if let info = viewModel.state.info {
            Text(info)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }

        TextField(L10n.codeField, text: $code)
            .textFieldStyle(.roundedBorder)
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
        .disabled(code.isEmpty || viewModel.state.isLoading)

        Button(L10n.resendCode) {
            Task { _ = await viewModel.resend() }
        }
        .disabled(viewModel.state.isLoading)

        Button(L10n.changeEmail) {
            email = viewModel.state.email
            code = ""
            viewModel.backToEmail()
        }
        .foregroundColor(.secondary)
        .disabled(viewModel.state.isLoading)
    }

    private var legalNote: some View {
        VStack(spacing: 8) {
            Text(L10n.legalNote)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(L10n.termsLink) { open(Legal.termsURL) }
                Button(L10n.policyLink) { open(Legal.policyURL) }
            }
            .font(.caption)
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
