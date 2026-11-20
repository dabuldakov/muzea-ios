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

    private func makePNG(width: CGFloat, height: CGFloat) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return try XCTUnwrap(image.pngData())
    }
}
