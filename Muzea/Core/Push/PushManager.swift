import Foundation
import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

/// Единая точка настройки FCM, приёма токена и построения локальных
/// уведомлений из data-only push.
final class PushManager: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = PushManager()

    var onToken: ((String) -> Void)?
    private var lastToken: String?
    private var configured = false

    func configure() {
        guard !configured else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("[Push] GoogleService-Info.plist не найден — FCM отключён")
            return
        }
        FirebaseApp.configure()
        guard FirebaseApp.app() != nil else {
            print("[Push] FirebaseApp не сконфигурирован — FCM отключён")
            return
        }
        configured = true
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // APNs-регистрация не требует разрешения на показ баннеров. Регистрируем
        // всегда: иначе при отказе от пушей не будет ни APNs-, ни FCM-токена.
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Явно запрашивает FCM-токен после получения APNs-токена: delegate-колбэк
    /// не всегда приходит при первом запуске/после переустановки.
    func refreshFcmToken() {
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().token { [weak self] token, error in
            if let token {
                self?.handleToken(token)
            } else if let error {
                ErrorReporter.logCaught("FCM", error)
            }
        }
    }

    func handleToken(_ token: String) {
        lastToken = token
        onToken?(token)
    }

    func flushIfNeeded() {
        if let lastToken { onToken?(lastToken) }
    }

    /// Data-only FCM: приложение строит уведомление само. Если этот чат уже
    /// открыт, уведомление не создаём и снимаем старое.
    func handleRemote(userInfo: [AnyHashable: Any]) {
        guard let route = PushPayload.route(from: userInfo) else { return }

        // APNs уже показал alert (сервер шлёт его вместе с data). Второе
        // локальное уведомление не создаём — иначе будут дубли.
        if let aps = userInfo["aps"] as? [String: Any], aps["alert"] != nil {
            return
        }

        if case .chat(let target) = route, ActiveChatTracker.shared.chatUuid == target.chatUuid {
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: [Self.identifier(for: route)]
            )
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title(for: route, data: userInfo)
        content.body = PushPayload.body(for: userInfo) ?? ""
        content.sound = .default
        content.badge = 1
        content.userInfo = sanitize(userInfo)

        let request = UNNotificationRequest(
            identifier: Self.identifier(for: route),
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func title(for route: PushRoute, data: [AnyHashable: Any]) -> String {
        switch route {
        case .chat:
            return PushPayload.title(for: data) ?? L10n.pushNewMessage
        case .news:
            return PushPayload.title(for: data) ?? L10n.pushNews
        }
    }

    private static func identifier(for route: PushRoute) -> String {
        switch route {
        case .chat(let target): return "chat_\(target.chatUuid)"
        case .news(let id): return "news_\(id)"
        }
    }

    /// FCM data приходит как [AnyHashable: Any]; UNNotificationContent требует
    /// PropertyList-совместимые значения.
    private func sanitize(_ data: [AnyHashable: Any]) -> [AnyHashable: Any] {
        var result: [AnyHashable: Any] = [:]
        for (key, value) in data {
            if value is String || value is NSNumber || value is Bool {
                result[key] = value
            }
        }
        return result
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        handleToken(fcmToken)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let route = PushPayload.route(from: userInfo),
           case .chat(let target) = route,
           ActiveChatTracker.shared.chatUuid == target.chatUuid {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let route = PushPayload.route(from: userInfo) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PushRouteNotification.name, object: route)
            }
        }
        completionHandler()
    }
}
