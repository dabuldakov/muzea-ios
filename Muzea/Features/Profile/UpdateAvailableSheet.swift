import SwiftUI

/// Карточка доступного обновления iOS. В отличие от Android здесь нет APK:
/// кнопка открывает страницу приложения в App Store.
struct UpdateAvailableSheet: View {
    let update: AppStoreUpdate

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 42))
                .foregroundColor(.accentColor)

            Text(L10n.updateAvailableTitle)
                .font(.title3).bold()

            Text(L10n.updateAvailableMessage(update.version))
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openURL(update.storeURL)
                dismiss()
            } label: {
                Text(L10n.updateOpen)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button(L10n.cancel) {
                dismiss()
            }
            .foregroundColor(.secondary)
        }
        .padding(24)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}
