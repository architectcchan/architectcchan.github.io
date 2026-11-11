import Foundation

/// A wall-clock time of day (no date, no time zone).
public struct ClockTime: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    /// Minutes after 12:00 noon, so evening and after-midnight times sort in night order
    /// (22:00 = 600, 00:30 = 750, 02:00 = 840). Used for "how late" comparisons.
    public var minutesAfterNoon: Int { (minutesSinceMidnight - 720 + 1440) % 1440 }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }
}

/// Identifies a night by its evening date ("the night of Nov 10").
public struct NightKey: Codable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Days since 1970-01-01. Lets us do "previous night" math without time zones.
    public var dayNumber: Int {
        let date = Self.utc.date(from: DateComponents(year: year, month: month, day: day))!
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    public init(dayNumber: Int) {
        let date = Date(timeIntervalSince1970: Double(dayNumber) * 86_400)
        let parts = Self.utc.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public func adding(days: Int) -> NightKey { NightKey(dayNumber: dayNumber + days) }

    public static func < (lhs: NightKey, rhs: NightKey) -> Bool { lhs.dayNumber < rhs.dayNumber }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}
