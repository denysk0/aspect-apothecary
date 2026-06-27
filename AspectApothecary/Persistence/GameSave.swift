import Foundation
import SwiftData

@Model
final class GameSave {
    @Attribute(.unique) var id: String
    var skint: Int
    var smugglersReputation: Int
    var thievesReputation: Int
    var mercenariesReputation: Int
    var spiceMerchantsReputation: Int
    var magesReputation: Int
    var inventoryRaw: String = GameSave.defaultInventoryRaw
    var itemsRaw: String = "{}"
    var knownAspectsRaw: String = AspectGraph.standard.primalIDs.joined(separator: ",")
    var scannedTypesRaw: String = ""
    var day: Int = 1
    var missedRent: Int = 0
    var upgradesRaw: String = "{}"

    init(
        id: String = "current",
        skint: Int = 40,
        smugglersReputation: Int = ReputationStage.indifference.rawValue,
        thievesReputation: Int = ReputationStage.indifference.rawValue,
        mercenariesReputation: Int = ReputationStage.indifference.rawValue,
        spiceMerchantsReputation: Int = ReputationStage.indifference.rawValue,
        magesReputation: Int = ReputationStage.friendliness.rawValue,
        inventoryRaw: String = GameSave.defaultInventoryRaw,
        itemsRaw: String = "{}",
        knownAspectsRaw: String = AspectGraph.standard.primalIDs.joined(separator: ","),
        scannedTypesRaw: String = "",
        day: Int = 1,
        missedRent: Int = 0,
        upgradesRaw: String = "{}"
    ) {
        self.id = id
        self.skint = skint
        self.smugglersReputation = smugglersReputation
        self.thievesReputation = thievesReputation
        self.mercenariesReputation = mercenariesReputation
        self.spiceMerchantsReputation = spiceMerchantsReputation
        self.magesReputation = magesReputation
        self.inventoryRaw = inventoryRaw
        self.itemsRaw = itemsRaw
        self.knownAspectsRaw = knownAspectsRaw
        self.scannedTypesRaw = scannedTypesRaw
        self.day = day
        self.missedRent = missedRent
        self.upgradesRaw = upgradesRaw
    }

    var upgradeLevels: [String: Int] {
        guard let data = upgradesRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded.filter { $0.value > 0 }
    }

    func upgradeLevel(_ kind: UpgradeKind) -> Int {
        upgradeLevels[kind.rawValue] ?? 0
    }

    func setUpgradeLevel(_ kind: UpgradeKind, _ level: Int) {
        var current = upgradeLevels
        current[kind.rawValue] = level
        guard let data = try? JSONEncoder().encode(current),
              let string = String(data: data, encoding: .utf8)
        else { return }
        upgradesRaw = string
    }

    var orderSlots: Int { UpgradeCatalog.orderSlots(levels: upgradeLevels) }
    var customerPatience: Int { UpgradeCatalog.patience(levels: upgradeLevels) }
    var tipMultiplier: Double { UpgradeCatalog.tipMultiplier(levels: upgradeLevels) }
    var apprenticeUnlocked: Bool { UpgradeCatalog.apprenticeUnlocked(levels: upgradeLevels) }

    var scannedTypes: Set<String> {
        Set(scannedTypesRaw.split(separator: "\n").map(String.init))
    }

    func hasScanned(_ typeKey: String) -> Bool {
        scannedTypes.contains(typeKey)
    }

    @discardableResult
    func markScanned(_ typeKey: String) -> Bool {
        var current = scannedTypes
        guard current.insert(typeKey).inserted else { return false }
        scannedTypesRaw = current.sorted().joined(separator: "\n")
        return true
    }

    var knownAspects: Set<String> {
        Set(knownAspectsRaw.split(separator: ",").map(String.init))
    }

    func isKnown(_ aspectID: String) -> Bool {
        knownAspects.contains(aspectID)
    }

    func markKnown(_ aspectID: String) {
        var current = knownAspects
        guard current.insert(aspectID).inserted else { return }
        knownAspectsRaw = current.sorted().joined(separator: ",")
    }

    static let primalStartingStock = 8

    static var defaultInventoryRaw: String {
        let stock = Dictionary(
            uniqueKeysWithValues: AspectGraph.standard.primalIDs.map { ($0, primalStartingStock) }
        )
        return encode(stock)
    }

    var inventory: [String: Int] {
        guard let data = inventoryRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded.filter { $0.value > 0 }
    }

    func count(of aspectID: String) -> Int {
        inventory[aspectID] ?? 0
    }

    func add(_ aspectID: String, _ amount: Int = 1) {
        var current = inventory
        current[aspectID, default: 0] += amount
        inventoryRaw = GameSave.encode(current)
        markKnown(aspectID)
    }

    @discardableResult
    func consume(_ aspectID: String, _ amount: Int = 1) -> Bool {
        var current = inventory
        guard current[aspectID, default: 0] >= amount else { return false }
        current[aspectID]! -= amount
        if current[aspectID] == 0 { current[aspectID] = nil }
        inventoryRaw = GameSave.encode(current)
        return true
    }

    var items: [String: Int] {
        guard let data = itemsRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data)
        else { return [:] }
        return decoded.filter { $0.value > 0 }
    }

    func itemCount(of itemID: String) -> Int {
        items[itemID] ?? 0
    }

    func addItem(_ itemID: String, _ amount: Int = 1) {
        var current = items
        current[itemID, default: 0] += amount
        itemsRaw = GameSave.encode(current)
    }

    @discardableResult
    func consumeItem(_ itemID: String, _ amount: Int = 1) -> Bool {
        var current = items
        guard current[itemID, default: 0] >= amount else { return false }
        current[itemID]! -= amount
        if current[itemID] == 0 { current[itemID] = nil }
        itemsRaw = GameSave.encode(current)
        return true
    }

    private static func encode(_ inventory: [String: Int]) -> String {
        guard let data = try? JSONEncoder().encode(inventory),
              let string = String(data: data, encoding: .utf8)
        else { return "{}" }
        return string
    }

    func reputationStage(for guild: Guild) -> ReputationStage {
        let rawValue = switch guild {
        case .smugglers: smugglersReputation
        case .thieves: thievesReputation
        case .mercenaries: mercenariesReputation
        case .spiceMerchants: spiceMerchantsReputation
        case .mages: magesReputation
        }

        return ReputationStage(rawValue: rawValue) ?? .indifference
    }

    func adjustReputation(for guild: Guild, quality: Double) {
        let delta = quality >= 0.8 ? 1 : quality < 0.5 ? -1 : 0
        guard delta != 0 else { return }

        let current = reputationStage(for: guild).rawValue
        let next = min(ReputationStage.trust.rawValue, max(ReputationStage.indifference.rawValue, current + delta))

        switch guild {
        case .smugglers: smugglersReputation = next
        case .thieves: thievesReputation = next
        case .mercenaries: mercenariesReputation = next
        case .spiceMerchants: spiceMerchantsReputation = next
        case .mages: magesReputation = next
        }
    }
}
