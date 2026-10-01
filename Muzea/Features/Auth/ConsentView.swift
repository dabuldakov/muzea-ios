import SwiftUI
import UIKit

/// Экран согласия на обработку персональных данных (ст. 9 ФЗ-152).
/// Показывается при первом запуске и повторно, если редакция согласия изменилась.
struct ConsentView: View {
    let consent: ConsentManager
    let onAccept: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Условия и обработка персональных данных")
                        .font(.title2)
                        .bold()

                    Text(Legal.consentBody)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    VStack(alignment: .leading, spacing: 12) {
                        legalLink("Открыть Пользовательское соглашение", url: Legal.termsURL)
                        legalLink("Открыть Политику обработки персональных данных", url: Legal.policyURL)
                    }
                }
                .padding()
            }

            VStack(spacing: 12) {
                Button {
                    consent.accept()
                    onAccept()
                } label: {
                    Text("Принять и продолжить").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                // Как и на Android, отказ закрывает приложение: без согласия
                // обработка персональных данных недопустима.
                Button("Не принимать") { exit(0) }
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    private func legalLink(_ title: String, url: String) -> some View {
        Button(title) {
            guard let target = URL(string: url) else { return }
            openURL(target)
        }
        .font(.callout)
    }
}
