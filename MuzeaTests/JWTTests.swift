import XCTest
@testable import Muzea

final class JWTTests: XCTestCase {

    private func base64URL(_ object: [String: String]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func token(sub: String) -> String {
        let header = base64URL(["alg": "HS256", "typ": "JWT"])
        let payload = base64URL(["sub": sub, "iat": "1"])
        return "\(header).\(payload).signature"
    }

    func testExtractsSubject() {
        XCTAssertEqual(JWT.subject(from: token(sub: "user-123")), "user-123")
    }

    func testNilTokenReturnsNil() {
        XCTAssertNil(JWT.subject(from: nil))
    }

    func testMalformedTokensReturnNil() {
        XCTAssertNil(JWT.subject(from: "not-a-jwt"))
        XCTAssertNil(JWT.subject(from: "only.two"))
        XCTAssertNil(JWT.subject(from: "a.!!!.c"))
    }

    func testPayloadWithoutSubjectReturnsNil() {
        let header = base64URL(["alg": "HS256"])
        let payload = base64URL(["iat": "1"])
        XCTAssertNil(JWT.subject(from: "\(header).\(payload).sig"))
    }
}