import SwiftUI
import UIKit

struct RegisterView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var consentAccepted = false
    @State private var isLoading = false
    @State private var error: String?

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

                if let error {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: register) {
                        if isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Зарегистрироваться").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValid || isLoading)
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
        isLoading = true
        error = nil
        Task {
            do {
                _ = try await container.authRepository.register(
                    username: username,
                    email: email,
                    password: password,
                    fullName: fullName
                )
                container.didLogin()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
