import XCTest
@testable import Muzea

final class VideoPlaybackTests: XCTestCase {
    func testOwnVideoShowsDeleteOnly() {
        XCTAssertEqual(VideoAction.actions(canDelete: true), [.delete])
    }

    func testForeignVideoShowsReportOnly() {
        XCTAssertEqual(VideoAction.actions(canDelete: false), [.report])
    }

    func testDiskCacheStoresAndClearsVideo() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-cache-tests-\(UUID().uuidString)")
        let cache = VideoDiskCache(directory: directory)
        let remote = URL(string: "https://example.com/video.mp4")!
        let payload = Data(repeating: 7, count: 2048)

        XCTAssertNil(cache.cachedFile(for: remote))
        try cache.store(data: payload, for: remote)

        let cached = try XCTUnwrap(cache.cachedFile(for: remote))
        XCTAssertEqual(try Data(contentsOf: cached), payload)
        XCTAssertEqual(cache.sizeBytes(), Int64(payload.count))

        cache.clear()
        XCTAssertNil(cache.cachedFile(for: remote))
        XCTAssertEqual(cache.sizeBytes(), 0)
    }

    func testDiskCacheUsesDifferentFilesForDifferentURLs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("video-cache-tests-\(UUID().uuidString)")
        let cache = VideoDiskCache(directory: directory)
        let first = URL(string: "https://example.com/a.mp4")!
        let second = URL(string: "https://example.com/b.mp4")!

        try cache.store(data: Data([1]), for: first)
        try cache.store(data: Data([2]), for: second)

        XCTAssertNotEqual(cache.cachedFile(for: first), cache.cachedFile(for: second))
        XCTAssertEqual(cache.sizeBytes(), 2)
    }
}
