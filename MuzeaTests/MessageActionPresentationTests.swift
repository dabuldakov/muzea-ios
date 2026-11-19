import XCTest
@testable import Muzea

/// Подписи и иконки действий: ими пользуются и контекстное меню, и карточка
/// по тапу на сообщение, поэтому все случаи должны быть заполнены.
final class MessageActionPresentationTests: XCTestCase {

    private let allActions: [MessageAction] = [
        .react, .retry, .copy, .reply, .select, .edit, .delete,
        .forward, .pin, .unpin, .report, .block, .status
    ]

    func testEveryActionHasTitleAndIcon() {
        for action in allActions {
            XCTAssertFalse(action.title.isEmpty, "Пустой заголовок у \(action)")
            XCTAssertFalse(action.systemImage.isEmpty, "Пустая иконка у \(action)")
        }
    }

    func testOnlyDeleteAndBlockAreDestructive() {
        XCTAssertEqual(Set(allActions.filter(\.isDestructive)), Set([.delete, .block]))
    }

    func testTitlesAndIconsAreUnique() {
        XCTAssertEqual(Set(allActions.map(\.title)).count, allActions.count)
        XCTAssertEqual(Set(allActions.map(\.systemImage)).count, allActions.count)
    }

    func testGifTabsHaveStableIdentifiersAndTitles() {
        XCTAssertEqual(GifTab.allCases.map(\.id), ["recent", "chat", "search"])
        for tab in GifTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
        }
        XCTAssertEqual(Set(GifTab.allCases.map(\.id)).count, GifTab.allCases.count)
    }
}
