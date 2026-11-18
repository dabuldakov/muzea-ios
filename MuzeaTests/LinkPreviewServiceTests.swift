import XCTest
@testable import Muzea

final class LinkPreviewServiceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func html(_ body: String) -> Data {
        Data(body.utf8)
    }

    func testLoadsOpenGraphAndCachesResult() async throws {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(
                    for: request,
                    headers: ["Content-Type": "text/html; charset=utf-8"]
                ),
                self.html("""
                <html><head>
                <meta property="og:title" content="Muzea">
                <meta property="og:description" content="Chat">
                <meta property="og:image" content="/cover.png">
                <meta property="og:site_name" content="muzea.su">
                </head></html>
                """)
            )
        }
        let service = LinkPreviewService(session: TestSupport.session())

        let preview = await service.load(URL(string: "https://example.com/page")!)
        let cached = await service.load(URL(string: "https://example.com/page")!)

        XCTAssertEqual(preview?.title, "Muzea")
        XCTAssertEqual(preview?.description, "Chat")
        XCTAssertEqual(preview?.siteName, "muzea.su")
        XCTAssertEqual(preview?.imageURL?.absoluteString, "https://example.com/cover.png")
        XCTAssertEqual(cached, preview)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testUnsafeURLIsNotRequested() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), self.html("<html></html>"))
        }
        let service = LinkPreviewService(session: TestSupport.session())

        let preview = await service.load(URL(string: "http://127.0.0.1/secret")!)

        XCTAssertNil(preview)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testNonHTMLResponseIsIgnored() async {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(
                    for: request,
                    headers: ["Content-Type": "image/png"]
                ),
                Data([1, 2, 3])
            )
        }
        let service = LinkPreviewService(session: TestSupport.session())

        let preview = await service.load(URL(string: "https://example.com/image.png")!)

        XCTAssertNil(preview)
    }

    func testServerErrorIsIgnored() async {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(
                    for: request,
                    status: 500,
                    headers: ["Content-Type": "text/html"]
                ),
                self.html("<html><title>Error</title></html>")
            )
        }
        let service = LinkPreviewService(session: TestSupport.session())

        let preview = await service.load(URL(string: "https://example.com/error")!)
        XCTAssertNil(preview)
    }

    func testExpiredCacheRefetches() async throws {
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(
                    for: request,
                    headers: ["Content-Type": "text/html"]
                ),
                self.html("<html><head><meta property=\"og:title\" content=\"T\"></head></html>")
            )
        }
        let service = LinkPreviewService(session: TestSupport.session(), ttl: 0)

        _ = await service.load(URL(string: "https://example.com/page")!)
        _ = await service.load(URL(string: "https://example.com/page")!)

        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }
}
