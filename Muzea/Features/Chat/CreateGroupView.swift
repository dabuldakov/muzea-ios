import SwiftUI

/// Создание группового чата: название и необязательный выбор участников.
struct CreateGroupView: View {
    let container: AppContainer
    let onCreated: (Chat) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateGroupViewModel
    @State private var title = ""
    @State private var selected: Set<String> = []
    @State private var showMemberPicker = false

    init(container: AppContainer, onCreated: @escaping (Chat) -> Void) {
        self.container = container
        self.onCreated = onCreated
        _viewModel = StateObject(wrappedValue: CreateGroupViewModel(
            chatRepository: container.chatRepository,
            contactRepository: container.contactRepository
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.chatGroupName) {
                    TextField(L10n.chatGroupNamePlaceholder, text: $title)
                }

                Section(L10n.chatGroupMembers) {
                    Button {
                        showMemberPicker = true
                    } label: {
                        HStack {
                            Text(selected.isEmpty ? L10n.chatGroupChooseMembers : L10n.selectedCount(selected.count))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                    }
                    .disabled(viewModel.isLoadingContacts)
                }

                if let error = viewModel.error {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle(L10n.chatGroupNew)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSubmitting)
                }
            }
            .task { await viewModel.loadContacts() }
            .sheet(isPresented: $showMemberPicker) {
                NavigationStack {
                    Group {
                        if viewModel.contacts.isEmpty {
                            Text(L10n.chatGroupNoContacts).foregroundColor(.secondary)
                        } else {
                            MemberPickerView(contacts: viewModel.contacts, selected: $selected)
                        }
                    }
                    .navigationTitle(L10n.chatGroupMembers)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L10n.done) { showMemberPicker = false }
                        }
                    }
                }
            }
        }
    }

    private func create() {
        Task {
            if let chat = await viewModel.create(title: title, memberUuids: Array(selected)) {
                onCreated(chat)
                dismiss()
            }
        }
    }
}
