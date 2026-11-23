import CoreGraphics
import XCTest
@testable import Muzea

final class ChatConversationModelsTests: XCTestCase {

    private let message = FakeChatRepository.message("m-1")

    func testMessagePopupIdUsesMessageUuid() {
        let popup = MessagePopupState(message: message, point: CGPoint(x: 4, y: 8))
        XCTAssertEqual(popup.id, "m-1")
    }

    func testActiveSheetIdsAreStable() {
        XCTAssertEqual(ActiveSheet.forward.id, "forward")
        XCTAssertEqual(ActiveSheet.emojiGif.id, "emoji-gif")
        XCTAssertEqual(ActiveSheet.details(message).id, "details-m-1")
        XCTAssertEqual(ActiveSheet.reaction(message).id, "reaction-m-1")
        XCTAssertEqual(ActiveSheet.report(message).id, "report-m-1")
    }

    func testActiveAlertIdsAreStable() {
        XCTAssertEqual(ActiveAlert.error("boom").id, "error-boom")
        XCTAssertEqual(ActiveAlert.notice("ok").id, "notice-ok")
        XCTAssertEqual(ActiveAlert.delete(message).id, "delete-m-1")
        XCTAssertEqual(ActiveAlert.deleteSelected.id, "delete-selected")
        XCTAssertEqual(ActiveAlert.block(message).id, "block-m-1")
    }

    func testSelectionFlagFollowsSelectionSet() {
        var state = ChatConversationUiState()
        XCTAssertFalse(state.isSelecting)
        state.selection = ["m-1"]
        XCTAssertTrue(state.isSelecting)
        state.selection = []
        XCTAssertFalse(state.isSelecting)
    }
}
