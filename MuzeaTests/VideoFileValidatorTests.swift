import XCTest
@testable import Muzea

final class VideoFileValidatorTests: XCTestCase {

    func testValidMp4IsNotTruncated() {
        let data = atom("ftyp", Data(repeating: 0, count: 8))
            + atom("mdat", Data(repeating: 1, count: 8))
        XCTAssertFalse(VideoFileValidator.isTruncated(data))
    }

    func testTruncatedMdatIsRejected() {
        var data = atom("ftyp", Data(repeating: 0, count: 8))
        // Заголовок mdat обещает 100 байт, но тело короче.
        data.append(contentsOf: [0, 0, 0, 100])
        data.append(contentsOf: Array("mdat".utf8))
        data.append(contentsOf: [1, 2, 3, 4])

        XCTAssertTrue(VideoFileValidator.isTruncated(data))
        XCTAssertTrue(VideoFileValidator.describe(data).contains("mdat=100"))
    }

    func testShortAndForeignContainersAreHandled() {
        XCTAssertTrue(VideoFileValidator.isTruncated(Data()))
        XCTAssertTrue(VideoFileValidator.isTruncated(Data(repeating: 0, count: 10)))
        // Не MP4/MOV: проверку не применяем.
        XCTAssertFalse(VideoFileValidator.isTruncated(atom("webm", Data(repeating: 0, count: 32))))
    }

    private func atom(_ type: String, _ payload: Data) -> Data {
        var data = Data()
        let size = UInt32(8 + payload.count)
        data.append(UInt8((size >> 24) & 0xFF))
        data.append(UInt8((size >> 16) & 0xFF))
        data.append(UInt8((size >> 8) & 0xFF))
        data.append(UInt8(size & 0xFF))
        data.append(contentsOf: Array(type.utf8))
        data.append(payload)
        return data
    }
}
