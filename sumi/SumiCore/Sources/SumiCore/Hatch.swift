import Foundation

/// Owned species and their evolution stage (1...Catalog.maxStage). PRD v2 Section 5.2.
public struct CreatureCollection: Codable, Hashable, Sendable {
    public private(set) var stages: [String: Int]

    public init(stages: [String: Int] = [:]) { self.stages = stages }

    public func stage(of speciesID: String) -> Int { stages[speciesID] ?? 0 }

    public func isMaxed(_ speciesID: String) -> Bool { stage(of: speciesID) >= Catalog.maxStage }

    public func isComplete(_ catalog: Catalog) -> Bool {
        catalog.species.allSatisfy { isMaxed($0.id) }
    }

    /// Total stages earned. A full starter collection is 12 × 3 = 36.
    public var totalStages: Int { stages.values.reduce(0, +) }

    mutating func apply(_ hatch: HatchResult) {
        stages[hatch.species.id] = hatch.stage
    }
}

public struct EggState: Codable, Hashable, Sendable {
    public var warmth: Int
    public var eggNumber: Int

    public static let hatchAt = 4

    public init(warmth: Int = 0, eggNumber: Int = 1) {
        self.warmth = warmth
        self.eggNumber = eggNumber
    }
}

public enum HatchKind: String, Codable, Hashable, Sendable {
    /// A species the user didn't have.
    case new
    /// A duplicate: the owned species moved up one stage.
    case evolved
    /// The whole collection is complete: a cosmetic celebration, nothing changes.
    case sparkle
}

public struct HatchResult: Codable, Hashable, Sendable {
    public let species: Species
    public let kind: HatchKind
    public let stage: Int
}

public enum EggPhase: String, Codable, Hashable, Sendable {
    /// No warmth gained last night. Copy stays kind: "the egg is resting".
    case resting
    case warmer
    case cracked
    case hatched
}

/// Everything the morning screen needs. PRD v2 Section 5.4.
public struct MorningReveal: Codable, Hashable, Sendable {
    public let night: NightKey
    public let outcome: NightOutcome
    public let warmthBefore: Int
    public let warmthAfter: Int
    public let phase: EggPhase
    public let hatch: HatchResult?
    public let glowStreak: Int
    public let nightsTogether: Int
    public let goodNightsThisWeek: Int
}

/// The whole saved game. Plain value type: the app persists it, `SumiCore` only transforms it.
public struct GameState: Codable, Hashable, Sendable {
    public var installSeed: UInt64
    public var egg: EggState
    public var collection: CreatureCollection
    public var history: [NightSummary]
    public var reveals: [MorningReveal]

    public init(installSeed: UInt64) {
        self.installSeed = installSeed
        self.egg = EggState()
        self.collection = CreatureCollection()
        self.history = []
        self.reveals = []
    }

    public func reveal(for night: NightKey) -> MorningReveal? {
        reveals.first { $0.night == night }
    }
}

public enum HatchEngine {
    /// Rarity weights with the capped glow bonus, in `Rarity.allCases` order.
    public static func weights(glowStreak: Int) -> [Rarity: Int] {
        let extraNights = max(0, glowStreak - 1)
        return [
            .common: Rarity.common.baseWeight,
            .uncommon: Rarity.uncommon.baseWeight + min(10, 2 * extraNights),
            .rare: Rarity.rare.baseWeight + min(5, extraNights),
        ]
    }

    /// Roll one hatch. Deterministic for a given generator state.
    public static func roll(
        catalog: Catalog,
        collection: CreatureCollection,
        glowStreak: Int,
        using rng: inout SplitMix64
    ) -> HatchResult {
        rollImpl(catalog: catalog, collection: collection, glowStreak: glowStreak, rng: &rng)
    }

    static func rollImpl(
        catalog: Catalog,
        collection: CreatureCollection,
        glowStreak: Int,
        rng: inout SplitMix64
    ) -> HatchResult {
        precondition(!catalog.species.isEmpty, "Catalog is empty")
        let rarityWeights = Self.weights(glowStreak: glowStreak)

        if collection.isComplete(catalog) {
            let species = pick(from: catalog.species, weights: rarityWeights, rng: &rng)!
            return HatchResult(species: species, kind: .sparkle, stage: Catalog.maxStage)
        }

        var species = pick(from: catalog.species, weights: rarityWeights, rng: &rng)!
        if collection.isMaxed(species.id) {
            let open = catalog.species.filter { !collection.isMaxed($0.id) }
            species = pick(from: open, weights: rarityWeights, rng: &rng)!
        }

        let current = collection.stage(of: species.id)
        return HatchResult(species: species, kind: current == 0 ? .new : .evolved, stage: current + 1)
    }

    /// Pick a rarity (only among rarities present in `pool`), then a species uniformly within it.
    static func pick(from pool: [Species], weights: [Rarity: Int], rng: inout SplitMix64) -> Species? {
        let rarities = Rarity.allCases.filter { rarity in pool.contains { $0.rarity == rarity } }
        guard !rarities.isEmpty else { return nil }
        let rarity = rarities[rng.weightedIndex(rarities.map { weights[$0] ?? 0 })]
        let candidates = pool.filter { $0.rarity == rarity }
        return candidates[Int(rng.next() % UInt64(candidates.count))]
    }

    /// Apply one finished night and produce the morning reveal. Idempotent: advancing a night
    /// that was already advanced returns the stored reveal and leaves the state unchanged.
    public static func advance(
        _ state: GameState,
        night: NightKey,
        outcome: NightOutcome,
        catalog: Catalog = .starter
    ) -> (state: GameState, reveal: MorningReveal) {
        if let existing = state.reveal(for: night) { return (state, existing) }

        var next = state
        next.history.append(NightSummary(night: night, outcome: outcome))
        next.history.sort { $0.night < $1.night }

        let glow = Counters.glowStreak(next.history, through: night)
        let before = next.egg.warmth
        let after = before + outcome.warmth

        var hatch: HatchResult?
        let phase: EggPhase
        if after >= EggState.hatchAt {
            var rng = SplitMix64(seed: SplitMix64.seed(install: state.installSeed, night: night))
            let result = rollImpl(catalog: catalog, collection: next.collection, glowStreak: glow, rng: &rng)
            if result.kind != .sparkle { next.collection.apply(result) }
            hatch = result
            next.egg = EggState(warmth: 0, eggNumber: next.egg.eggNumber + 1)
            phase = .hatched
        } else {
            next.egg.warmth = after
            if outcome.warmth == 0 {
                phase = .resting
            } else if after == 1 {
                phase = .warmer
            } else {
                phase = .cracked
            }
        }

        let reveal = MorningReveal(
            night: night,
            outcome: outcome,
            warmthBefore: before,
            warmthAfter: min(after, EggState.hatchAt),
            phase: phase,
            hatch: hatch,
            glowStreak: glow,
            nightsTogether: Counters.nightsTogether(next.history),
            goodNightsThisWeek: Counters.goodNightsThisWeek(next.history, endingAt: night)
        )
        next.reveals.append(reveal)
        return (next, reveal)
    }
}
