import Foundation

/// The user's nightly lock window: from `bedtime` to the next `wakeTime`, in `timeZoneID`.
/// PRD v2 Section 4.1.
public struct BedtimePlan: Codable, Hashable, Sendable {
    public let bedtime: ClockTime
    public let wakeTime: ClockTime
    public let timeZoneID: String

    public static let minimumMinutes = 3 * 60
    public static let maximumMinutes = 14 * 60

    public init(bedtime: ClockTime, wakeTime: ClockTime, timeZoneID: String) {
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.timeZoneID = timeZoneID
    }

    /// Length of the window on a normal (non-DST) night.
    public var nominalMinutes: Int {
        let difference = wakeTime.minutesSinceMidnight - bedtime.minutesSinceMidnight
        return difference > 0 ? difference : difference + 1440
    }

    public var isValid: Bool {
        TimeZone(identifier: timeZoneID) != nil
            && (Self.minimumMinutes...Self.maximumMinutes).contains(nominalMinutes)
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return calendar
    }

    /// The absolute lock window for a night. A bedtime before 12:00 belongs to the
    /// evening before (night of Nov 10 with a 01:00 bedtime starts Nov 11 at 01:00).
    public func window(for night: NightKey) -> DateInterval? {
        let calendar = self.calendar
        guard let evening = calendar.date(from: DateComponents(
            year: night.year, month: night.month, day: night.day, hour: 12))
        else { return nil }

        let startDayOffset = bedtime.hour >= 12 ? 0 : 1
        guard
            let startDay = calendar.date(byAdding: .day, value: startDayOffset, to: evening),
            let start = calendar.date(
                bySettingHour: bedtime.hour, minute: bedtime.minute, second: 0, of: startDay),
            var end = calendar.date(
                bySettingHour: wakeTime.hour, minute: wakeTime.minute, second: 0, of: startDay)
        else { return nil }

        if end <= start {
            guard
                let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay),
                let nextEnd = calendar.date(
                    bySettingHour: wakeTime.hour, minute: wakeTime.minute, second: 0, of: nextDay)
            else { return nil }
            end = nextEnd
        }
        return DateInterval(start: start, end: end)
    }

    /// The latest night whose lock has started at or before `date`.
    public func latestStartedNight(asOf date: Date) -> NightKey? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        let today = NightKey(year: year, month: month, day: day)
        for offset in 0...2 {
            let night = today.adding(days: -offset)
            if let window = window(for: night), window.start <= date { return night }
        }
        return nil
    }

    /// The latest night whose lock has ended at or before `date`: the one the morning reveal shows.
    public func latestEndedNight(asOf date: Date) -> NightKey? {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        let today = NightKey(year: year, month: month, day: day)
        for offset in 0...2 {
            let night = today.adding(days: -offset)
            if let window = window(for: night), window.end <= date { return night }
        }
        return nil
    }
}
