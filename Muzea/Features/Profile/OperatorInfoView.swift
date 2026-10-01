import SwiftUI
import UIKit

/// Сведения об операторе персональных данных (ч. 1 ст. 19 ФЗ-152):
/// ФИО, ИНН, адрес, контакты для обращений и ссылки на правовые документы.
struct OperatorInfoView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text("Персональные данные пользователей обрабатывает:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("ФИО", value: Legal.operatorName)
                LabeledContent("Статус", value: Legal.operatorStatus)
                LabeledContent("ИНН", value: Legal.operatorINN)
                LabeledContent("Адрес", value: Legal.operatorAddress)
            }

            Section("Обращения") {
                link("Почта", detail: Legal.operatorEmail, url: Legal.operatorEmailURL)
                link("Телефон", detail: Legal.operatorPhone, url: Legal.operatorPhoneURL)
            }

            Section("Документы") {
                link("Политика обработки персональных данных", detail: nil, url: Legal.policyURL)
                link("Пользовательское соглашение", detail: nil, url: Legal.termsURL)
            }
        }
        .navigationTitle("Оператор персональных данных")
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
