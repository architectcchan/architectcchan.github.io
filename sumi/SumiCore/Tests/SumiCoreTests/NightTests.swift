import XCTest
@testable import SumiCore

final class NightEvaluatorTests: XCTestCase {
    let window = hongKongPlan.window(for: night(2026, 11, 10))!
    let started = NightEvent.lockStarted(at: instant(2026, 11, 10, 23, 30))

    func outcome(_ events: [NightEvent]) -> NightOutcome {
        NightEvaluator.outcome(events: events, window: window)
    }

    func testPausedWinsOverEverything() {
        XCTAssertEqual(outcome([.paused, started, .emergencyUnlock(at: instant(2026, 11, 11, 1, 0))]), .paused)
    }

    func testNoLockMeansNotStarted() {
        XCTAssertEqual(outcome([]), .notStarted)
        XCTAssertEqual(outcome([.receipt(at: instant(2026, 11, 11, 1, 0), minutes: 5)]), .notStarted)
    }

    func testQuietNightIsCalm() {
        XCTAssertEqual(outcome([started, .lockEnded(at: window.end)]), .calm)
    }

    func testEmergencyUnlockIsRestless() {
        XCTAssertEqual(outcome([started, .emergencyUnlock(at: instant(2026, 11, 11, 2, 0))]), .restless)
    }

    func testEmergencyUnlockOutsideTheWindowIsIgnored() {
        XCTAssertEqual(outcome([started, .emergencyUnlock(at: instant(2026, 11, 11, 8, 0))]), .calm)
    }

    func testSmallReceiptsAreMostlyCalm() {
        XCTAssertEqual(outcome([started, .receipt(at: instant(2026, 11, 11, 0, 10), minutes: 10)]), .mostlyCalm)
        XCTAssertEqual(outcome([
            started,
            .receipt(at: instant(2026, 11, 11, 0, 10), minutes: 10),
            .receipt(at: instant(2026, 11, 11, 1, 10), minutes: 5),
        ]), .mostlyCalm, "exactly 15 minutes is still mostly calm")
    }

    func testMoreThanFifteenReceiptMinutesIsRestless() {
        XCTAssertEqual(outcome([
            started,
            .receipt(at: instant(2026, 11, 11, 0, 10), minutes: 10),
            .receipt(at: instant(2026, 11, 11, 1, 10), minutes: 10),
        ]), .restless)
    }

    func testReceiptsOutsideTheWindowAreIgnored() {
        XCTAssertEqual(outcome([started, .receipt(at: instant(2026, 11, 10, 22, 0), minutes: 15)]), .calm)
        XCTAssertEqual(outcome([started, .receipt(at: instant(2026, 11, 11, 7, 30), minutes: 15)]), .calm)
    }

    func testReceiptMinutesAreClippedAtWakeTime() {
        // 15 min asked at 07:25 only costs 5 min before the lock ends.
        XCTAssertEqual(outcome([
            started,
            .receipt(at: instant(2026, 11, 11, 0, 10), minutes: 10),
            .receipt(at: instant(2026, 11, 11, 7, 25), minutes: 15),
        ]), .mostlyCalm)
    }

    func testReceiptCount() {
        let events: [NightEvent] = [
            started,
            .receipt(at: instant(2026, 11, 11, 0, 10), minutes: 5),
            .receipt(at: instant(2026, 11, 11, 1, 10), minutes: 5),
            .receipt(at: instant(2026, 11, 10, 21, 0), minutes: 5),
        ]
        XCTAssertEqual(NightEvaluator.receiptCount(events: events, window: window), 2)
    }

    func testWarmthIsNeverNegative() {
        for outcome in NightOutcome.allCases { XCTAssertGreaterThanOrEqual(outcome.warmth, 0) }
    }
}

final class CountersTests: XCTestCase {
    func history(_ outcomes: [NightOutcome], startingAt first: NightKey = night(2026, 11, 1)) -> [NightSummary] {
        outcomes.enumerated().map { NightSummary(night: first.adding(days: $0.offset), outcome: $0.element) }
    }

    func testNightsTogetherCountsShowingUpOnly() {
        let summaries = history([.calm, .restless, .paused, .notStarted, .mostlyCalm])
        XCTAssertEqual(Counters.nightsTogether(summaries), 3)
    }

    func testGlowStreakSkipsPausedNights() {
        let summaries = history([.calm, .calm, .paused, .mostlyCalm])
        XCTAssertEqual(Counters.glowStreak(summaries, through: night(2026, 11, 4)), 3)
    }

    func testGlowStreakEndsAtARestlessNight() {
        let summaries = history([.calm, .restless, .calm, .calm])
        XCTAssertEqual(Counters.glowStreak(summaries, through: night(2026, 11, 4)), 2)
    }

    func testGlowStreakEndsAtAMissingNight() {
        let summaries = [
            NightSummary(night: night(2026, 11, 1), outcome: .calm),
            NightSummary(night: night(2026, 11, 3), outcome: .calm),
        ]
        XCTAssertEqual(Counters.glowStreak(summaries, through: night(2026, 11, 3)), 1)
    }

    func testGoodNightsThisWeekLooksAtSevenNights() {
        let summaries = history([.calm, .calm, .calm, .restless, .calm, .mostlyCalm, .calm, .calm, .calm])
        // Nights 3...9 → calm, restless, calm, mostlyCalm, calm, calm, calm = 6 good.
        XCTAssertEqual(Counters.goodNightsThisWeek(summaries, endingAt: night(2026, 11, 9)), 6)
    }

    func testPauseLimit() {
        let twoPauses = history([.paused, .calm, .paused, .calm, .calm, .calm])
        XCTAssertFalse(Counters.canPause(night(2026, 11, 7), history: twoPauses))
        XCTAssertTrue(Counters.canPause(night(2026, 11, 8), history: twoPauses), "the first pause has rolled out of the week")
    }
}

final class ArchetypeTests: XCTestCase {
    func testRevengeScroller() {
        let answers = QuizAnswers(reasons: [.scrolling], usualPhoneDown: clock(1, 30), bedtime: clock(23, 30))
        XCTAssertEqual(answers.minutesLatePerNight, 120)
        XCTAssertEqual(answers.lateMinutesPerWeek, 840)
        XCTAssertEqual(Archetype.from(answers), .revengeScroller)
    }

    func testNightOwl() {
        let answers = QuizAnswers(reasons: [.work], usualPhoneDown: clock(1, 30), bedtime: clock(1, 15))
        XCTAssertEqual(Archetype.from(answers), .nightOwl)
    }

    func testJustOneMore() {
        let answers = QuizAnswers(reasons: [.games], usualPhoneDown: clock(23, 45), bedtime: clock(23, 30))
        XCTAssertEqual(Archetype.from(answers), .justOneMore)
    }

    func testAlwaysOn() {
        let answers = QuizAnswers(reasons: [.messages], usualPhoneDown: clock(23, 45), bedtime: clock(23, 30))
        XCTAssertEqual(Archetype.from(answers), .alwaysOn)
    }

    func testFallback() {
        let answers = QuizAnswers(reasons: [], usualPhoneDown: clock(23, 0), bedtime: clock(23, 30))
        XCTAssertEqual(answers.minutesLatePerNight, 0)
        XCTAssertEqual(Archetype.from(answers), .almostThere)
    }
}
