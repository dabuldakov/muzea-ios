import SwiftUI

/// Создание группового чата: название и необязательный выбор участников.
struct CreateGroupView: View {
    let repository: ChatRepository
    let onCreated: (ChatResponse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var contacts: [ContactResponse] = []
    @State private var selected: Set<String> = []
    @State private var isLoadingContacts = false
    @State private var showMemberPicker = false
    @State private var isSubmitting = false
    @State private var error: String?

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
                    .disabled(isLoadingContacts)
                }

                if let error {
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
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .task { await loadContacts() }
            .sheet(isPresented: $showMemberPicker) {
                NavigationStack {
                    Group {
                        if contacts.isEmpty {
                            Text("Нет контактов").foregroundColor(.secondary)
                        } else {
                            MemberPickerView(contacts: contacts, selected: $selected)
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

    private func loadContacts() async {
        isLoadingContacts = true
        contacts = (try? await repository.loadContacts()) ?? []
        isLoadingContacts = false
    }

    private func create() {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSubmitting = true
        error = nil
        Task {
            do {
                let chat = try await repository.createGroupChat(title: name, memberUuids: Array(selected))
                onCreated(chat)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
