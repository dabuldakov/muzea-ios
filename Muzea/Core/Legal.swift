import Foundation

/// Правовая информация об операторе персональных данных и ссылки на документы.
/// Значения совпадают с `res/values/strings.xml` Android-приложения.
enum Legal {
    /// Язык правовых страниц. Сайт поддерживает только ru/en, поэтому
    /// для остальных языков открываем английскую версию.
    private static var legalLanguage: String {
        LocalizationStore.shared.resolvedLanguageCode == "ru" ? "ru" : "en"
    }

    static var policyURL: String {
        legalLanguage == "ru"
            ? "https://muzea.su/privacy?lang=ru"
            : "https://muzea.su/en/privacy?lang=en"
    }

    static var termsURL: String {
        legalLanguage == "ru"
            ? "https://muzea.su/terms?lang=ru"
            : "https://muzea.su/en/terms?lang=en"
    }

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
    static let consentVersion = 4

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
