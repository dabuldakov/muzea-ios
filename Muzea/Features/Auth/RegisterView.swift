import SwiftUI
import UIKit

struct RegisterView: View {
    let container: AppContainer

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AuthViewModel

    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var consentAccepted = false

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: AuthViewModel(repository: container.authRepository))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Аккаунт") {
                    TextField("Имя пользователя", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Полное имя", text: $fullName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Пароль", text: $password)
                    SecureField("Подтвердите пароль", text: $confirmPassword)
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

                if let error = viewModel.state.error {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }

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
            .navigationTitle("Регистрация")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        !username.isEmpty
            && !fullName.isEmpty
            && email.contains("@")
            && password.count >= 6
            && password == confirmPassword
            && consentAccepted
    }

    private func open(_ url: String) {
        guard let target = URL(string: url) else { return }
        openURL(target)
    }

    private func register() {
        Task {
            let success = await viewModel.register(
                username: username,
                email: email,
                password: password,
                fullName: fullName
            )
            if success {
                container.didLogin()
                dismiss()
            }
        }
    }
}
