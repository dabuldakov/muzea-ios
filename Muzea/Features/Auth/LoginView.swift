import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Muzea")
                    .font(.largeTitle).bold()

                TextField("Имя пользователя", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Пароль", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let error {
                    Text(error).foregroundColor(.red).font(.footnote)
                }

                Button(action: login) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Войти").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(username.isEmpty || password.isEmpty || isLoading)

                Button("Регистрация") { showRegister = true }
                    .disabled(isLoading)
            }
            .padding()
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    private func login() {
        isLoading = true
        error = nil
        Task {
            do {
                _ = try await container.authRepository.login(username: username, password: password)
                container.didLogin()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
