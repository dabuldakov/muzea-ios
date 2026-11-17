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
        Reason(id: "SPAM", title: L10n.reportSpam),
        Reason(id: "ABUSE", title: L10n.reportAbuse),
        Reason(id: "VIOLENCE", title: L10n.reportViolence),
        Reason(id: "ADULT", title: L10n.reportAdult),
        Reason(id: "ILLEGAL", title: L10n.reportIllegal),
        Reason(id: "OTHER", title: L10n.reportOther)
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
            .navigationTitle(L10n.reportTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
