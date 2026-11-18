import XCTest
@testable import Muzea

final class LocalizationStoreTests: XCTestCase {

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "localization-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    func testDefaultsToSystem() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        XCTAssertEqual(LocalizationStore(defaults: defaults).language, .system)
    }

    func testChoicePersistsBetweenInstances() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LocalizationStore(defaults: defaults)
        store.set(.ru)

        XCTAssertEqual(store.language, .ru)
        XCTAssertEqual(LocalizationStore(defaults: defaults).language, .ru)
        XCTAssertEqual(store.resolvedLanguageCode, "ru")
    }

    func testSystemChoiceClearsStoredValue() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LocalizationStore(defaults: defaults)
        store.set(.en)
        store.set(.system)

        XCTAssertEqual(store.language, .system)
        XCTAssertNil(defaults.string(forKey: "app.language"))
    }

    func testLocaleFollowsSelection() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LocalizationStore(defaults: defaults)
        store.set(.en)
        XCTAssertEqual(store.locale.identifier, "en")

        store.set(.ru)
        XCTAssertEqual(store.locale.identifier, "ru")
    }

    func testLabelsAreStableNativeNames() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = LocalizationStore(defaults: defaults)
        XCTAssertEqual(store.label(for: .ru), "Русский")
        XCTAssertEqual(store.label(for: .en), "English")
    }

    func testAllCasesHaveDistinctIdentifiers() {
        let ids = LocalizationStore.AppLanguage.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
