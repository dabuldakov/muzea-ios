import XCTest
@testable import Muzea

final class ContentReportRepositoryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testReportPostsContentTypeIdAndReason() async throws {
        let store = TestSupport.makeStore()
        store.token = "access"
        let repository = ContentReportRepositoryImpl(
            client: TestSupport.makeupClient(tokenStore: store)
        )
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 201), Data("{}".utf8))
        }

        try await repository.report(
            contentType: "NEWS",
            contentId: 54,
            reason: "SPAM",
            comment: nil
        )

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let json = request.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual(json?["contentType"] as? String, "NEWS")
        XCTAssertEqual(json?["contentId"] as? Int, 54)
        XCTAssertEqual(json?["reason"] as? String, "SPAM")
    }
}

final class CacheManagerTests: XCTestCase {

    func testSizeAndClear() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cache-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: root.appendingPathComponent("a.bin"))
        try Data([4, 5]).write(to: root.appendingPathComponent("b.bin"))

        var cleared = false
        let manager = CacheManager(
            directories: [root],
            clearActions: [{ cleared = true }]
        )

        XCTAssertEqual(manager.totalSizeBytes(), 5)
        await manager.clear()
        XCTAssertEqual(manager.totalSizeBytes(), 0)
        XCTAssertTrue(cleared)
    }
}
