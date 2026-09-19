import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
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
        !username.isEmpty && !fullName.isEmpty && email.contains("@") && password.count >= 6
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
