import SwiftUI

/// Список контактов с множественным выбором (по contactUserUuid).
struct MemberPickerView: View {
    let contacts: [ContactResponse]
    @Binding var selected: Set<String>

    var body: some View {
        List(contacts) { contact in
            Button {
                toggle(contact.contactUserUuid)
            } label: {
                HStack(spacing: 12) {
                    AvatarView(url: ImageURL.chat(contact.avatarUrl), size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.displayName).foregroundColor(.primary)
                        if let username = contact.username, !username.isEmpty {
                            Text("@\(username)").font(.caption).foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected(contact) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected(contact) ? .accentColor : .secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func isSelected(_ contact: ContactResponse) -> Bool {
        guard let uuid = contact.contactUserUuid, !uuid.isEmpty else { return false }
        return selected.contains(uuid)
    }

    private func toggle(_ uuid: String?) {
        guard let uuid, !uuid.isEmpty else { return }
        if selected.contains(uuid) {
            selected.remove(uuid)
        } else {
            selected.insert(uuid)
        }
    }
}
