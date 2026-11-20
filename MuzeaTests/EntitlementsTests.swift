import XCTest
import UIKit
@testable import Muzea

/// Push не работает, если `aps-environment` пропал из entitlements: профиль
/// может его содержать, но codesign берёт значения из файла проекта.
final class EntitlementsTests: XCTestCase {

    private var root: URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fileManager = FileManager.default
        while url.path != "/",
              !fileManager.fileExists(atPath: url.appendingPathComponent("project.yml").path) {
            url.deleteLastPathComponent()
        }
        return url
    }

    func testPushEntitlementUsesBuildSetting() throws {
        let url = root.appendingPathComponent("Muzea/Resources/Muzea.entitlements")
        let data = try Data(contentsOf: url)
        let object = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try XCTUnwrap(object as? [String: Any], "Не разобрал \(url.path)")

        XCTAssertEqual(
            plist["aps-environment"] as? String,
            "$(APS_ENVIRONMENT)",
            "Нет aps-environment в \(url.path)"
        )
        let domains = plist["com.apple.developer.associated-domains"] as? [String]
        XCTAssertEqual(domains, ["applinks:muzea.su"])
    }

    func testProjectDefinesPushEnvironmentForBothConfigurations() throws {
        let url = root.appendingPathComponent("project.yml")
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(text.contains("APS_ENVIRONMENT: development"))
        XCTAssertTrue(text.contains("APS_ENVIRONMENT: production"))
    }
}

/// Поле ввода должно быть компактным в одну строку и расти до лимита,
/// а не занимать maxHeight сразу.
@MainActor
final class ComposerSizingTests: XCTestCase {

    func testSingleLineUsesMinimumHeight() {
        let view = AutoGrowingTextView(frame: CGRect(x: 0, y: 0, width: 220, height: 36))
        view.font = .preferredFont(forTextStyle: .body)
        view.textContainerInset = UIEdgeInsets(top: 5, left: 4, bottom: 5, right: 4)
        view.isScrollEnabled = false
        view.text = "привет"
        view.layoutIfNeeded()

        XCTAssertEqual(view.intrinsicContentSize.height, 36, accuracy: 1)
    }

    func testLongTextGrowsButDoesNotExceedLimit() {
        let view = AutoGrowingTextView(frame: CGRect(x: 0, y: 0, width: 220, height: 36))
        view.font = .preferredFont(forTextStyle: .body)
        view.textContainerInset = UIEdgeInsets(top: 5, left: 4, bottom: 5, right: 4)
        view.isScrollEnabled = false
        view.text = Array(repeating: "строка", count: 20).joined(separator: "\n")
        view.layoutIfNeeded()

        XCTAssertGreaterThan(view.intrinsicContentSize.height, 36)
        XCTAssertLessThanOrEqual(view.intrinsicContentSize.height, 140)
    }
}
