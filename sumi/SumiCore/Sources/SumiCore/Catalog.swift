import Foundation

public enum Rarity: String, Codable, Hashable, Sendable, CaseIterable {
    case common, uncommon, rare

    public var baseWeight: Int {
        switch self {
        case .common: return 60
        case .uncommon: return 30
        case .rare: return 10
        }
    }
}

public struct Species: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let rarity: Rarity

    public init(id: String, name: String, rarity: Rarity) {
        self.id = id
        self.name = name
        self.rarity = rarity
    }
}

public struct Catalog: Codable, Hashable, Sendable {
    public let species: [Species]
    public static let maxStage = 3

    public init(species: [Species]) { self.species = species }

    public func species(withID id: String) -> Species? { species.first { $0.id == id } }

    /// 12 placeholder species (6 common, 4 uncommon, 2 rare). Names are working titles
    /// until the art direction is decided (PRD v2 Q1, Q2).
    public static let starter = Catalog(species: [
        Species(id: "moonmoth", name: "Moonmoth", rarity: .common),
        Species(id: "pillowpup", name: "Pillowpup", rarity: .common),
        Species(id: "dozefin", name: "Dozefin", rarity: .common),
        Species(id: "lullabud", name: "Lullabud", rarity: .common),
        Species(id: "snugslug", name: "Snugslug", rarity: .common),
        Species(id: "yawnling", name: "Yawnling", rarity: .common),
        Species(id: "starfern", name: "Starfern", rarity: .uncommon),
        Species(id: "mistmouse", name: "Mistmouse", rarity: .uncommon),
        Species(id: "hushowl", name: "Hushowl", rarity: .uncommon),
        Species(id: "cometcub", name: "Cometcub", rarity: .uncommon),
        Species(id: "auroralynx", name: "Auroralynx", rarity: .rare),
        Species(id: "eclipsea", name: "Eclipsea", rarity: .rare),
    ])
}
