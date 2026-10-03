import SwiftUI
import UIKit

struct LoginView: View {
    let container: AppContainer

    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
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

                    TextField("Имя пользователя", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Пароль", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if let error = viewModel.state.error {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }

                    Button(action: login) {
                        if viewModel.state.isLoading {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Войти").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.isEmpty || password.isEmpty || viewModel.state.isLoading)

                    Button("Регистрация") { showRegister = true }
                        .disabled(viewModel.state.isLoading)

                    legalNote
                }
                .padding()
            }
            .sheet(isPresented: $showRegister) {
                RegisterView(container: container)
            }
        }
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

    private func login() {
        Task {
            if await viewModel.login(username: username, password: password) {
                container.didLogin()
            }
        }
    }
}
