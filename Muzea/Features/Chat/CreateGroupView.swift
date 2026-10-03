import SwiftUI

/// Создание группового чата: название и необязательный выбор участников.
struct CreateGroupView: View {
    let container: AppContainer
    let onCreated: (ChatResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateGroupViewModel
    @State private var title = ""
    @State private var selected: Set<String> = []
    @State private var showMemberPicker = false

    init(container: AppContainer, onCreated: @escaping (ChatResponse) -> Void) {
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
                Section("Название") {
                    TextField("Название группы", text: $title)
                }

                Section("Участники") {
                    Button {
                        showMemberPicker = true
                    } label: {
                        HStack {
                            Text(selected.isEmpty ? "Выбрать участников" : "Выбрано: \(selected.count)")
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
            .navigationTitle("Новая группа")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") { create() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isSubmitting)
                }
            }
            .task { await viewModel.loadContacts() }
            .sheet(isPresented: $showMemberPicker) {
                NavigationStack {
                    Group {
                        if viewModel.contacts.isEmpty {
                            Text("Нет контактов").foregroundColor(.secondary)
                        } else {
                            MemberPickerView(contacts: viewModel.contacts, selected: $selected)
                        }
                    }
                    .navigationTitle("Участники")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") { showMemberPicker = false }
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
