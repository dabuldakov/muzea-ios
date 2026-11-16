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

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AuthViewModel(repository: container.authRepository))
    }

    var body: some View {
        NavigationStack {
            Form {
                if viewModel.state.phase == .email {
                    registrationForm
                } else {
                    confirmationForm
                }
            }
            .navigationTitle(viewModel.state.phase == .email ? "Регистрация" : "Подтверждение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var registrationForm: some View {
        Section("Аккаунт") {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
            TextField("Имя пользователя", text: $username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
            TextField("Отображаемое имя (необязательно)", text: $displayName)
        }

        Section {
            Toggle("Я принимаю Пользовательское соглашение и Политику обработки персональных данных", isOn: $consentAccepted)
                .font(.footnote)
            HStack(spacing: 16) {
                Button("Пользовательское соглашение") { open(Legal.termsURL) }
                Button("Политика обработки ПДн") { open(Legal.policyURL) }
            }
            .font(.caption)
        }

        errorSection

        Section {
            Button(action: register) {
                if viewModel.state.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Зарегистрироваться").frame(maxWidth: .infinity)
                }
            }
            .disabled(!isValid || viewModel.state.isLoading)
        }
    }

    @ViewBuilder
    private var confirmationForm: some View {
        Section("Подтверждение email") {
            if let info = viewModel.state.info {
                Text(info).font(.footnote).foregroundColor(.secondary)
            }
            TextField("Код из письма", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
        }

        errorSection

        Section {
            Button(action: verify) {
                if viewModel.state.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Подтвердить").frame(maxWidth: .infinity)
                }
            }
            .disabled(code.isEmpty || viewModel.state.isLoading)

            Button("Отправить ещё раз") {
                Task { _ = await viewModel.resend() }
            }
            .disabled(viewModel.state.isLoading)

            Button("Изменить данные") {
                code = ""
                viewModel.backToEmail()
            }
            .foregroundColor(.secondary)
            .disabled(viewModel.state.isLoading)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.state.error {
            Section {
                Text(error).foregroundColor(.red)
            }
        }
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
