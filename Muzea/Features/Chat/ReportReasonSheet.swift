import SwiftUI

/// Причины жалобы — те же значения, что на Android и в API.
struct ReportReasonSheet: View {
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct Reason: Identifiable {
        let id: String
        let title: String
    }

    private let reasons = [
        Reason(id: "SPAM", title: "Спам"),
        Reason(id: "ABUSE", title: "Оскорбления и травля"),
        Reason(id: "VIOLENCE", title: "Насилие"),
        Reason(id: "ADULT", title: "Материалы для взрослых"),
        Reason(id: "ILLEGAL", title: "Незаконный контент"),
        Reason(id: "OTHER", title: "Другое")
    ]

    var body: some View {
        NavigationStack {
            List(reasons) { reason in
                Button {
                    onPick(reason.id)
                    dismiss()
                } label: {
                    Text(reason.title).foregroundColor(.primary)
                }
            }
            .navigationTitle("Причина жалобы")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
