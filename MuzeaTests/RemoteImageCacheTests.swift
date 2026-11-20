import XCTest
import UIKit
@testable import Muzea

/// Кэш картинок: downsample не должен отдавать полноразмерный PNG и не должен
/// падать на мусоре. Дисковая часть проверяется косвенно — через повторную
/// загрузку одного и того же URL в `AvatarView` на устройстве.
final class RemoteImageCacheTests: XCTestCase {

    func testDownsampleLimitsMaximumPixelSize() throws {
        let data = try makePNG(width: 400, height: 200)

        let image = try XCTUnwrap(RemoteImageCache.downsample(data, maxPixelSize: 100))
        let cg = try XCTUnwrap(image.cgImage)

        XCTAssertLessThanOrEqual(max(cg.width, cg.height), 100)
        XCTAssertGreaterThan(cg.width, cg.height)
    }

    func testDownsampleKeepsSmallImageSize() throws {
        let data = try makePNG(width: 48, height: 48)

        let image = try XCTUnwrap(RemoteImageCache.downsample(data, maxPixelSize: 200))
        let cg = try XCTUnwrap(image.cgImage)

        XCTAssertEqual(cg.width, cg.height)
        XCTAssertLessThanOrEqual(cg.width, 48)
    }

    func testDownsampleRejectsGarbage() {
        XCTAssertNil(RemoteImageCache.downsample(Data([0, 1, 2, 3]), maxPixelSize: 64))
        XCTAssertNil(RemoteImageCache.downsample(Data(), maxPixelSize: 64))
    }

    func testImageIsCachedOnDiskAndUsesToken() async throws {
        MockURLProtocol.reset()
        defer { MockURLProtocol.reset() }
        let png = try makePNG(width: 320, height: 180)
        MockURLProtocol.handler = { request in
            (
                MockURLProtocol.response(
                    for: request,
                    headers: ["Content-Type": "image/png"]
                ),
                png
            )
        }

        let url = URL(string: "https://chat-muzea.su/api/avatars/test-\(UUID().uuidString).png")!
        let first = RemoteImageCache(session: TestSupport.session())
        first.authTokenProvider = { "token-1" }

        let firstImage = await first.image(for: url, maxPixelSize: 64)
        XCTAssertNotNil(firstImage)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(
            MockURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization"),
            "Bearer token-1"
        )

        // Новый экземпляр без memory-кэша должен взять файл с диска.
        let second = RemoteImageCache(session: TestSupport.session())
        let secondImage = await second.image(for: url, maxPixelSize: 64)
        XCTAssertNotNil(secondImage)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    private func makePNG(width: CGFloat, height: CGFloat) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        let image = renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.pngData())
    }
}
