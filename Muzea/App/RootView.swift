import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Group {
            if container.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
