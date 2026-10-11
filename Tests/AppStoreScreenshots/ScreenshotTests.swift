import XCTest

final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureStoreScreenshots() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--app-store-screenshots", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.buttons["スタート"].waitForExistence(timeout: 20))
        capture("01-home")
        app.buttons["メニューを変更"].tap()
        XCTAssertTrue(app.navigationBars["メニューを選択"].waitForExistence(timeout: 5))
        capture("02-programs")
        app.buttons["完了"].tap()
        app.tabBars.buttons["履歴"].tap()
        XCTAssertTrue(app.staticTexts["傾斜ウォーキング"].firstMatch.waitForExistence(timeout: 5))
        capture("04-history")
        app.staticTexts["傾斜ウォーキング"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["傾斜ウォーキング"].waitForExistence(timeout: 5))
        capture("05-detail")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["速度と傾斜"].waitForExistence(timeout: 5))
        capture("07-charts")
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["プロフィール"].waitForExistence(timeout: 5))
        capture("06-settings")
        app.tabBars.buttons["ワークアウト"].tap()
        app.buttons["スタート"].tap()
        XCTAssertTrue(app.buttons["一時停止"].waitForExistence(timeout: 10))
        capture("03-workout")
        app.terminate()
    }

    @MainActor
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
