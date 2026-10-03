import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
            // Без согласия на обработку персональных данных приложение не запускается (ст. 9 ФЗ-152).
            if !container.isConsentAccepted {
                ConsentView(consent: container.consentManager) {
                    container.didAcceptConsent()
                }
            } else if container.isLoggedIn {
                MainTabView()
            } else {
                LoginView(container: container)
            }
        }
    }
}
