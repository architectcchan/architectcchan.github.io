import XCTest
@testable import SumiCore

final class RandomTests: XCTestCase {
    func testSplitMix64ReferenceValue() {
        // Reference output of SplitMix64 for seed 0 (Vigna's reference implementation).
        var rng = SplitMix64(seed: 0)
        XCTAssertEqual(rng.next(), 0xE220_A839_7B1D_CDAF)
    }

    func testSameSeedSameSequence() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)
        for _ in 0..<100 { XCTAssertEqual(a.next(), b.next()) }
    }

    func testSeedDependsOnInstallAndNight() {
        let base = SplitMix64.seed(install: 7, night: night(2026, 11, 10))
        XCTAssertEqual(base, SplitMix64.seed(install: 7, night: night(2026, 11, 10)))
        XCTAssertNotEqual(base, SplitMix64.seed(install: 8, night: night(2026, 11, 10)))
        XCTAssertNotEqual(base, SplitMix64.seed(install: 7, night: night(2026, 11, 11)))
    }

    func testWeightedIndexSkipsZeroWeights() {
        var rng = SplitMix64(seed: 1)
        for _ in 0..<200 { XCTAssertEqual(rng.weightedIndex([0, 5, 0]), 1) }
    }
}

final class HatchEngineTests: XCTestCase {
    let catalog = Catalog.starter

    func testStarterCatalogShape() {
        XCTAssertEqual(catalog.species.count, 12)
        XCTAssertEqual(catalog.species.filter { $0.rarity == .common }.count, 6)
        XCTAssertEqual(catalog.species.filter { $0.rarity == .uncommon }.count, 4)
        XCTAssertEqual(catalog.species.filter { $0.rarity == .rare }.count, 2)
        XCTAssertEqual(Set(catalog.species.map(\.id)).count, 12, "ids are unique")
    }

    func testGlowBonusIsCapped() {
        XCTAssertEqual(HatchEngine.weights(glowStreak: 0), [.common: 60, .uncommon: 30, .rare: 10])
        XCTAssertEqual(HatchEngine.weights(glowStreak: 1), [.common: 60, .uncommon: 30, .rare: 10])
        XCTAssertEqual(HatchEngine.weights(glowStreak: 3), [.common: 60, .uncommon: 34, .rare: 12])
        XCTAssertEqual(HatchEngine.weights(glowStreak: 100), [.common: 60, .uncommon: 40, .rare: 15])
    }

