import XCTest
@testable import RenewedMindKit

final class DataStoreTests: XCTestCase {
    func testFreshStore() {
        let store = DataStore(fileURL: TestSupport.temporaryURL())
        let (data, outcome) = store.load()
        XCTAssertEqual(outcome, .fresh)
        XCTAssertTrue(data.checkIns.isEmpty && data.reframes.isEmpty && data.sessions.isEmpty)
        XCTAssertFalse(data.profile.hasCompletedOnboarding)
    }

    func testRoundTrip() throws {
        let store = DataStore(fileURL: TestSupport.temporaryURL())
        var data = AppData()
        data.profile.name = "Grace"
        data.profile.hasCompletedOnboarding = true
        data.settings.reminderEnabled = true
        data.settings.claudeModel = .opus55
        data.checkIns.append(CheckIn(mood: 4, factors: [.grateful, .prayed], note: "Good day"))
        data.reframes.append(ReframeEntry(thought: "I'm a failure", emotion: "sad", intensityBefore: 80, intensityAfter: 40,
                                          result: ReframeEngine(library: TestSupport.library).reframe("I'm a failure")))
        data.journal.append(JournalEntry(practiceID: "three-good-things", responses: ["Sunrise", "Coffee", "Call with Mom"]))
        data.wellbeing.append(try WHO5Result(answers: [3, 3, 3, 3, 3]))
        data.toggleFavorite("peace-isaiah-26-3")
        data.record(session: PracticeSession(practiceID: "breath-prayer", seconds: 180, feedback: .helped))
        try store.save(data)
        let (loaded, outcome) = store.load()
        XCTAssertEqual(outcome, .loaded)
        XCTAssertEqual(loaded, data, "dates and all fields round-trip exactly")
        XCTAssertEqual(loaded.profile, data.profile)
        XCTAssertEqual(loaded.settings, data.settings)
        XCTAssertEqual(loaded.reframes.first?.intensityChange, 40)
        XCTAssertEqual(loaded.journal, data.journal)
        XCTAssertEqual(loaded.favorites, ["peace-isaiah-26-3"])
        XCTAssertEqual(loaded.practiceStats["breath-prayer"]?.successes, 1)
        XCTAssertEqual(loaded.checkIns.count, 1)
        XCTAssertEqual(loaded.wellbeing.first?.percentScore, 60)
    }

    func testCorruptFileIsRecoveredSafely() throws {
        let url = TestSupport.temporaryURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)
        let (data, outcome) = DataStore(fileURL: url).load()
        XCTAssertTrue(data.checkIns.isEmpty && data.reframes.isEmpty)
        guard case .recoveredFromCorruption(let backup) = outcome else { return XCTFail("expected recovery") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path), "the unreadable file is kept, not deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testTolerantDecodingOfOlderFiles() throws {
        let decoded = try DataStore.makeDecoder().decode(AppData.self, from: Data("{}".utf8))
        XCTAssertEqual(decoded, AppData(profile: decoded.profile))
        let settingsJSON = #"{"settings":{"claudeModel":"claude-retired-1","aiMode":"bogus","reminderHour":99}}"#
        let withSettings = try DataStore.makeDecoder().decode(AppData.self, from: Data(settingsJSON.utf8))
        XCTAssertEqual(withSettings.settings.claudeModel, .default)
        XCTAssertEqual(withSettings.settings.aiMode, .automatic)
        XCTAssertEqual(withSettings.settings.reminderHour, 23, "out-of-range values are clamped")
    }

    func testDeleteAll() throws {
        let url = TestSupport.temporaryURL()
        let store = DataStore(fileURL: url)
        try store.save(AppData())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try store.deleteAll()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNoThrow(try store.deleteAll(), "deleting twice is harmless")
    }

    func testExportIsReadableJSON() throws {
        var data = AppData()
        data.profile.name = "Sam"
        let json = String(decoding: try DataStore.exportJSON(data), as: UTF8.self)
        XCTAssertTrue(json.contains("\"name\" : \"Sam\""))
        XCTAssertTrue(json.contains("\n"))
    }

    func testValueClamping() {
        XCTAssertEqual(CheckIn(mood: 9).mood, 5)
        XCTAssertEqual(CheckIn(mood: -3).mood, 1)
        let entry = ReframeEntry(thought: "x", intensityBefore: 150, intensityAfter: -5,
                                 result: ReframeEngine(library: TestSupport.library).reframe("x"))
        XCTAssertEqual(entry.intensityBefore, 100)
        XCTAssertEqual(entry.intensityAfter, 0)
        XCTAssertEqual(PracticeSession(practiceID: "x", seconds: -10).seconds, 0)
    }

    func testFavoritesToggle() {
        var data = AppData()
        data.toggleFavorite("a")
        XCTAssertTrue(data.isFavorite("a"))
        data.toggleFavorite("a")
        XCTAssertFalse(data.isFavorite("a"))
    }
}
