import Foundation

/// Язык приложения: системный или выбранный вручную (аналог per-app language
/// на Android). Выбор хранится в `UserDefaults`, строки берутся из нужного
/// `.lproj`-бандла, поэтому переключение работает без перезапуска.
final class LocalizationStore: ObservableObject {
    static let shared = LocalizationStore()

    enum AppLanguage: String, CaseIterable, Identifiable {
        case system
        case ru
        case en

        var id: String { rawValue }

        var localeIdentifier: String? {
            switch self {
            case .system: return nil
            case .ru: return "ru"
            case .en: return "en"
            }
        }
    }

    @Published private(set) var language: AppLanguage

    private let defaults: UserDefaults
    private let key = "app.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = AppLanguage(rawValue: defaults.string(forKey: key) ?? "") ?? .system
    }

    func set(_ language: AppLanguage) {
        guard language != self.language else { return }
        self.language = language
        if language == .system {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(language.rawValue, forKey: key)
        }
    }

    func label(for language: AppLanguage) -> String {
        switch language {
        case .system: return L10n.languageSystem
        // l10n:ignore — самоназвания языков не переводятся
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    var currentLabel: String {
        label(for: language)
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    /// `ru`/`en` для выбранного языка, иначе первый язык системы.
    var resolvedLanguageCode: String {
        if let code = language.localeIdentifier { return code }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.split(separator: "-").first.map(String.init) ?? "en"
    }

    /// Бандл с таблицами строк. Если языка нет в сборке — основной бандл.
    var bundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: resolvedLanguageCode,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}
