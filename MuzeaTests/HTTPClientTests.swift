import XCTest
@testable import Muzea

final class HTTPClientTests: XCTestCase {

    private var store: TokenStore!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        store = TestSupport.makeStore()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        store = nil
        super.tearDown()
    }

    private func client() -> HTTPClient { TestSupport.makeupClient(tokenStore: store) }

    func testAddsAuthorizationHeaderWhenTokenPresent() async throws {
        store.token = "abc"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"id":1,"userName":"u","email":"e","role":"USER"}"#))
        }

        let _: UserResponse = try await client().request("GET", "/api/users/me")

        XCTAssertEqual(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
    }

    func testOmitsAuthorizationWhenUnauthorized() async throws {
        store.token = "abc"
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"ok"}"#))
        }

        let _: AuthServiceMessage = try await client().request(
            "POST",
            "/auth/otp/request",
            body: AuthEmailRequest(email: "a@b.c"),
            authorized: false
        )

        XCTAssertNil(MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func testEncodesJSONBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"message":"ok"}"#))
        }

        let _: AuthServiceMessage = try await client().request(
            "POST",
            "/auth/otp/request",
            body: AuthEmailRequest(email: "alice@example.com"),
            authorized: false
        )

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["email"], "alice@example.com")
    }

    func testAppendsQueryItems() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"count":3}"#))
        }

        let _: UnreadCountResponse = try await client().request(
            "GET",
            "/api/chats/unread-count/all",
            query: [URLQueryItem(name: "x", value: "1")]
        )

        XCTAssertEqual(MockURLProtocol.requests.first?.url?.query, "x=1")
    }

    func testUnauthorizedThrows() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 401), Data())
        }
        do {
            let _: UserResponse = try await client().request("GET", "/api/users/me")
            XCTFail("Ожидалась ошибка авторизации")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                return XCTFail("Ожидался .unauthorized, получено \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }

    func testServerErrorCarriesCodeAndMessage() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 500), TestSupport.data("boom"))
        }
        do {
            let _: UserResponse = try await client().request("GET", "/api/users/me")
            XCTFail("Ожидалась ошибка сервера")
        } catch let error as APIError {
            guard case .server(let code, let message) = error else {
                return XCTFail("Ожидался .server, получено \(error)")
            }
            XCTAssertEqual(code, 500)
            XCTAssertEqual(message, "boom")
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }

    func testDecodingErrorIsWrapped() async {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"unexpected":true}"#))
        }
        do {
            let _: UserResponse = try await client().request("GET", "/api/users/me")
            XCTFail("Ожидалась ошибка разбора")
        } catch let error as APIError {
            guard case .decoding = error else {
                return XCTFail("Ожидался .decoding, получено \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }

    func testTransportErrorIsWrapped() async {
        MockURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        do {
            let _: UserResponse = try await client().request("GET", "/api/users/me")
            XCTFail("Ожидалась сетевая ошибка")
        } catch let error as APIError {
            guard case .transport = error else {
                return XCTFail("Ожидался .transport, получено \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
    }

    func testRequestVoidSucceedsOn204() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, status: 204), Data())
        }
        try await client().requestVoid("DELETE", "/api/videos/1")
        XCTAssertEqual(MockURLProtocol.requests.first?.httpMethod, "DELETE")
    }

    func testUploadDataReturnsRawBody() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request, headers: ["Content-Type": "text/plain"]),
             TestSupport.data("api/avatars/x.png"))
        }

        let raw = try await client().uploadData(
            "/api/chats/c-1/avatar",
            fields: [:],
            files: [MultipartFile(field: "file", fileName: "a.jpg", mimeType: "image/jpeg", data: Data([1, 2, 3]))]
        )

        XCTAssertEqual(String(data: raw, encoding: .utf8), "api/avatars/x.png")
    }

    // MARK: - Unauthorized handler (token refresh)

    func testRetriesOnceAfterUnauthorizedWithNewToken() async throws {
        store.token = "old"
        var calls = 0
        let http = client()
        http.unauthorizedHandler = { failedToken in
            XCTAssertEqual(failedToken, "old")
            self.store.token = "new"
            return true
        }
        MockURLProtocol.handler = { request in
            calls += 1
            if calls == 1 {
                return (MockURLProtocol.response(for: request, status: 401), Data())
            }
            return (MockURLProtocol.response(for: request), TestSupport.data("[]"))
        }

        let _: [String] = try await http.request("GET", "/api/chats")

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(MockURLProtocol.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer new")
    }

    func testDoesNotRetryMoreThanOnce() async {
        store.token = "old"
        var calls = 0
        let http = client()
        http.unauthorizedHandler = { _ in true }
        MockURLProtocol.handler = { request in
            calls += 1
            return (MockURLProtocol.response(for: request, status: 401), Data())
        }

        do {
            let _: [String] = try await http.request("GET", "/api/chats")
            XCTFail("Ожидалась ошибка авторизации")
        } catch let error as APIError {
            guard case .unauthorized = error else {
                return XCTFail("Ожидался .unauthorized, получено \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
        XCTAssertEqual(calls, 2)
    }

    func testForbiddenIsRetriedWhenEnabled() async throws {
        store.token = "old"
        var calls = 0
        let http = client()
        http.treatsForbiddenAsUnauthorized = true
        http.unauthorizedHandler = { _ in
            self.store.token = "new"
            return true
        }
        MockURLProtocol.handler = { request in
            calls += 1
            if calls == 1 {
                return (MockURLProtocol.response(for: request, status: 403), Data())
            }
            return (MockURLProtocol.response(for: request), TestSupport.data("[]"))
        }

        let _: [String] = try await http.request("GET", "/api/users/me")

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(MockURLProtocol.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer new")
    }

    func testForbiddenIsNotRetriedByDefault() async {
        store.token = "old"
        var calls = 0
        let http = client()
        MockURLProtocol.handler = { request in
            calls += 1
            return (MockURLProtocol.response(for: request, status: 403), Data())
        }

        do {
            let _: [String] = try await http.request("GET", "/api/users/me")
            XCTFail("Ожидалась ошибка сервера")
        } catch let error as APIError {
            guard case .server(let code, _) = error, code == 403 else {
                return XCTFail("Ожидался .server(403), получено \(error)")
            }
        } catch {
            XCTFail("Неожиданная ошибка \(error)")
        }
        XCTAssertEqual(calls, 1)
    }

    func testUploadBuildsMultipartWithFieldsAndFiles() async throws {
        MockURLProtocol.handler = { request in
            (MockURLProtocol.response(for: request), TestSupport.data(#"{"id":1}"#))
        }

        let _: NewsCreateResponse = try await client().upload(
            "/api/news",
            fields: ["title": "T", "content": "C"],
            files: [MultipartFile(field: "image", fileName: "p.jpg", mimeType: "image/jpeg", data: Data([9]))]
        )

        let body = try XCTUnwrap(MockURLProtocol.requests.first?.capturedBody)
        let text = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(text.contains("name=\"title\""))
        XCTAssertTrue(text.contains("name=\"content\""))
        XCTAssertTrue(text.contains("name=\"image\"; filename=\"p.jpg\""))
        XCTAssertTrue(text.contains("Content-Type: image/jpeg"))
        XCTAssertEqual(
            MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data"),
            true
        )
    }
}