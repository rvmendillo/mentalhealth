import XCTest
@testable import RenewedMindKit

final class ReminderPlannerTests: XCTestCase {
    let library = TestSupport.library
    let cal = TestSupport.calendar()

    func testPlansAWeekStartingTodayWhenTimeIsAhead() {
        let now = TestSupport.date(2026, 11, 20, 6, 30, calendar: cal)
        let plan = ReminderPlanner.plan(from: now, days: 7, hour: 8, minute: 15, calendar: cal, library: library)
        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.dateComponents.day, 20)
        XCTAssertEqual(plan.first?.dateComponents.hour, 8)
        XCTAssertEqual(plan.first?.dateComponents.minute, 15)
        XCTAssertEqual(plan.first?.id, "daily-affirmation-2026-11-20")
        XCTAssertEqual(Set(plan.map(\.id)).count, 7)
        for reminder in plan {
            let a = library.affirmation(id: reminder.affirmationID)!
            XCTAssertTrue(reminder.body.contains(a.affirmation))
            XCTAssertTrue(reminder.body.contains(a.reference))
        }
    }

    func testStartsTomorrowWhenTimeHasPassed() {
        let now = TestSupport.date(2026, 11, 20, 21, 0, calendar: cal)
        let plan = ReminderPlanner.plan(from: now, days: 3, hour: 8, minute: 0, calendar: cal, library: library)
        XCTAssertEqual(plan.map { $0.dateComponents.day }, [21, 22, 23])
        XCTAssertTrue(ReminderPlanner.plan(from: now, days: 0, hour: 8, minute: 0, calendar: cal, library: library).isEmpty)
    }

    func testReminderMatchesDailyAffirmation() {
        let now = TestSupport.date(2026, 11, 20, 6, 0, calendar: cal)
        let plan = ReminderPlanner.plan(from: now, days: 1, hour: 9, minute: 0, calendar: cal, library: library)
        XCTAssertEqual(plan.first?.affirmationID, library.dailyAffirmation(for: now, calendar: cal).id)
    }
}

final class CrisisDirectoryTests: XCTestCase {
    func testRegions() {
        let us = CrisisDirectory.region(for: "us")
        XCTAssertEqual(us.code, "US")
        XCTAssertEqual(us.emergencyNumber, "911")
        XCTAssertEqual(us.lines.first?.phone, "988")
        XCTAssertEqual(CrisisDirectory.region(for: "GB").lines.first?.phone, "116123")
        XCTAssertEqual(CrisisDirectory.region(for: "PH").lines.first?.phone, "1553")
        XCTAssertEqual(CrisisDirectory.region(for: "ZZ").code, "INTL")
        XCTAssertEqual(CrisisDirectory.region(for: nil).code, "INTL")
    }

    func testEveryLineIsReachable() {
        for region in CrisisDirectory.regions + [CrisisDirectory.international] {
            XCTAssertNotNil(region.emergencyURL)
            XCTAssertFalse(region.lines.isEmpty)
            for line in region.lines {
                XCTAssertTrue(line.phoneURL != nil || line.smsURL != nil || line.websiteURL != nil, line.id)
                if let phone = line.phone { XCTAssertNotNil(phone.range(of: #"^\d+$"#, options: .regularExpression), line.id) }
            }
        }
    }

    func testTextLineURL() {
        let ctl = CrisisDirectory.region(for: "US").lines.first { $0.id == "us-ctl" }!
        XCTAssertEqual(ctl.smsURL?.absoluteString, "sms:741741&body=HOME")
        XCTAssertEqual(CrisisDirectory.region(for: "US").lines[0].phoneURL?.absoluteString, "tel:988")
    }
}
