import Foundation

/// Something that happened during a night, logged by the app or the Screen Time extensions.
/// PRD v2 Section 4.2.
public enum NightEvent: Codable, Hashable, Sendable {
    case lockStarted(at: Date)
    case receipt(at: Date, minutes: Int)
    case emergencyUnlock(at: Date)
    case lockEnded(at: Date)
    case paused
}

/// PRD v2 Section 4.3.
public enum NightOutcome: String, Codable, Hashable, Sendable, CaseIterable {
    case paused
    case notStarted
    case restless
    case mostlyCalm
    case calm

    /// Warmth the egg gains. Never negative: nothing is ever lost.
    public var warmth: Int {
        switch self {
        case .calm: return 2
        case .mostlyCalm: return 1
        case .paused, .notStarted, .restless: return 0
        }
    }

    /// A "good night": the phone (mostly) stayed down.
    public var isGood: Bool { self == .calm || self == .mostlyCalm }

    /// The lock ran this night, whatever happened. Counts toward "nights together".
    public var showedUp: Bool { isGood || self == .restless }
}

/// Tunable thresholds (remote-flag friendly).
public struct NightRules: Codable, Hashable, Sendable {
    public var mostlyCalmMaxMinutes: Int
    public var maxReceiptsPerNight: Int
    public var maxPausesPerWeek: Int

    public init(mostlyCalmMaxMinutes: Int = 15, maxReceiptsPerNight: Int = 3, maxPausesPerWeek: Int = 2) {
        self.mostlyCalmMaxMinutes = mostlyCalmMaxMinutes
        self.maxReceiptsPerNight = maxReceiptsPerNight
        self.maxPausesPerWeek = maxPausesPerWeek
    }

    public static let standard = NightRules()
}

public enum NightEvaluator {
    /// Rules N0 to N5, first match wins.
    public static func outcome(
        events: [NightEvent], window: DateInterval, rules: NightRules = .standard
    ) -> NightOutcome {
        if events.contains(.paused) { return .paused }

        let started = events.contains { event in
            if case .lockStarted = event { return true }
            return false
        }
        guard started else { return .notStarted }

        var receiptMinutes = 0
        for event in events {
            switch event {
            case .emergencyUnlock(let at):
                if at >= window.start && at < window.end { return .restless }
            case .receipt(let at, let minutes):
                guard at >= window.start, at < window.end else { continue }
                let minutesLeft = Int(window.end.timeIntervalSince(at) / 60)
                receiptMinutes += max(0, min(minutes, minutesLeft))
            case .lockStarted, .lockEnded, .paused:
                continue
            }
        }

        if receiptMinutes > rules.mostlyCalmMaxMinutes { return .restless }
        if receiptMinutes > 0 { return .mostlyCalm }
        return .calm
    }

    /// Receipts already signed inside the window. The UI uses this to enforce the per-night cap.
    public static func receiptCount(events: [NightEvent], window: DateInterval) -> Int {
        events.reduce(0) { count, event in
            if case .receipt(let at, _) = event, at >= window.start, at < window.end {
                return count + 1
            }
            return count
        }
    }
}

public struct NightSummary: Codable, Hashable, Sendable {
    public let night: NightKey
    public let outcome: NightOutcome

    public init(night: NightKey, outcome: NightOutcome) {
        self.night = night
        self.outcome = outcome
    }
}

/// PRD v2 Section 4.4 and 4.5. All counters are positive-only.
public enum Counters {
    public static func nightsTogether(_ history: [NightSummary]) -> Int {
        history.filter { $0.outcome.showedUp }.count
    }

    /// Good nights among the 7 nights ending at `night` (inclusive).
    public static func goodNightsThisWeek(_ history: [NightSummary], endingAt night: NightKey) -> Int {
        let range = (night.dayNumber - 6)...night.dayNumber
        return history.filter { range.contains($0.night.dayNumber) && $0.outcome.isGood }.count
    }

    /// Consecutive good nights ending at `night`. Paused nights are skipped, not breaks.
    /// A restless, not-started, or missing night ends the streak.
    public static func glowStreak(_ history: [NightSummary], through night: NightKey) -> Int {
        var byDay: [Int: NightOutcome] = [:]
        for summary in history { byDay[summary.night.dayNumber] = summary.outcome }

        var streak = 0
        var day = night.dayNumber
        let earliest = history.map(\.night.dayNumber).min() ?? day
        while day >= earliest {
            switch byDay[day] {
            case .calm?, .mostlyCalm?: streak += 1
            case .paused?: break
            default: return streak
            }
            day -= 1
        }
        return streak
    }

    /// The user may pause `night` if fewer than `maxPausesPerWeek` of the 6 nights before it were paused.
    public static func canPause(
        _ night: NightKey, history: [NightSummary], rules: NightRules = .standard
    ) -> Bool {
        let range = (night.dayNumber - 6)...(night.dayNumber - 1)
        let recentPauses = history.filter {
            range.contains($0.night.dayNumber) && $0.outcome == .paused
        }.count
        return recentPauses < rules.maxPausesPerWeek
    }
}
