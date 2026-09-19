import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var viewModel: ProfileViewModel

    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedPhoto: PhotosPickerItem?

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

                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button("Сохранить") {
                        Task { _ = await viewModel.update(fullName: fullName, email: email) }
                    }
                    Button("Выйти", role: .destructive) {
                        container.logout()
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
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        await viewModel.uploadAvatar(
            data: data,
            fileName: "avatar_\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg"
        )
    }
}