    func testRollIsDeterministic() {
        var a = SplitMix64(seed: 99)
        var b = SplitMix64(seed: 99)
        let first = HatchEngine.roll(catalog: catalog, collection: .init(), glowStreak: 2, using: &a)
        let second = HatchEngine.roll(catalog: catalog, collection: .init(), glowStreak: 2, using: &b)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.kind, .new)
        XCTAssertEqual(first.stage, 1)
    }

    func testDuplicateEvolves() {
        let onlyOne = Catalog(species: [Species(id: "a", name: "A", rarity: .common)])
        var rng = SplitMix64(seed: 3)
        let result = HatchEngine.roll(
            catalog: onlyOne, collection: CreatureCollection(stages: ["a": 1]), glowStreak: 0, using: &rng)
        XCTAssertEqual(result.kind, .evolved)
        XCTAssertEqual(result.stage, 2)
    }

    func testMaxedSpeciesIsRerolledToAnOpenOne() {
        let two = Catalog(species: [
            Species(id: "a", name: "A", rarity: .common),
            Species(id: "b", name: "B", rarity: .common),
        ])
        let collection = CreatureCollection(stages: ["a": Catalog.maxStage])
        for seed: UInt64 in 0..<50 {
            var rng = SplitMix64(seed: seed)
            let result = HatchEngine.roll(catalog: two, collection: collection, glowStreak: 0, using: &rng)
            XCTAssertEqual(result.species.id, "b")
        }
    }

    func testCompleteCollectionGivesSparkles() {
        var stages: [String: Int] = [:]
        for species in catalog.species { stages[species.id] = Catalog.maxStage }
        var rng = SplitMix64(seed: 5)
        let result = HatchEngine.roll(
            catalog: catalog, collection: CreatureCollection(stages: stages), glowStreak: 0, using: &rng)
        XCTAssertEqual(result.kind, .sparkle)
    }

    func testTwoCalmNightsHatchAnEgg() throws {
        var state = GameState(installSeed: 2026)
        let first = HatchEngine.advance(state, night: night(2026, 11, 10), outcome: .calm)
        state = first.state
        XCTAssertEqual(first.reveal.phase, .cracked)
        XCTAssertNil(first.reveal.hatch)
        XCTAssertEqual(state.egg.warmth, 2)

        let second = HatchEngine.advance(state, night: night(2026, 11, 11), outcome: .calm)
        state = second.state
        XCTAssertEqual(second.reveal.phase, .hatched)
        let hatch = try XCTUnwrap(second.reveal.hatch)
        XCTAssertEqual(hatch.kind, .new)
        XCTAssertEqual(state.collection.stage(of: hatch.species.id), 1)
        XCTAssertEqual(state.egg, EggState(warmth: 0, eggNumber: 2))
        XCTAssertEqual(second.reveal.glowStreak, 2)
        XCTAssertEqual(second.reveal.nightsTogether, 2)
    }

    func testMostlyCalmNightWarmsByOne() {
        let result = HatchEngine.advance(GameState(installSeed: 1), night: night(2026, 11, 10), outcome: .mostlyCalm)
        XCTAssertEqual(result.reveal.phase, .warmer)
        XCTAssertEqual(result.state.egg.warmth, 1)
    }

    func testRestlessNightNeverTakesAnythingAway() {
        var state = GameState(installSeed: 1)
        state = HatchEngine.advance(state, night: night(2026, 11, 10), outcome: .calm).state
        let result = HatchEngine.advance(state, night: night(2026, 11, 11), outcome: .restless)
        XCTAssertEqual(result.reveal.phase, .resting)
        XCTAssertEqual(result.state.egg.warmth, 2)
        XCTAssertEqual(result.state.collection, state.collection)
    }

    func testAdvanceIsIdempotent() {
        let once = HatchEngine.advance(GameState(installSeed: 9), night: night(2026, 11, 10), outcome: .calm)
        let twice = HatchEngine.advance(once.state, night: night(2026, 11, 10), outcome: .calm)
        XCTAssertEqual(once.state, twice.state)
        XCTAssertEqual(once.reveal, twice.reveal)
    }

    func testSameInstallAndNightAlwaysHatchTheSameCreature() {
        func hatchOnSecondNight(seed: UInt64) -> HatchResult? {
            var state = GameState(installSeed: seed)
            state = HatchEngine.advance(state, night: night(2026, 11, 10), outcome: .calm).state
            return HatchEngine.advance(state, night: night(2026, 11, 11), outcome: .calm).reveal.hatch
        }
        XCTAssertEqual(hatchOnSecondNight(seed: 123), hatchOnSecondNight(seed: 123))
    }

    func testFullCollectionTakes36HatchesAnd72CalmNights() {
        var state = GameState(installSeed: 77)
        var current = night(2026, 11, 1)
        var nights = 0
        while !state.collection.isComplete(catalog) && nights < 500 {
            state = HatchEngine.advance(state, night: current, outcome: .calm).state
            current = current.adding(days: 1)
            nights += 1
        }
        XCTAssertTrue(state.collection.isComplete(catalog))
        XCTAssertEqual(state.collection.totalStages, 36)
        XCTAssertEqual(nights, 72)
        XCTAssertEqual(state.egg.eggNumber, 37)
    }

    func testGameStateRoundTripsThroughJSON() throws {
        var state = GameState(installSeed: 4)
        state = HatchEngine.advance(state, night: night(2026, 11, 10), outcome: .calm).state
        state = HatchEngine.advance(state, night: night(2026, 11, 11), outcome: .calm).state
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)
    }
}
