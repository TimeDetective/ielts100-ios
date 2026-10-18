import XCTest

final class AppFlowTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }
    func app(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + (reset ? ["--reset-progress"] : [])
        app.launch()
        return app
    }
    func testLessonTranslationAndWordDetails() {
        let app = app()
        XCTAssertTrue(app.buttons["continue-learning"].waitForExistence(timeout: 10))
        app.buttons["continue-learning"].tap()
        let translation = app.buttons["translation-toggle"]
        XCTAssertTrue(translation.waitForExistence(timeout: 5))
        translation.tap()
        XCTAssertTrue(app.staticTexts["translation-text"].exists)
        translation.tap()
        XCTAssertFalse(app.staticTexts["translation-text"].exists)
        for _ in 0..<4 { if app.buttons["word-1-1"].isHittable { break }; app.swipeUp() }
        app.buttons["word-1-1"].tap()
        XCTAssertTrue(app.staticTexts["practice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "英音朗读 practice")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "美音朗读 practice")).firstMatch.exists)
    }
    func testReviewAndProgressSurvivesRelaunch() {
        let app = app()
        app.buttons["复习"].tap()
        app.buttons["review-start"].tap()
        XCTAssertFalse(app.staticTexts["review-meaning"].exists)
        app.buttons["review-reveal"].tap()
        XCTAssertTrue(app.staticTexts["review-meaning"].exists)
        app.buttons["记住了"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.staticTexts["已记住词条"].waitForExistence(timeout: 5))
        // A fresh launch must preserve progress; then exercise search in a separate navigation.
        app.buttons["词库"].tap()
        let search = app.textFields["vocabulary-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("discover")
        XCTAssertTrue(app.buttons["vocab-3-1"].waitForExistence(timeout: 5))
    }
    func testPronunciationButtons() {
        let app = app()
        app.buttons["continue-learning"].tap()
        for label in ["英音朗读", "美音朗读"] {
            let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            button.tap()
            let stop = app.buttons["停止朗读"]
            XCTAssertTrue(stop.waitForExistence(timeout: 10))
            stop.tap()
            XCTAssertFalse(app.alerts["发音提示"].exists)
        }
    }
    func testNonCoreSentenceWordShowsTranslation() {
        let app = app()
        app.buttons["continue-learning"].tap()
        let debate = app.links["every"]
        XCTAssertTrue(debate.waitForExistence(timeout: 5), app.debugDescription)
        debate.tap()
        let meaning = app.staticTexts["lookup-meaning"]
        XCTAssertTrue(meaning.waitForExistence(timeout: 5))
        XCTAssertTrue(meaning.label.contains("每"))
        XCTAssertTrue(app.staticTexts["lookup-context"].label.contains("本句 every 的用法"))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "英音朗读 every")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "美音朗读 every")).firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "every-contextual-translation"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    func testLastLessonSearchExerciseAndFavorite() {
        let app = app()
        let courseSearch = app.textFields["course-search"]
        for _ in 0..<6 { if courseSearch.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(courseSearch.waitForExistence(timeout: 5))
        courseSearch.tap(); courseSearch.typeText("3\n")
        let last = app.buttons["lesson-3"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        if !last.isHittable { app.swipeUp() }
        last.tap()
        XCTAssertTrue(app.staticTexts["保持好奇心"].waitForExistence(timeout: 5))
        app.buttons["收藏本课"].tap()
        XCTAssertTrue(app.buttons["取消收藏本课"].exists)
        for _ in 0..<12 { if app.buttons["cloze-open"].isHittable { break }; app.swipeUp() }
        app.buttons["cloze-open"].tap()
        let answer = app.textFields["cloze-answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 5))
        answer.tap(); answer.typeText("discover")
        app.buttons["cloze-check"].tap()
        XCTAssertTrue(app.staticTexts["答对了！"].waitForExistence(timeout: 5))
    }
    func testListeningControlsAndWordFavorite() {
        let app = app()
        let listen = app.buttons["listening-open"]
        for _ in 0..<4 { if listen.isHittable { break }; app.swipeUp() }
        listen.tap()
        app.buttons["listening-play"].tap()
        XCTAssertTrue(app.buttons["暂停播放"].waitForExistence(timeout: 10))
        app.buttons["暂停播放"].tap()
        XCTAssertTrue(app.buttons["继续播放"].exists)
        app.buttons["停止播放"].tap()
        app.buttons["词库"].tap()
        let search = app.textFields["vocabulary-search"]
        search.tap(); search.typeText("practice\n")
        app.buttons["vocab-1-1"].tap()
        app.buttons["收藏单词"].tap()
        XCTAssertTrue(app.buttons["取消收藏单词"].exists)
    }
    func testClozeAnswer() {
        let app = app()
        app.buttons["continue-learning"].tap()
        for _ in 0..<8 { if app.buttons["cloze-open"].isHittable { break }; app.swipeUp() }
        app.buttons["cloze-open"].tap()
        let field = app.textFields["cloze-answer"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("practice")
        app.buttons["cloze-check"].tap()
        XCTAssertTrue(app.staticTexts["cloze-result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["答对了！"].exists)
    }
}
