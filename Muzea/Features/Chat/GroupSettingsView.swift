import SwiftUI
import PhotosUI

/// Настройки чата/группы: аватар, список участников и добавление новых.
struct GroupSettingsView: View {
    let chat: ChatResponse
    let repository: ChatRepository
    let myUserUuid: String?

    @State private var participants: [ChatParticipantResponse] = []
    @State private var contacts: [ContactResponse] = []
    @State private var avatarUrl: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedMembers: Set<String> = []
    @State private var showMemberPicker = false
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var error: String?

    init(chat: ChatResponse, repository: ChatRepository, myUserUuid: String?) {
        self.chat = chat
        self.repository = repository
        self.myUserUuid = myUserUuid
        _avatarUrl = State(initialValue: chat.avatarUrl)
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        AvatarView(url: ImageURL.chat(avatarUrl), size: 96)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Сменить аватар")
                        }
                        .disabled(isUploading)

                        if isUploading { ProgressView() }
                    }
                    Spacer()
                }
            }

            Section("Участники (\(participants.count))") {
                if participants.isEmpty {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Text("Нет участников").foregroundColor(.secondary)
                    }
                } else {
                    ForEach(participants) { participant in
                        ParticipantRow(participant: participant, isMe: participant.userUuid == myUserUuid)
                    }
                }
            }

            if let error {
                Section { Text(error).foregroundColor(.red) }
            }

            Section {
                Button {
                    showMemberPicker = true
                } label: {
                    Label("Добавить участников", systemImage: "person.badge.plus")
                }
                .disabled(contacts.isEmpty)
            }
        }
        .navigationTitle(chat.title ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: selectedPhoto) { newValue in
            Task { await uploadAvatar(newValue) }
        }
        .sheet(isPresented: $showMemberPicker) {
            NavigationStack {
                MemberPickerView(contacts: contacts, selected: $selectedMembers)
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

    private func load() async {
        isLoading = true
        participants = (try? await repository.loadChatParticipants(chatUuid: chat.chatUuid)) ?? []
        contacts = (try? await repository.loadContacts()) ?? []
        isLoading = false
    }

    private func addMembers() {
        let uuids = Array(selectedMembers)
        selectedMembers = []
        showMemberPicker = false
        Task {
            do {
                try await repository.addGroupParticipants(chatUuid: chat.chatUuid, memberUuids: uuids)
                await load()
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        isUploading = true
        do {
            let path = try await repository.uploadChatAvatar(
                chatUuid: chat.chatUuid,
                data: data,
                fileName: "chat_avatar_\(Int(Date().timeIntervalSince1970)).jpg",
                mimeType: "image/jpeg"
            )
            if let path, !path.isEmpty {
                avatarUrl = path
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isUploading = false
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
