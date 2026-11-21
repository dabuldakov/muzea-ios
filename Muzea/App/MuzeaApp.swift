import SwiftUI
import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        PushManager.shared.configure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if FirebaseApp.app() != nil {
            Messaging.messaging().apnsToken = deviceToken
            PushManager.shared.refreshFcmToken()
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error)")
        ErrorReporter.logCaught("APNs", error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if FirebaseApp.app() != nil {
            Messaging.messaging().appDidReceiveMessage(userInfo)
        }
        PushManager.shared.handleRemote(userInfo: userInfo)
        completionHandler(.newData)
    }
}

@main
struct MuzeaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container = AppContainer()
    @StateObject private var appRouter = AppRouter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(appRouter)
                .environmentObject(container.networkMonitor)
                .onAppear { container.updateBadge() }
                .onChange(of: scenePhase) { phase in
                    if phase == .active { container.updateBadge() }
                }
        }
    }
}
