import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class GameState {
    let engine = PuzzleEngine.standard
    let language: LanguageService = FoundationModelsLanguageService()
    let recognizer = VisionRecognizer()

    static let questionBudget = 3

    struct DialogueEntry: Identifiable {
        let id = UUID()
        let question: String
        let reply: String
        let source: GenerationSource
    }

    struct PaymentOption: Identifiable {
        let id = UUID()
        let label: String
        let skint: Int
        let itemID: String?
    }

    struct QueuedCustomer: Identifiable {
        let id = UUID()
        let entry: PotionCatalogEntry
        let seed: UInt64
        let patience: Int
    }

    var path: [AppRoute] = []
    var save: GameSave?
    var queue: [QueuedCustomer] = []
    var order: ClientOrder?
    var spec: HiddenOrderSpec?
    var target: PuzzleTarget?
    var activeResolved = false
    var placements: [Hex: String] = [:]
    private var freeHexes: Set<Hex> = []
    var transcript: [DialogueEntry] = []
    var revealedFactIDs: Set<String> = []
    var questionsRemaining = questionBudget
    var isAwaitingReply = false
    var statusMessage = "Visit the counter for a new order."
    var potionDescription: PotionDescription?
    var lastPotionType: PotionType?
    var review: Review?
    var pendingPayment: [PaymentOption]?
    var lastScan: ScanOutcome?
    var isScanning = false
    var autoBuildHint: String?

    struct ScanOutcome {
        let labels: [String]
        let granted: [(aspectID: String, quantity: Int)]
        let duplicate: Bool
        let message: String
        var source: GenerationSource?
    }

    var statusText: String { language.statusText }

    var orderSlots: Int { save?.orderSlots ?? UpgradeCatalog.baseOrderSlots }

    var rentDue: Int { Economy.rent(forDay: save?.day ?? 1) }

    var apprenticeUnlocked: Bool { save?.apprenticeUnlocked ?? false }

    var canEndDay: Bool {
        queue.isEmpty && (order == nil || activeResolved)
    }

    var ownedAspectIDs: [String] {
        (save?.inventory ?? [:]).keys.sorted()
    }

    func count(of aspectID: String) -> Int {
        save?.count(of: aspectID) ?? 0
    }

    func isKnown(_ aspectID: String) -> Bool {
        save?.isKnown(aspectID) ?? false
    }

    var revealedFacts: [OrderFact] {
        spec?.facts.filter { revealedFactIDs.contains($0.id) } ?? []
    }

    var coreRevealed: Bool {
        revealedFacts.contains {
            if case .requiresAspect = $0.kind { return true }
            return false
        }
    }

    var canCraft: Bool {
        target != nil && !activeResolved
    }

    private func clearActiveOrder() {
        refundPlacements()
        order = nil
        spec = nil
        target = nil
        activeResolved = false
        transcript = []
        revealedFactIDs = []
        questionsRemaining = 0
        workshopSteps = []
        apprenticeVerdict = nil
        autoBuildHint = nil
    }

    func startDay() {
        clearActiveOrder()
        potionDescription = nil
        review = nil
        pendingPayment = nil

        let stage: (Guild) -> ReputationStage = { [save] guild in
            save?.reputationStage(for: guild) ?? .indifference
        }
        let patience = save?.customerPatience ?? UpgradeCatalog.basePatience
        let available = engine.availableOrders(stage: stage).shuffled()
        var newQueue: [QueuedCustomer] = []
        var usedTypes: Set<PotionType> = []
        for entry in available where newQueue.count < orderSlots {
            guard usedTypes.insert(entry.type).inserted else { continue }
            newQueue.append(QueuedCustomer(entry: entry, seed: UInt64.random(in: .min ... .max), patience: patience))
        }
        while newQueue.count < orderSlots, let entry = available.randomElement() {
            newQueue.append(QueuedCustomer(entry: entry, seed: UInt64.random(in: .min ... .max), patience: patience))
        }
        queue = newQueue

        let day = save?.day ?? 1
        statusMessage = queue.isEmpty
            ? "Day \(day). No customers today. Close up when ready."
            : "Day \(day). \(queue.count) customer\(queue.count == 1 ? "" : "s") waiting. Rent tonight: \(rentDue) skint."
    }

    func endDay() {
        guard let save else { return }
        let due = Economy.rent(forDay: save.day)
        var note: String
        if save.skint >= due {
            save.skint -= due
            note = "Day \(save.day) closed. Paid \(due) skint rent."
        } else {
            let short = due - save.skint
            save.skint = 0
            save.missedRent += 1
            note = "Day \(save.day) closed. Couldn't cover rent (short \(short) skint). Strike \(save.missedRent)."
        }
        save.day += 1
        startDay()
        statusMessage = "\(note) \(statusMessage)"
    }

    func acceptCustomer(_ customer: QueuedCustomer) async {
        clearActiveOrder()
        queue.removeAll { $0.id == customer.id }
        potionDescription = nil
        review = nil
        pendingPayment = nil

        _ = await language.warmUpFoundationModels()

        let entry = customer.entry
        let newOrder = await language.makeOrder(
            guild: entry.guild,
            potion: entry.type,
            effect: entry.effectDescription
        )
        let newSpec = engine.makeSpec(for: entry.type)

        order = newOrder
        spec = newSpec
        target = engine.makeTarget(for: newSpec, seed: customer.seed)
        revealedFactIDs = Set(
            newSpec.facts
                .filter { if case .requiresAspect = $0.kind { return true } else { return false } }
                .map(\.id)
        )
        questionsRemaining = customer.patience
        statusMessage = "\(newOrder.personaName) (\(entry.guild.displayName)) steps up. Hear them out, or get straight to crafting."
        path = [.conversation]
    }

    func askQuestion(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard questionsRemaining > 0, !trimmed.isEmpty, let order, let spec, !isAwaitingReply else { return }

        isAwaitingReply = true
        let reply = await language.answerQuestion(
            order: order,
            facts: spec.facts,
            question: trimmed,
            previousReplies: transcript.map(\.reply),
            alreadyRevealed: revealedFactIDs
        )
        revealedFactIDs.formUnion(reply.revealedFactIDs)
        transcript.append(DialogueEntry(question: trimmed, reply: reply.text, source: reply.source))
        questionsRemaining -= 1
        isAwaitingReply = false
    }

    func declineOrder() {
        let name = order?.personaName ?? "The customer"
        clearActiveOrder()
        potionDescription = nil
        review = nil
        pendingPayment = nil
        path = []
        statusMessage = "You wave \(name) away. Who's next?"
    }

    func buyUpgrade(_ upgrade: Upgrade) {
        guard let save else { return }
        let level = save.upgradeLevel(upgrade.kind)
        guard let price = upgrade.price(currentLevel: level), save.skint >= price else { return }
        save.skint -= price
        save.setUpgradeLevel(upgrade.kind, level + 1)
        statusMessage = "Bought \(upgrade.name)."
    }

    @discardableResult
    func combine(_ lhs: String, _ rhs: String) -> String? {
        guard
            let save,
            let child = engine.graph.combination(of: lhs, rhs),
            save.count(of: lhs) >= 1,
            save.count(of: rhs) >= 1
        else { return nil }

        save.consume(lhs)
        save.consume(rhs)
        save.add(child)
        return child
    }

    var ownedItems: [(item: CauldronItem, quantity: Int)] {
        (save?.items ?? [:])
            .compactMap { id, qty in
                CauldronCatalog.item(id: id).map { ($0, qty) }
            }
            .sorted { $0.item.name < $1.item.name }
    }

    func itemCount(of itemID: String) -> Int {
        save?.itemCount(of: itemID) ?? 0
    }

    func buyItem(_ item: CauldronItem) {
        guard let save, save.skint >= item.priceSkint else { return }
        save.skint -= item.priceSkint
        save.addItem(item.id)
    }

    func tossItem(_ item: CauldronItem) {
        guard let save, save.consumeItem(item.id) else { return }
        for entry in item.yield {
            save.add(entry.aspect, entry.quantity)
        }
    }

    func scanImage(_ image: CGImage) async {
        guard let save, !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let labels = (try? await recognizer.classify(image)) ?? []
        guard let typeKey = labels.first else {
            lastScan = ScanOutcome(
                labels: [],
                granted: [],
                duplicate: false,
                message: "Couldn't make out the object. Try a clearer photo."
            )
            return
        }

        let readable = typeKey.replacingOccurrences(of: "_", with: " ")
        if save.hasScanned(typeKey) {
            lastScan = ScanOutcome(
                labels: labels,
                granted: [],
                duplicate: true,
                message: "You've already catalogued a \(readable). A different kind of object would yield more."
            )
            return
        }

        let suggestion = await language.mapObjectToAspects(labels: labels, vocabulary: engine.aspectVocabulary)
        let reward = engine.scanReward(for: suggestion.aspectIDs)
        for (id, quantity) in reward { save.add(id, quantity) }
        save.markScanned(typeKey)

        let granted = reward
            .map { (aspectID: $0.key, quantity: $0.value) }
            .sorted { $0.aspectID < $1.aspectID }
        let names = granted
            .map { "\(engine.graph.aspectName($0.aspectID)) ×\($0.quantity)" }
            .joined(separator: ", ")

        lastScan = ScanOutcome(
            labels: labels,
            granted: granted,
            duplicate: false,
            message: granted.isEmpty
                ? "The bench found nothing usable in a \(readable)."
                : "\(suggestion.rationale) Gained: \(names).",
            source: suggestion.source
        )
    }

    func place(_ aspectID: String, at hex: Hex) {
        guard
            let save,
            placements[hex] == nil,
            target?.blockedHexes.contains(hex) != true,
            target?.lockedHexes.contains(hex) != true,
            save.consume(aspectID)
        else { return }
        placements[hex] = aspectID
        freeHexes.remove(hex)
        autoBuildHint = nil
    }

    func clear(at hex: Hex) {
        guard let aspectID = placements[hex] else { return }
        if freeHexes.remove(hex) == nil {
            save?.add(aspectID)
        }
        placements[hex] = nil
        autoBuildHint = nil
    }

    func refundPlacements() {
        for (hex, aspectID) in placements where !freeHexes.contains(hex) {
            save?.add(aspectID)
        }
        placements = [:]
        freeHexes = []
    }

    @discardableResult
    func autoBuild() -> Bool {
        guard let target else { return false }
        refundPlacements()

        for (hex, aspectID) in engine.idealSolution(target: target) {
            placements[hex] = aspectID
            freeHexes.insert(hex)
        }

        let result = engine.validate(placements: placements, target: target)
        autoBuildHint = result.isValid
            ? "Laid out a clean chain, tap Craft to finish."
            : "Couldn't complete the chain automatically."
        return result.isValid
    }

    func craft() async -> Bool {
        guard let order, let target, let save, !activeResolved else { return false }

        let result = engine.validate(placements: placements, target: target)
        guard result.isValid else {
            statusMessage = result.message
            return false
        }

        await settle(order: order, target: target, save: save, result: result)
        path = []
        return true
    }

    private func settle(order: ClientOrder, target: PuzzleTarget, save: GameSave, result: CraftResult) async {
        placements = [:]
        freeHexes = []
        activeResolved = true

        var quality = result.quality
        if result.quality > 0.2 {
            let respected = revealedFacts.filter {
                if case .forbidsAspect = $0.kind { return true } else { return false }
            }.count
            quality = min(1.0, quality + 0.05 * Double(respected))
        }

        let entry = engine.catalogEntry(for: target.potionType)
        let base = entry.basePriceSkint
        let tip = Economy.tip(base: base, quality: quality, multiplier: save.tipMultiplier)
        let payout = base + tip

        save.adjustReputation(for: order.guild, quality: quality)
        lastPotionType = target.potionType

        let qualityText = quality.formatted(.percent.precision(.fractionLength(0)))
        let tipText = tip > 0 ? " (incl. \(tip) tip)" : ""

        let options = paymentOptions(payout: payout, guild: order.guild)
        if options.count > 1 {
            pendingPayment = options
            statusMessage = "\(result.message) Quality \(qualityText). \(order.personaName) is fishing for coin..."
        } else {
            pendingPayment = nil
            save.skint += payout
            statusMessage = "\(result.message) Quality \(qualityText). Paid \(payout) skint\(tipText)."
        }

        potionDescription = await language.describePotion(type: target.potionType, quality: quality)
        review = await language.writeReview(order: order, quality: quality)
    }

    struct WorkshopStep: Identifiable {
        let id = UUID()
        let aspect: String
        let thought: String
        let source: GenerationSource
    }

    var workshopSteps: [WorkshopStep] = []
    var apprenticeWorking = false
    var apprenticeVerdict: String?

    func runApprentice() async {
        guard let order, let target, let save, !apprenticeWorking, !activeResolved else { return }
        apprenticeWorking = true
        defer { apprenticeWorking = false }

        refundPlacements()
        workshopSteps = []
        apprenticeVerdict = nil

        let essence = engine.graph.aspectName(target.targetAspect)
        let forbidden = target.forbiddenAspects.map { engine.graph.aspectName($0) }
        let budget = target.idealPlacements * 2 + 4

        for _ in 0..<budget {
            if engine.validate(placements: placements, target: target).isValid { break }

            let moves = engine.candidateMoves(placements: placements, target: target, inventory: save.inventory, unlimited: true)
            guard !moves.isEmpty else { break }

            let unconnected = engine.unconnectedAnchors(placements: placements, target: target)
                .map { engine.graph.aspectName($0.aspect) }
            let options = moves.enumerated().map { offset, move in
                ApprenticeMoveOption(
                    index: offset,
                    aspect: engine.graph.aspectName(move.aspectID),
                    linksTo: move.linkNames.joined(separator: " + ")
                )
            }

            let decision = await language.decideApprenticeMove(
                essence: essence,
                unconnected: unconnected,
                forbidden: forbidden,
                options: options
            )

            if decision.finished {
                workshopSteps.append(WorkshopStep(aspect: "-", thought: decision.thought, source: decision.source))
                break
            }
            guard let index = decision.chosenIndex, moves.indices.contains(index) else { break }

            let move = moves[index]
            placements[move.hex] = move.aspectID
            freeHexes.insert(move.hex)
            workshopSteps.append(WorkshopStep(aspect: engine.graph.aspectName(move.aspectID), thought: decision.thought, source: decision.source))

            try? await Task.sleep(for: .milliseconds(450))
        }

        let result = engine.validate(placements: placements, target: target)
        if result.isValid {
            let quality = result.quality.formatted(.percent.precision(.fractionLength(0)))
            await settle(order: order, target: target, save: save, result: result)
            apprenticeVerdict = "Finished. \(result.message) Quality \(quality)."
        } else {
            refundPlacements()
            apprenticeVerdict = "The apprentice gave up, it couldn't link everything. \(result.message) Your aspects are returned."
        }
    }

    private func paymentOptions(payout: Int, guild: Guild) -> [PaymentOption] {
        let full = PaymentOption(label: "\(payout) skint", skint: payout, itemID: nil)
        guard Bool.random(), let item = CauldronCatalog.items.randomElement() else {
            return [full]
        }
        let reduced = max(1, payout / 2)
        let barter = PaymentOption(label: "\(reduced) skint + \(item.name)", skint: reduced, itemID: item.id)
        return [full, barter]
    }

    func settlePayment(_ option: PaymentOption) {
        guard let save else { return }
        save.skint += option.skint
        if let itemID = option.itemID {
            save.addItem(itemID)
        }
        pendingPayment = nil
        statusMessage = "Settled for \(option.label)."
    }
}
