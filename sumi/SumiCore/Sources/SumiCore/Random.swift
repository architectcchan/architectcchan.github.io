import Foundation

/// SplitMix64: small, fast, and identical on every platform and Swift version.
/// We never use `Int.random(in:using:)` for game rolls, because its algorithm is not
/// guaranteed to stay the same across Swift releases. PRD v2 Section 5.3.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// One seed per (install, night): reopening the app can never re-roll a hatch.
    public static func seed(install: UInt64, night: NightKey) -> UInt64 {
        var mixer = SplitMix64(seed: install ^ UInt64(bitPattern: Int64(night.dayNumber)))
        return mixer.next()
    }

    /// An index in 0..<total chosen in proportion to `weights`. Weights must be ≥ 0, total > 0.
    public mutating func weightedIndex(_ weights: [Int]) -> Int {
        let total = weights.reduce(0) { $0 + max(0, $1) }
        precondition(total > 0, "weightedIndex needs a positive total weight")
        var roll = Int(next() % UInt64(total))
        for (index, weight) in weights.enumerated() where weight > 0 {
            if roll < weight { return index }
            roll -= weight
        }
        return weights.count - 1
    }
}
