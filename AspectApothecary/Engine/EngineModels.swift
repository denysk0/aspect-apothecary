import Foundation

struct Aspect: Hashable, Identifiable {
    let id: String
    let name: String
    let keyword: String
    let emoji: String
    let parents: [String]
    let colorHex: String
}

enum PotionType: String, CaseIterable, Codable, Identifiable {
    case preservation
    case stealth
    case light
    case numbing
    case savor
    case strength
    case warding
    case silence
    case charm
    case healing
    case clarity
    case combat
    case fortune
    case flight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preservation: "Preservation"
        case .stealth: "Stealth"
        case .light: "Light"
        case .numbing: "Numbing"
        case .savor: "Savor"
        case .strength: "Strength"
        case .warding: "Warding"
        case .silence: "Silence"
        case .charm: "Charm"
        case .healing: "Healing"
        case .clarity: "Clarity"
        case .combat: "Killing Edge"
        case .fortune: "Fortune"
        case .flight: "Flight"
        }
    }

    var icon: String {
        switch self {
        case .preservation: "shippingbox.fill"
        case .stealth: "eye.slash.fill"
        case .light: "lightbulb.fill"
        case .numbing: "snowflake"
        case .savor: "leaf.fill"
        case .strength: "bolt.fill"
        case .warding: "shield.fill"
        case .silence: "speaker.slash.fill"
        case .charm: "heart.fill"
        case .healing: "cross.case.fill"
        case .clarity: "brain.head.profile"
        case .combat: "flame.fill"
        case .fortune: "dollarsign.circle.fill"
        case .flight: "wind"
        }
    }

    var vagueRequest: String {
        switch self {
        case .preservation: "My cargo keeps turning to rot long before it ever reaches the buyer."
        case .stealth: "Lately, on every job, the wrong eyes seem to find me in the dark."
        case .light: "Where I work it's black as pitch, and I keep missing what's right in front of me."
        case .numbing: "Before a hard night my nerves get the better of me and my hands won't hold steady."
        case .savor: "My stall's wares have lost their pull, folk just walk right past now."
        case .strength: "I'm not the arm I once was, and the heavy work is starting to show it."
        case .warding: "Blows and prying eyes find me far too easily these days."
        case .silence: "Every footstep I take rings out like a temple bell at the worst moment."
        case .charm: "However I try, I can't seem to win a single soul over lately."
        case .healing: "I took a bad knock on the job and I'm just not mending the way I should."
        case .clarity: "My thoughts turn to fog exactly when I need them sharpest."
        case .combat: "When it comes down to a real fight, I keep coming up short."
        case .fortune: "Luck's been against me at every turn, and my purse is the proof."
        case .flight: "I need to reach a place no ladder, rope, or stair will ever take me."
        }
    }

    var effectSummary: String {
        switch self {
        case .preservation: "keeps goods and bodies from spoiling"
        case .stealth: "lets the drinker slip through shadows unseen"
        case .light: "gives off a steady, reliable light"
        case .numbing: "numbs pain and fear"
        case .savor: "fills the air with an irresistible scent"
        case .strength: "makes the drinker physically stronger"
        case .warding: "turns aside prying eyes and blows"
        case .silence: "lets the drinker move in utter silence"
        case .charm: "charms and sways whoever is nearby"
        case .healing: "knits wounds and restores vigor"
        case .clarity: "sharpens the mind to crystal clarity"
        case .combat: "makes a warrior deadly in a fight"
        case .fortune: "draws fortune and profit to the drinker"
        case .flight: "grants the drinker flight"
        }
    }
}

struct PotionCatalogEntry: Identifiable {
    let type: PotionType
    let guild: Guild
    let tier: Int
    let basePriceSkint: Int
    let targetAspectID: String
    let effectDescription: String

    var id: PotionType { type }
}

enum Guild: String, CaseIterable, Codable, Identifiable {
    case smugglers
    case thieves
    case mercenaries
    case spiceMerchants
    case mages

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smugglers: "Smugglers"
        case .thieves: "Thieves"
        case .mercenaries: "Mercenaries"
        case .spiceMerchants: "Spice Merchants"
        case .mages: "Mages"
        }
    }

    var icon: String {
        switch self {
        case .smugglers: "shippingbox.fill"
        case .thieves: "theatermasks.fill"
        case .mercenaries: "shield.lefthalf.filled"
        case .spiceMerchants: "bag.fill"
        case .mages: "wand.and.stars"
        }
    }
}

