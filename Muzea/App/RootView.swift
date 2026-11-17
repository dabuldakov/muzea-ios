import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var appRouter: AppRouter

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
        .onOpenURL { url in
            _ = appRouter.handleURL(url)
        }
        // Universal Links: https://muzea.su/chat/... приходит не через onOpenURL.
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            _ = appRouter.handleURL(url)
        }
    }
}
