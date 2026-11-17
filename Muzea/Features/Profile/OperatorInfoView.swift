import SwiftUI
import UIKit

/// Сведения об операторе персональных данных (ч. 1 ст. 19 ФЗ-152):
/// ФИО, ИНН, адрес, контакты для обращений и ссылки на правовые документы.
struct OperatorInfoView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text(L10n.operatorTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent(L10n.operatorName, value: Legal.operatorName)
                LabeledContent(L10n.operatorStatus, value: Legal.operatorStatus)
                LabeledContent(L10n.operatorINN, value: Legal.operatorINN)
                LabeledContent(L10n.operatorAddress, value: Legal.operatorAddress)
            }

            Section(L10n.operatorContacts) {
                link(L10n.operatorEmail, detail: Legal.operatorEmail, url: Legal.operatorEmailURL)
                link(L10n.operatorPhone, detail: Legal.operatorPhone, url: Legal.operatorPhoneURL)
            }

            Section(L10n.operatorDocuments) {
                link(L10n.policyLink, detail: nil, url: Legal.policyURL)
                link(L10n.termsLink, detail: nil, url: Legal.termsURL)
            }
        }
        .navigationTitle(L10n.operatorLink)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func link(_ title: String, detail: String?, url: String) -> some View {
        Button {
            guard let target = URL(string: url) else { return }
            openURL(target)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(Color.accentColor)
    }
}
