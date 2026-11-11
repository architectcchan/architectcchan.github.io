import XCTest
@testable import SumiCore

final class BedtimePlanTests: XCTestCase {
    func testClockTimeRejectsInvalidValues() {
        XCTAssertNil(ClockTime(hour: 24, minute: 0))
        XCTAssertNil(ClockTime(hour: 7, minute: 60))
        XCTAssertNotNil(ClockTime(hour: 0, minute: 0))
    }

    func testMinutesAfterNoonOrdersNightTimes() {
        XCTAssertEqual(clock(22, 0).minutesAfterNoon, 600)
        XCTAssertEqual(clock(0, 30).minutesAfterNoon, 750)
        XCTAssertEqual(clock(2, 0).minutesAfterNoon, 840)
        XCTAssertLessThan(clock(23, 0).minutesAfterNoon, clock(1, 0).minutesAfterNoon)
    }

    func testNightKeyDayMath() {
        XCTAssertEqual(night(2026, 11, 10).adding(days: 1), night(2026, 11, 11))
        XCTAssertEqual(night(2026, 12, 31).adding(days: 1), night(2027, 1, 1))
        XCTAssertEqual(night(2026, 3, 1).adding(days: -1), night(2026, 2, 28))
        XCTAssertEqual(night(1970, 1, 2).dayNumber, 1)
        XCTAssertEqual(night(2026, 11, 10).description, "2026-11-10")
    }

    func testValidity() {
        XCTAssertTrue(hongKongPlan.isValid)
        XCTAssertEqual(hongKongPlan.nominalMinutes, 480)
        let tooShort = BedtimePlan(bedtime: clock(22, 0), wakeTime: clock(23, 0), timeZoneID: "UTC")
        XCTAssertFalse(tooShort.isValid)
        let tooLong = BedtimePlan(bedtime: clock(20, 0), wakeTime: clock(12, 0), timeZoneID: "UTC")
        XCTAssertFalse(tooLong.isValid)
        let badZone = BedtimePlan(bedtime: clock(23, 0), wakeTime: clock(7, 0), timeZoneID: "Mars/Olympus")
        XCTAssertFalse(badZone.isValid)
    }

    func testWindowCrossingMidnight() throws {
        let window = try XCTUnwrap(hongKongPlan.window(for: night(2026, 11, 10)))
        XCTAssertEqual(window.start, instant(2026, 11, 10, 23, 30))
        XCTAssertEqual(window.end, instant(2026, 11, 11, 7, 30))
        XCTAssertEqual(window.duration, 8 * 3600)
    }

    func testAfterMidnightBedtimeBelongsToTheEveningBefore() throws {
        let plan = BedtimePlan(bedtime: clock(1, 0), wakeTime: clock(9, 0), timeZoneID: "Asia/Hong_Kong")
        let window = try XCTUnwrap(plan.window(for: night(2026, 11, 10)))
        XCTAssertEqual(window.start, instant(2026, 11, 11, 1, 0))
        XCTAssertEqual(window.end, instant(2026, 11, 11, 9, 0))
    }

    func testDaylightSavingNightIsAnHourLonger() throws {
        // US clocks fall back on Sunday, Nov 1, 2026.
        let plan = BedtimePlan(bedtime: clock(23, 0), wakeTime: clock(7, 0), timeZoneID: "America/New_York")
        let window = try XCTUnwrap(plan.window(for: night(2026, 10, 31)))
        XCTAssertEqual(window.duration, 9 * 3600)
    }

    func testLatestStartedNight() {
        XCTAssertEqual(hongKongPlan.latestStartedNight(asOf: instant(2026, 11, 11, 3, 0)), night(2026, 11, 10))
        XCTAssertEqual(hongKongPlan.latestStartedNight(asOf: instant(2026, 11, 11, 20, 0)), night(2026, 11, 10))
        XCTAssertEqual(hongKongPlan.latestStartedNight(asOf: instant(2026, 11, 11, 23, 45)), night(2026, 11, 11))

        let lateOwl = BedtimePlan(bedtime: clock(1, 0), wakeTime: clock(9, 0), timeZoneID: "Asia/Hong_Kong")
        XCTAssertEqual(lateOwl.latestStartedNight(asOf: instant(2026, 11, 11, 0, 30)), night(2026, 11, 9))
    }

    func testLatestEndedNightDrivesTheMorningReveal() {
        XCTAssertEqual(hongKongPlan.latestEndedNight(asOf: instant(2026, 11, 11, 8, 0)), night(2026, 11, 10))
        XCTAssertEqual(hongKongPlan.latestEndedNight(asOf: instant(2026, 11, 11, 7, 0)), night(2026, 11, 9))
    }
}
