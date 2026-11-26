import Foundation

/// Доступное обновление iOS-приложения в App Store.
struct AppStoreUpdate: Equatable, Identifiable {
    let version: String
    let storeURL: URL

    var id: String { version }
}

enum AppUpdateCheckResult: Equatable {
    case available(AppStoreUpdate)
    case upToDate
    case failed
}

/// Сравнение версий вида «1.2.0». Нечисловые суффиксы трактуются как 0 —
/// для релизных тегов этого достаточно.
enum AppVersion {
    static func compare(_ lhs: String, _ rhs: String) -> Int {
        let left = lhs.split(separator: ".")
        let right = rhs.split(separator: ".")
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? Int(left[index]) ?? 0 : 0
            let rightValue = index < right.count ? Int(right[index]) ?? 0 : 0
            if leftValue != rightValue { return leftValue < rightValue ? -1 : 1 }
        }
        return 0
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) > 0
    }
}

/// Проверка новой версии в App Store.
///
/// В отличие от Android здесь нельзя скачать APK: обновление ставится через
/// App Store, поэтому repository отдаёт версию и ссылку на карточку приложения.
@MainActor
final class AppUpdateRepository: ObservableObject {
    @Published private(set) var availableUpdate: AppStoreUpdate?

    let currentVersion: String

    private let client: HTTPClient
    private let appID: String

    init(
        client: HTTPClient? = nil,
        appID: String = "6835792727",
        currentVersion: String? = nil
    ) {
        self.client = client ?? HTTPClient(
            baseURL: URL(string: "https://itunes.apple.com")!,
            tokenProvider: { nil }
        )
        self.appID = appID
        self.currentVersion = currentVersion
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0"
    }

    func checkForUpdate() async -> AppUpdateCheckResult {
        do {
            let response: LookupResponse = try await client.request(
                "GET",
                "/lookup",
                query: [URLQueryItem(name: "id", value: appID)],
                authorized: false
            )
            guard let result = response.results.first else {
                availableUpdate = nil
                return .upToDate
            }
            guard let storeURL = URL(string: result.trackViewUrl) else {
                return .failed
            }
            guard AppVersion.isNewer(result.version, than: currentVersion) else {
                availableUpdate = nil
                return .upToDate
            }
            let update = AppStoreUpdate(version: result.version, storeURL: storeURL)
            availableUpdate = update
            return .available(update)
        } catch {
            return .failed
        }
    }

    private struct LookupResponse: Decodable {
        let resultCount: Int
        let results: [LookupResult]
    }

    private struct LookupResult: Decodable {
        let version: String
        let trackViewUrl: String
    }
}
