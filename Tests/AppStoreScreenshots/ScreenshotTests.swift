import XCTest

final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureStoreScreenshots() { captureStoreScreenshots(language: "ja") }

    @MainActor
    func testCaptureEnglishStoreScreenshots() { captureStoreScreenshots(language: "en") }

    @MainActor
    private func captureStoreScreenshots(language: String) {
        func label(_ japanese: String, _ english: String) -> String { language == "ja" ? japanese : english }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--app-store-screenshots", "-AppleLanguages", "(\(language))", "-AppleLocale", language == "ja" ? "ja_JP" : "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons[label("スタート", "Start")].waitForExistence(timeout: 20))
        capture("01-home")
        app.buttons[label("メニューを変更", "Change workout")].tap()
        XCTAssertTrue(app.navigationBars[label("メニューを選択", "Choose a workout")].waitForExistence(timeout: 5))
        capture("02-programs")
        app.buttons[label("完了", "Done")].tap()
        app.tabBars.buttons[label("履歴", "History")].tap()
        XCTAssertTrue(app.staticTexts[label("傾斜ウォーキング", "Incline walk")].firstMatch.waitForExistence(timeout: 5))
        capture("04-history")
        app.staticTexts[label("傾斜ウォーキング", "Incline walk")].firstMatch.tap()
        XCTAssertTrue(app.navigationBars[label("傾斜ウォーキング", "Incline walk")].waitForExistence(timeout: 5))
        capture("05-detail")
        app.swipeUp()
        XCTAssertTrue(app.staticTexts[label("速度と傾斜", "Speed & incline")].waitForExistence(timeout: 5))
        capture("07-charts")
        app.tabBars.buttons[label("設定", "Settings")].tap()
        XCTAssertTrue(app.staticTexts[label("プロフィール", "Profile")].waitForExistence(timeout: 5))
        capture("06-settings")
        app.swipeUp()
        app.buttons[label("プライバシーポリシー", "Privacy policy")].tap()
        XCTAssertTrue(app.staticTexts[label("このアプリについて", "About this app")].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons[label("サポート・使い方", "Help & support")].tap()
        XCTAssertTrue(app.staticTexts[label("記録を始める", "Start a workout")].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons[label("ワークアウト", "Workout")].tap()
        app.buttons[label("スタート", "Start")].tap()
        XCTAssertTrue(app.buttons[label("一時停止", "Pause")].waitForExistence(timeout: 10))
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
