import Foundation

/// Onboarding quiz: "What keeps you up?" (multi-select). PRD v2 Section 3.1.
public enum KeepsUpReason: String, Codable, Hashable, Sendable, CaseIterable {
    case scrolling, videos, games, messages, work
}

public struct QuizAnswers: Codable, Hashable, Sendable {
    public var reasons: Set<KeepsUpReason>
    public var usualPhoneDown: ClockTime
    public var bedtime: ClockTime

    public init(reasons: Set<KeepsUpReason>, usualPhoneDown: ClockTime, bedtime: ClockTime) {
        self.reasons = reasons
        self.usualPhoneDown = usualPhoneDown
        self.bedtime = bedtime
    }

    /// How many minutes after the target bedtime the phone usually goes down (0 if not later).
    public var minutesLatePerNight: Int {
        max(0, usualPhoneDown.minutesAfterNoon - bedtime.minutesAfterNoon)
    }

    /// For the onboarding "honest projection" screen. Show the math next to it.
    public var lateMinutesPerWeek: Int { minutesLatePerNight * 7 }
}

/// PRD v2 Section 4.6. Identity, never diagnosis.
public enum Archetype: String, Codable, Hashable, Sendable, CaseIterable {
    case revengeScroller, nightOwl, justOneMore, alwaysOn, almostThere

    public var displayName: String {
        switch self {
        case .revengeScroller: return "The Revenge Scroller"
        case .nightOwl: return "The Night Owl"
        case .justOneMore: return "The Just-One-More"
        case .alwaysOn: return "The Always-On"
        case .almostThere: return "The Almost-There"
        }
    }

    public static func from(_ answers: QuizAnswers) -> Archetype {
        let reasons = answers.reasons
        let scrollsOrWatches = reasons.contains(.scrolling) || reasons.contains(.videos)
        if scrollsOrWatches && answers.minutesLatePerNight >= 60 { return .revengeScroller }

        let oneAM = ClockTime(hour: 1, minute: 0)!
        if answers.bedtime.minutesAfterNoon >= oneAM.minutesAfterNoon { return .nightOwl }

        if reasons.contains(.games) || reasons.contains(.videos) { return .justOneMore }
        if reasons.contains(.messages) || reasons.contains(.work) { return .alwaysOn }
        return .almostThere
    }
}
