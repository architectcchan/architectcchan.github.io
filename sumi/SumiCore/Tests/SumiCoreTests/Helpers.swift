import Foundation
@testable import SumiCore

func clock(_ hour: Int, _ minute: Int) -> ClockTime { ClockTime(hour: hour, minute: minute)! }

func night(_ year: Int, _ month: Int, _ day: Int) -> NightKey { NightKey(year: year, month: month, day: day) }

/// An absolute instant from local wall-clock parts in a time zone.
func instant(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int,
    tz: String = "Asia/Hong_Kong"
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: tz)!
    return calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute))!
}

let hongKongPlan = BedtimePlan(bedtime: clock(23, 30), wakeTime: clock(7, 30), timeZoneID: "Asia/Hong_Kong")
