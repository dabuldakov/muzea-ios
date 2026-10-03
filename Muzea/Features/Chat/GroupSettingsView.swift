import SwiftUI
import PhotosUI

/// Настройки чата/группы: аватар, список участников и добавление новых.
struct GroupSettingsView: View {
    let chat: ChatResponse
    let container: AppContainer

    @StateObject private var viewModel: GroupSettingsViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedMembers: Set<String> = []
    @State private var showMemberPicker = false

    init(chat: ChatResponse, container: AppContainer) {
        self.chat = chat
        self.container = container
        _viewModel = StateObject(wrappedValue: GroupSettingsViewModel(
            chatUuid: chat.chatUuid,
            myUserUuid: container.myUserUuid,
            initialAvatarUrl: chat.avatarUrl,
            chatRepository: container.chatRepository,
            contactRepository: container.contactRepository,
            avatarRepository: container.avatarRepository
        ))
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        AvatarView(url: ImageURL.chat(viewModel.avatarUrl), size: 96)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Сменить аватар")
                        }
                        .disabled(viewModel.state.isUploading)

                        if viewModel.state.isUploading { ProgressView() }
                    }
                    Spacer()
                }
            }

            Section("Участники (\(viewModel.state.participants.count))") {
                if viewModel.state.participants.isEmpty {
                    if viewModel.state.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Text("Нет участников").foregroundColor(.secondary)
                    }
                } else {
                    ForEach(viewModel.state.participants) { participant in
                        ParticipantRow(
                            participant: participant,
                            isMe: participant.userUuid == viewModel.myUserUuid
                        )
                    }
                }
            }

            if let error = viewModel.state.error {
                Section { Text(error).foregroundColor(.red) }
            }

            Section {
                Button {
                    showMemberPicker = true
                } label: {
                    Label("Добавить участников", systemImage: "person.badge.plus")
                }
                .disabled(viewModel.contacts.isEmpty)
            }
        }
        .navigationTitle(chat.title ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .onChange(of: selectedPhoto) { newValue in
            Task { await uploadAvatar(newValue) }
        }
        .sheet(isPresented: $showMemberPicker) {
            NavigationStack {
                MemberPickerView(contacts: viewModel.contacts, selected: $selectedMembers)
                    .navigationTitle("Добавить участников")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Отмена") { selectedMembers = [] }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Добавить") { addMembers() }
                                .disabled(selectedMembers.isEmpty)
                        }
                    }
            }
        }
    }

    private func addMembers() {
        let uuids = Array(selectedMembers)
        selectedMembers = []
        showMemberPicker = false
        Task { _ = await viewModel.addMembers(uuids) }
    }

    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard data.count <= Config.maxAvatarBytes else {
            viewModel.reportValidationError("Выберите изображение размером до 5 МБ")
            return
        }
        await viewModel.uploadAvatar(
            data: data,
            fileName: "chat_avatar_\(Int(Date().timeIntervalSince1970)).jpg",
            mimeType: "image/jpeg"
        )
    }
}

struct ParticipantRow: View {
    let participant: ChatParticipantResponse
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: ImageURL.chat(participant.avatarUrl), size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName).font(.headline)
                if isMe {
                    Text("You").font(.caption).foregroundColor(.secondary)
                } else if let username = participant.username, !username.isEmpty {
                    Text("@\(username)").font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            if participant.role == "OWNER" {
                Text("Owner")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
            }
        }
    }
}
