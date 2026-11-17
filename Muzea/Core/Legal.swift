import Foundation

/// Правовая информация об операторе персональных данных и ссылки на документы.
/// Значения совпадают с `res/values/strings.xml` Android-приложения.
enum Legal {
    static let policyURL = "https://muzea.su/privacy"
    static let termsURL = "https://muzea.su/terms"

    // l10n:ignore — имя оператора, данные
    static let operatorName = "Булдаков Дмитрий Александрович"
    // l10n:ignore — правовой статус, данные
    static let operatorStatus = "Физическое лицо, оператор персональных данных"
    static let operatorINN = "701712666930"
    // l10n:ignore — адрес, данные
    static let operatorAddress = "Томская область, г. Томск, ул. Пушкина, д. 61/3, кв. 267"
    static let operatorEmail = "dabuldakov@mail.ru"
    static let operatorPhone = "+7 913 800-24-16"

    static let operatorEmailURL = "mailto:\(Legal.operatorEmail)"
    static let operatorPhoneURL = "tel:\(Legal.operatorPhone)"

    /// Текущая редакция согласия на обработку персональных данных.
    /// Увеличивайте при изменении текста согласия или политики — экран согласия
    /// покажется заново всем пользователям.
    static let consentVersion = 3

    /// Текст согласия, ст. 9 ФЗ-152. Подставляется операторский email.
    /// Сам текст живёт в `L10n`, чтобы на английском он тоже был английским.
    static var consentBody: String {
        L10n.consentBody(operatorEmail)
    }

    /// Сообщение о неудачной деактивации с форматом `%@` — операторский email.
    static func deleteFailedMessage(email: String = Legal.operatorEmail) -> String {
        L10n.deactivateFallback(email)
    }
}
