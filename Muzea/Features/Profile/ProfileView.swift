import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ProfileViewModel

    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var deleteDialog: DeleteDialog?

    private enum DeleteDialog {
        case confirm
        case failure(String)
    }

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            authRepository: container.authRepository,
            chatRepository: container.chatRepository
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            AvatarView(url: ImageURL.chat(viewModel.avatarUrl), size: 96)

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text("Сменить аватар")
                            }
                            .disabled(viewModel.isBusy)

                            if viewModel.avatarUrl != nil {
                                Button("Удалить аватар", role: .destructive) {
                                    Task { await viewModel.deleteAvatar() }
                                }
                                .disabled(viewModel.isBusy)
                            }

                            if viewModel.isBusy { ProgressView() }
                        }
                        Spacer()
                    }
                }

                Section("Профиль") {
                    LabeledContent("Логин", value: viewModel.user?.userName ?? container.tokenStore.username ?? "")
                    TextField("Полное имя", text: $fullName)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    LabeledContent("Роль", value: viewModel.user?.role ?? "")
                }

                Section {
                    NavigationLink {
                        OperatorInfoView()
                    } label: {
                        Label("Оператор персональных данных", systemImage: "person.text.rectangle")
                    }
                }

                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button("Сохранить") {
                        Task { _ = await viewModel.update(fullName: fullName, email: email) }
                    }
                    Button("Удалить аккаунт", role: .destructive) {
                        deleteDialog = .confirm
                    }
                    .disabled(viewModel.isBusy)
                    Button("Выйти", role: .destructive) {
                        Task { await container.logout() }
                    }
                }
            }
            .navigationTitle("Профиль")
            .task {
                await viewModel.load()
                fullName = viewModel.user?.fullName ?? viewModel.user?.userName ?? ""
                email = viewModel.user?.email ?? ""
            }
            .onChange(of: selectedPhoto) { newValue in
                Task { await loadPhoto(newValue) }
            }
            .alert("Удалить аккаунт?", isPresented: Binding(
                get: { deleteDialog != nil },
                set: { if !$0 { deleteDialog = nil } }
            )) {
                switch deleteDialog {
                case .confirm:
                    Button("Удалить", role: .destructive) { Task { await deleteAccount() } }
                    Button("Отмена", role: .cancel) {}
                case .failure:
                    Button("Выйти из приложения", role: .destructive) {
                        Task { await container.logout() }
                    }
                    Button("Отмена", role: .cancel) {}
                case .none:
                    EmptyView()
                }
            } message: {
                switch deleteDialog {
                case .confirm:
                    Text("Профиль, сообщения, публикации и видео будут удалены, обработка персональных данных прекратится. Отменить удаление нельзя.")
                case .failure(let message):
                    Text(message)
                case .none:
                    EmptyView()
                }
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard data.count <= Config.maxAvatarBytes else {
            viewModel.error = "Выберите изображение размером до 5 МБ"
            return
        }
        await viewModel.uploadAvatar(
            data: data,
            fileName: "avatar_\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg"
        )
    }

    private func deleteAccount() async {
        switch await viewModel.deleteAccount() {
        case .deleted:
            // Аккаунт уже удалён на обоих серверах: серверный logout тут не
            // нужен, а вызвал бы повторную регистрацию. Чистим только локально.
            container.clearLocalSession()
            container.tokenStore.clearAll()
            container.consentManager.revoke()
            container.isConsentAccepted = false
        case .chatFailed:
            deleteDialog = .failure("Не удалось удалить переписку на сервере чата. Проверьте подключение и повторите попытку.")
        case .failed(let message):
            deleteDialog = .failure(message)
        }
    }
}
