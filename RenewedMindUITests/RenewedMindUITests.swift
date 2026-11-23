import XCTest

/// End-to-end tests of the real app. Each test captures screenshots as attachments.
final class RenewedMindUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
        app = nil
        super.tearDown()
    }

    // MARK: Helpers

    @discardableResult
    func launch(onboarded: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetData"] + (onboarded ? ["-skipOnboarding"] : [])
        app.launch()
        self.app = app
        return app
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Any element whose accessibility label contains the text (SwiftUI often merges row text into one element).
    func anyElement(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Scrolls the main scroll view until the element is visible and hittable.
    func reveal(_ element: XCUIElement, maxSwipes: Int = 12, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "Couldn't reveal \(element)", file: file, line: line)
    }

    func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing tab \(name)")
        tab.tap()
    }

    func dismissKeyboardIfNeeded() {
        let done = app.toolbars.buttons["Done"]
        if done.exists && done.isHittable {
            done.tap()
        } else if app.keyboards.count > 0 {
            app.swipeDown()
        }
    }

    // MARK: Tests

    func testOnboardingLeadsToToday() {
        launch(onboarded: false)
        let next = element("onboarding.continue")
        XCTAssertTrue(next.waitForExistence(timeout: 15))
        snap("00-Onboarding-Welcome")
        next.tap()
        XCTAssertTrue(element("onboarding.continue").waitForExistence(timeout: 5))
        element("onboarding.continue").tap()
        let name = element("onboarding.name")
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Grace\n")
        snap("00-Onboarding-Safety-Note")
        let begin = element("onboarding.begin")
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        begin.tap()
        let greeting = element("today.greeting")
        XCTAssertTrue(greeting.waitForExistence(timeout: 10))
        XCTAssertTrue(greeting.label.contains("Grace"), greeting.label)
        XCTAssertTrue(element("affirmation.text").exists)
        snap("01-Today")
    }

    func testCheckInUpdatesToday() {
        launch()
        let mood = element("today.mood.4")
        reveal(mood)
        mood.tap()
        let factor = element("checkin.factor.grateful")
        XCTAssertTrue(factor.waitForExistence(timeout: 5))
        factor.tap()
        element("checkin.factor.poorSleep").tap()
        snap("02-CheckIn-Sheet")
        element("checkin.save").tap()
        let summary = element("today.checkInSummary")
        reveal(summary)
        XCTAssertTrue(summary.label.contains("Grateful"), summary.label)
        snap("02-CheckIn-Saved")
        let recommendations = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "today.recommendation."))
        reveal(recommendations.firstMatch)
        XCTAssertGreaterThanOrEqual(recommendations.count, 1)
    }

    func testRenewThoughtProducesReframeAndSaves() {
        launch()
        tapTab("Renew")
        let editor = element("renew.thought")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("I always mess everything up and I'm such a failure.")
        dismissKeyboardIfNeeded()
        snap("03-Renew-Input")
        let submit = element("renew.submit")
        reveal(submit)
        submit.tap()
        let validation = element("result.validation")
        XCTAssertTrue(validation.waitForExistence(timeout: 20))
        XCTAssertFalse(validation.label.isEmpty)
        XCTAssertTrue(element("result.distortion.labeling").exists || element("result.distortion.overgeneralization").exists)
        snap("04-Reframe-Result")
        let balanced = element("result.balanced")
        reveal(balanced)
        snap("05-Reframe-Perspective")
        let fullStudy = app.buttons["Read the full word study"]
        reveal(fullStudy)
        snap("06-Reframe-Scripture")
        let save = element("result.save")
        reveal(save)
        save.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: save)
        wait(for: [gone], timeout: 10)
        // Back on Renew, the saved reflection is listed.
        let recent = anyElement(containing: "I always mess everything up")
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        XCTAssertTrue(element("renew.submit").exists, "returned to the Renew screen")
        snap("07-Renew-History")
    }

    func testCrisisLanguageShowsSafetyResources() {
        launch()
        tapTab("Renew")
        let editor = element("renew.thought")
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        editor.tap()
        editor.typeText("I want to end my life")
        dismissKeyboardIfNeeded()
        let submit = element("renew.submit")
        reveal(submit)
        submit.tap()
        let banner = element("safety.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 20))
        XCTAssertTrue(element("safety.primaryLine").exists, "a crisis line is offered directly")
        snap("08-Safety-Banner")
        element("safety.moreOptions").tap()
        XCTAssertTrue(element("crisis.list").waitForExistence(timeout: 10))
        snap("09-Crisis-Resources")
    }

    func testBreathPrayerSessionAndFeedback() {
        launch()
        tapTab("Practices")
        let row = element("practice.breath-prayer")
        reveal(row)
        row.tap()
        let begin = element("practice.begin")
        reveal(begin)
        snap("10-Practice-Detail")
        begin.tap()
        let toggle = element("breathing.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        toggle.tap()
        let cue = element("breathing.cue")
        XCTAssertTrue(cue.waitForExistence(timeout: 5))
        sleep(2)
        snap("11-Breath-Prayer")
        element("session.finish").tap()
        let helped = element("feedback.helped")
        XCTAssertTrue(helped.waitForExistence(timeout: 10))
        snap("12-Feedback")
        helped.tap()
        XCTAssertTrue(element("practice.begin").waitForExistence(timeout: 10))
    }

    func testGratitudeJournalSaves() {
        launch()
        tapTab("Practices")
        let row = element("practice.three-good-things")
        reveal(row)
        row.tap()
        let begin = element("practice.begin")
        reveal(begin)
        begin.tap()
        let first = element("journal.response.0")
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        first.typeText("Morning coffee with my sister")
        dismissKeyboardIfNeeded()
        snap("13-Three-Good-Things")
        let finish = element("session.finish")
        reveal(finish)
        finish.tap()
        let somewhat = element("feedback.somewhat")
        XCTAssertTrue(somewhat.waitForExistence(timeout: 10))
        somewhat.tap()
        let entry = anyElement(containing: "Morning coffee with my sister")
        reveal(entry)
    }

    func testLibraryWordStudyAndEtymology() {
        launch()
        tapTab("Library")
        let peace = element("library.theme.peace")
        XCTAssertTrue(peace.waitForExistence(timeout: 10))
        snap("14-Library")
        peace.tap()
        let row = element("affirmation.row.peace-isaiah-26-3")
        reveal(row)
        row.tap()
        let strongs = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "H7965")).firstMatch
        reveal(strongs)
        XCTAssertTrue(strongs.exists, "Strong's number is shown")
        snap("15-Word-Study")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let etymologyLink = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Healthy etymology")).firstMatch
        reveal(etymologyLink)
        etymologyLink.tap()
        XCTAssertTrue(element("etymology.health").waitForExistence(timeout: 10))
        snap("16-Etymology")
    }

    func testWHO5ScoresAndSaves() {
        launch()
        tapTab("Insights")
        let take = element("insights.takeWHO5")
        reveal(take)
        snap("17-Insights")
        take.tap()
        for question in 0..<5 {
            let answer = element("who5.q\(question).a3")
            reveal(answer)
            answer.tap()
        }
        let submit = element("who5.submit")
        reveal(submit)
        submit.tap()
        let score = element("who5.score")
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        XCTAssertEqual(score.label, "60 / 100")
        snap("18-WHO5-Result")
        element("who5.done").tap()
        let saved = element("insights.who5Score")
        reveal(saved)
    }

    func testSettingsHelpAndScience() {
        launch()
        let help = element("today.help")
        XCTAssertTrue(help.waitForExistence(timeout: 10))
        help.tap()
        XCTAssertTrue(element("crisis.list").waitForExistence(timeout: 10))
        snap("19-Help")
        app.buttons["Done"].firstMatch.tap()
        let settings = element("today.settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(element("settings.aiMode").waitForExistence(timeout: 10))
        snap("20-Settings")
        let science = element("settings.science")
        reveal(science)
        science.tap()
        XCTAssertTrue(app.navigationBars["The science"].waitForExistence(timeout: 10))
        snap("21-Science")
    }
}