enum ReputationStage: Int, Codable, CaseIterable {
    case hatred
    case indifference
    case friendliness
    case trust

    var displayName: String {
        switch self {
        case .hatred: "Hatred"
        case .indifference: "Indifference"
        case .friendliness: "Friendliness"
        case .trust: "Trust"
        }
    }
}

struct PuzzleEndpoint: Hashable {
    let hex: Hex
    let aspect: String
}

struct ApprenticeMove {
    let hex: Hex
    let aspectID: String
    let linkNames: [String]
}

struct PuzzleTarget: Identifiable {
    let id = UUID()
    let potionType: PotionType
    let boardRadius: Int
    let cells: [Hex]
    let targetHex: Hex
    let targetAspect: String
    let anchors: [PuzzleEndpoint]
    let idealPaths: [[String]]
    let forbiddenAspects: [String]
    let blockedHexes: Set<Hex>

    var depth: Int { max(1, (idealPaths.map(\.count).max() ?? 1) - 1) }

    var idealPlacements: Int {
        idealPaths.reduce(0) { $0 + max(0, $1.count - 2) }
    }

    var lockedHexes: Set<Hex> {
        Set(anchors.map(\.hex)).union([targetHex])
    }

    var requiredAspects: [String] { [targetAspect] + anchors.map(\.aspect) }
}

struct OrderFact: Identifiable, Equatable {
    let id: String
    let note: String
    let hint: String
    let kind: FactKind
}

enum FactKind: Equatable {
    case requiresAspect(String)
    case forbidsAspect(String)

    var questionKeywords: [String] {
        switch self {
        case .requiresAspect:
            ["need", "want", "exactly", "do", "effect", "problem", "fix", "help", "potion", "for", "matters"]
        case .forbidsAspect:
            ["avoid", "side", "unaccept", "danger", "without", "not", "wrong", "harm", "risk"]
        }
    }
}

extension [OrderFact] {
    func unlocked(by question: String, alreadySaid previousReplies: [String], alreadyRevealed: Set<String> = []) -> OrderFact? {
        let lowered = question.lowercased()
        let forbids = filter { if case .forbidsAspect = $0.kind { return true } else { return false } }
        let requires = filter { if case .requiresAspect = $0.kind { return true } else { return false } }
        let mentionsForbid = FactKind.forbidsAspect("").questionKeywords.contains { lowered.contains($0) }
        let mentionsRequire = FactKind.requiresAspect("").questionKeywords.contains { lowered.contains($0) }

        let directHit = first { fact in
            let key = fact.keyword
            return !key.isEmpty && key.count > 2 && lowered.contains(key)
        }

        var ordered: [OrderFact] = []
        if mentionsForbid { ordered += forbids }
        if mentionsRequire { ordered += requires }

        let alreadyTold = filter { fact in
            previousReplies.contains { $0.localizedCaseInsensitiveContains(fact.note) }
        }.map(\.id)

        if let directHit, !alreadyRevealed.contains(directHit.id), !alreadyTold.contains(directHit.id) {
            return directHit
        }
        guard mentionsForbid || mentionsRequire else { return nil }
        return ordered.first { !alreadyTold.contains($0.id) && !alreadyRevealed.contains($0.id) }
    }
}

extension OrderFact {
    var keyword: String {
        switch kind {
        case .forbidsAspect:
            note.replacingOccurrences(of: "Must not involve ", with: "").lowercased()
        case .requiresAspect:
            note.replacingOccurrences(of: "Wants a ", with: "")
                .replacingOccurrences(of: " potion", with: "")
                .lowercased()
        }
    }
}

struct HiddenOrderSpec {
    let potionType: PotionType
    let targetAspect: String
    let forbiddenAspects: [String]
    let facts: [OrderFact]
}

struct CraftResult {
    let isValid: Bool
    let quality: Double
    let message: String
}

struct InventoryAspect: Identifiable {
    let id: String
    var quantity: Int
}

struct CauldronItem: Identifiable {
    let id: String
    let name: String
    let blurb: String
    let priceSkint: Int
    let yield: [(aspect: String, quantity: Int)]
}
