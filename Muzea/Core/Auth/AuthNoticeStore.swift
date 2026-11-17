import Foundation

/// Одноразовая подсказка о переходе на вход по email-коду. После миграции на
/// единый IdP старые аккаунты нужно «зарегистрировать» заново с прежними email
/// и username — иначе вход по коду молча не находит пользователя (сервер
/// отвечает нейтрально и письмо не отправляет).
struct AuthNoticeStore {
    private let defaults: UserDefaults
    private let key = "auth.passwordlessNoticeShown"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldShowPasswordlessNotice: Bool {
        !defaults.bool(forKey: key)
    }

    func markPasswordlessNoticeShown() {
        defaults.set(true, forKey: key)
    }
}
