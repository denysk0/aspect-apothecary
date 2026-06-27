import Foundation

enum UpgradeKind: String, CaseIterable, Identifiable {
    case counter
    case patience
    case negotiator
    case apprentice

    var id: String { rawValue }
}

struct Upgrade: Identifiable {
    let kind: UpgradeKind
    let name: String
    let blurb: String
    let icon: String
    let maxLevel: Int
    let basePrice: Int
    let priceGrowth: Double

    var id: String { kind.rawValue }

    func price(currentLevel: Int) -> Int? {
        guard currentLevel < maxLevel else { return nil }
        return Int((Double(basePrice) * pow(priceGrowth, Double(currentLevel))).rounded())
    }
}

enum UpgradeCatalog {
    static let all: [Upgrade] = [
        Upgrade(
            kind: .counter,
            name: "Extra Counter",
            blurb: "Serve one more customer each day.",
            icon: "person.2.fill",
            maxLevel: 3,
            basePrice: 60,
            priceGrowth: 1.8
        ),
        Upgrade(
            kind: .patience,
            name: "Welcoming Parlor",
            blurb: "Customers answer one more question before they lose patience.",
            icon: "cup.and.saucer.fill",
            maxLevel: 3,
            basePrice: 45,
            priceGrowth: 1.7
        ),
        Upgrade(
            kind: .negotiator,
            name: "Silver Tongue",
            blurb: "Earn bigger tips for high-quality work.",
            icon: "hands.and.sparkles.fill",
            maxLevel: 3,
            basePrice: 50,
            priceGrowth: 1.7
        ),
        Upgrade(
            kind: .apprentice,
            name: "Hire an Apprentice",
            blurb: "Unlock an apprentice who can solve an order on its own.",
            icon: "person.fill.badge.plus",
            maxLevel: 1,
            basePrice: 80,
            priceGrowth: 1
        )
    ]

    static func upgrade(_ kind: UpgradeKind) -> Upgrade {
        all.first { $0.kind == kind } ?? all[0]
    }

    static let baseOrderSlots = 3
    static let basePatience = 3

    private static func level(_ kind: UpgradeKind, in levels: [String: Int]) -> Int {
        levels[kind.rawValue] ?? 0
    }

    static func orderSlots(levels: [String: Int]) -> Int {
        baseOrderSlots + level(.counter, in: levels)
    }

    static func patience(levels: [String: Int]) -> Int {
        basePatience + level(.patience, in: levels)
    }

    static func tipMultiplier(levels: [String: Int]) -> Double {
        1.0 + 0.25 * Double(level(.negotiator, in: levels))
    }

    static func apprenticeUnlocked(levels: [String: Int]) -> Bool {
        level(.apprentice, in: levels) >= 1
    }
}

enum Economy {
    static func rent(forDay day: Int) -> Int {
        20 + max(0, day - 1) * 8
    }

    static func tip(base: Int, quality: Double, multiplier: Double) -> Int {
        guard quality >= 0.5 else { return 0 }
        let factor = (quality - 0.5) / 0.5
        return Int((Double(base) * 0.5 * factor * multiplier).rounded())
    }
}
