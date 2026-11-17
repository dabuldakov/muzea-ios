import XCTest
@testable import Muzea

final class WaveformTests: XCTestCase {

    func testEmptySamplesProduceSilentBars() {
        let bars = Waveform.downsample([], count: 8)

        XCTAssertEqual(bars.count, 8)
        XCTAssertTrue(bars.allSatisfy { $0 == Waveform.minimumLevel })
    }

    func testZeroCountProducesNoBars() {
        XCTAssertTrue(Waveform.downsample([0.5, 0.7], count: 0).isEmpty)
    }

    func testSilenceStaysAtMinimum() {
        let bars = Waveform.downsample([0, 0, 0, 0], count: 4)

        XCTAssertEqual(bars, Array(repeating: Waveform.minimumLevel, count: 4))
    }

    func testConstantSignalFillsEveryBar() {
        let bars = Waveform.downsample([0.25, 0.25, 0.25, 0.25], count: 4)

        XCTAssertEqual(bars, Array(repeating: 1, count: 4))
    }

    func testLouderHalfProducesTallerBars() {
        let quiet = [Float](repeating: 0.1, count: 16)
        let loud = [Float](repeating: 0.9, count: 16)
        let bars = Waveform.downsample(quiet + loud, count: 8)

        XCTAssertEqual(bars.count, 8)
        let firstHalf = bars.prefix(4).reduce(0, +)
        let secondHalf = bars.suffix(4).reduce(0, +)
        XCTAssertLessThan(firstHalf, secondHalf)
    }

    func testNonFiniteSamplesAreIgnored() {
        let bars = Waveform.downsample([.nan, .infinity, 0.5], count: 3)

        XCTAssertEqual(bars, [Waveform.minimumLevel, Waveform.minimumLevel, 1])
    }

    func testMinimumLevelIsVisible() {
        let bars = Waveform.downsample([1, 0.0001], count: 2)

        XCTAssertTrue(bars.allSatisfy { $0 >= Waveform.minimumLevel && $0 <= 1 })
    }

    func testPlayedCountFollowsProgress() {
        XCTAssertEqual(Waveform.playedCount(total: 10, progress: 0), 0)
        XCTAssertEqual(Waveform.playedCount(total: 10, progress: 0.5), 5)
        XCTAssertEqual(Waveform.playedCount(total: 10, progress: 1), 10)
        XCTAssertEqual(Waveform.playedCount(total: 10, progress: 1.5), 10)
        XCTAssertEqual(Waveform.playedCount(total: 10, progress: -1), 0)
        XCTAssertEqual(Waveform.playedCount(total: 0, progress: 0.5), 0)
    }
}
