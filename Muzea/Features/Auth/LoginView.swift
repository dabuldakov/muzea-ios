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
                Text("Получить код").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(email.isEmpty || viewModel.state.isLoading)

        Button("Регистрация") { showRegister = true }
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

        TextField("Код из письма", text: $code)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)

        Button(action: verify) {
            if viewModel.state.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else {
                Text("Войти").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(code.isEmpty || viewModel.state.isLoading)

        Button("Отправить ещё раз") {
            Task { _ = await viewModel.resend() }
        }
        .disabled(viewModel.state.isLoading)

        Button("Изменить email") {
            email = viewModel.state.email
            code = ""
            viewModel.backToEmail()
        }
        .foregroundColor(.secondary)
        .disabled(viewModel.state.isLoading)
    }

    private var legalNote: some View {
        VStack(spacing: 8) {
            Text("Продолжая, вы принимаете Пользовательское соглашение и Политику обработки персональных данных")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Пользовательское соглашение") { open(Legal.termsURL) }
                Button("Политика обработки ПДн") { open(Legal.policyURL) }
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
