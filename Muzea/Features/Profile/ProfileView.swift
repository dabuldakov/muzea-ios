import SwiftUI
import PhotosUI

struct ProfileView: View {
    let container: AppContainer

    @StateObject private var viewModel: ProfileViewModel
    @State private var fullName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var deleteDialog: DeleteDialog?
    @State private var cacheSize: Int64 = 0
    @State private var cacheCleared = false
    @State private var showLanguagePicker = false
    @ObservedObject private var localization = LocalizationStore.shared

    private enum DeleteDialog {
        case confirm
        case failure(String)
    }

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            userRepository: container.userRepository,
            avatarRepository: container.avatarRepository,
            chatSessionRepository: container.chatSessionRepository,
            authRepository: container.authRepository
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            AvatarView(url: ImageURL.chat(viewModel.state.avatarUrl), size: 96)

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text(L10n.changeAvatar)
                            }
                            .disabled(viewModel.state.isBusy)

                            if viewModel.state.avatarUrl != nil {
                                Button(L10n.deleteAvatar, role: .destructive) {
                                    Task { await viewModel.deleteAvatar() }
                                }
                                .disabled(viewModel.state.isBusy)
                            }

                            if viewModel.state.isBusy { ProgressView() }
                        }
                        Spacer()
                    }
                }

                Section(L10n.profileTitle) {
                    LabeledContent(L10n.loginLabel, value: viewModel.state.user?.userName ?? container.tokenStore.username ?? "")
                    TextField(L10n.fullNameField, text: $fullName)
                    // Email — идентичность IdP; отдельного endpoint для смены нет.
                    LabeledContent("Email", value: viewModel.state.email ?? "")
                    LabeledContent(L10n.roleLabel, value: viewModel.state.user?.role ?? "")
                }

                Section {
                    NavigationLink(value: Route.operatorInfo) {
                        Label(L10n.operatorLink, systemImage: "person.text.rectangle")
                    }
                }

                Section {
                    LabeledContent(
                        L10n.cacheLabel,
                        value: ByteCountFormatter.string(
                            fromByteCount: cacheSize,
                            countStyle: .file
                        )
                    )
                    Button(L10n.clearCache) {
                        Task {
                            await container.cacheManager.clear()
                            cacheSize = container.cacheManager.totalSizeBytes()
                            cacheCleared = true
                        }
                    }
                } footer: {
                    if cacheCleared {
                        Text(L10n.cacheCleared).foregroundColor(.green)
                    }
                }

                Section {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        LabeledContent(L10n.languageLabel, value: localization.currentLabel)
                    }
                }

                if let error = viewModel.state.error {
                    Section { Text(error).foregroundColor(.red) }
                }

                Section {
                    Button(L10n.save) {
                        Task {
                            _ = await viewModel.update(
                                fullName: fullName,
                                email: viewModel.state.email ?? ""
                            )
                        }
                    }
                    Button(L10n.deleteAccount, role: .destructive) {
                        deleteDialog = .confirm
                    }
                    .disabled(viewModel.state.isBusy)
                    Button(L10n.signOut, role: .destructive) {
                        Task { await container.logout() }
                    }
                }
            }
            .confirmationDialog(
                L10n.languageTitle,
                isPresented: $showLanguagePicker,
                titleVisibility: .visible
            ) {
                ForEach(LocalizationStore.AppLanguage.allCases) { language in
                    Button(localization.label(for: language)) {
                        localization.set(language)
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            }
            .navigationTitle(L10n.profileTitle)
            .navigationDestination(for: Route.self) { RouteDestinationView(route: $0) }
            .task {
                await viewModel.load()
                fullName = viewModel.state.user?.fullName ?? viewModel.state.user?.userName ?? ""
                cacheSize = container.cacheManager.totalSizeBytes()
            }
            .onChange(of: selectedPhoto) { newValue in
                Task { await loadPhoto(newValue) }
            }
            .alert(L10n.deleteAccountTitle, isPresented: Binding(
                get: { deleteDialog != nil },
                set: { if !$0 { deleteDialog = nil } }
            )) {
                switch deleteDialog {
                case .confirm:
                    Button(L10n.delete, role: .destructive) { Task { await deleteAccount() } }
                    Button(L10n.cancel, role: .cancel) {}
                case .failure:
                    Button(L10n.signOutAction, role: .destructive) {
                        Task { await container.logout() }
                    }
                    Button(L10n.cancel, role: .cancel) {}
                case .none:
                    EmptyView()
                }
            } message: {
                switch deleteDialog {
                case .confirm:
                    Text(L10n.deactivateDescription)
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
            viewModel.reportValidationError(L10n.avatarTooLarge)
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
            container.didDeleteAccount()
        case .chatFailed:
            deleteDialog = .failure(L10n.chatDeactivateFailed)
        case .failed(let message):
            deleteDialog = .failure(message)
        }
    }
}
