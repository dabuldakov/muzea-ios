import XCTest
@testable import Muzea

@MainActor
final class AppUpdateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testVersionComparison() {
        XCTAssertTrue(AppVersion.isNewer("1.2", than: "1.1"))
        XCTAssertTrue(AppVersion.isNewer("1.10.0", than: "1.9.9"))
        XCTAssertFalse(AppVersion.isNewer("1.1", than: "1.1"))
        XCTAssertFalse(AppVersion.isNewer("1.0", than: "1.1"))
        XCTAssertTrue(AppVersion.isNewer("2", than: "1.9.9"))
    }

    func testAvailableUpdateFromLookup() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/lookup")
            XCTAssertEqual(request.url?.query, "id=6835792727")
            return (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"resultCount":1,"results":[{"version":"1.2","trackViewUrl":"https://apps.apple.com/app/id6835792727"}]}"#)
            )
        }
        let repository = makeRepository(currentVersion: "1.1")

        let result = await repository.checkForUpdate()

        XCTAssertEqual(
            result,
            .available(AppStoreUpdate(
                version: "1.2",
                storeURL: URL(string: "https://apps.apple.com/app/id6835792727")!
            ))
        )
        XCTAssertEqual(repository.availableUpdate?.version, "1.2")
    }

    func testUpToDateFromLookup() async {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"resultCount":1,"results":[{"version":"1.1","trackViewUrl":"https://apps.apple.com/app/id6835792727"}]}"#)
            )
        }
        let repository = makeRepository(currentVersion: "1.1")

        let result = await repository.checkForUpdate()
        XCTAssertEqual(result, .upToDate)
        XCTAssertNil(repository.availableUpdate)
    }

    func testEmptyLookupIsUpToDate() async {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(for: request),
                TestSupport.data(#"{"resultCount":0,"results":[]}"#)
            )
        }
        let repository = makeRepository(currentVersion: "1.1")

        let result = await repository.checkForUpdate()
        XCTAssertEqual(result, .upToDate)
    }

    func testLookupFailure() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), Data())
        }
        let repository = makeRepository(currentVersion: "1.1")

        let result = await repository.checkForUpdate()
        XCTAssertEqual(result, .failed)
    }

    private func makeRepository(currentVersion: String) -> AppUpdateRepository {
        let client = HTTPClient(
            baseURL: URL(string: "https://itunes.apple.com")!,
            tokenProvider: { nil },
            session: TestSupport.session()
        )
        return AppUpdateRepository(client: client, currentVersion: currentVersion)
    }
}
