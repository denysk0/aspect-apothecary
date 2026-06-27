import Foundation

struct PuzzleEngine {
    let graph: AspectGraph
    let catalog: [PotionCatalogEntry]

    static let standard = PuzzleEngine(
        graph: .standard,
        catalog: [
            PotionCatalogEntry(type: .preservation, guild: .smugglers, tier: 1, basePriceSkint: 18, targetAspectID: "victus", effectDescription: "keep goods and bodies from spoiling"),
            PotionCatalogEntry(type: .stealth, guild: .thieves, tier: 1, basePriceSkint: 18, targetAspectID: "tenebrae", effectDescription: "let the drinker slip through shadows unseen"),
            PotionCatalogEntry(type: .light, guild: .mages, tier: 1, basePriceSkint: 16, targetAspectID: "lux", effectDescription: "give off a steady, reliable light"),
            PotionCatalogEntry(type: .numbing, guild: .mercenaries, tier: 1, basePriceSkint: 18, targetAspectID: "gelum", effectDescription: "numb pain and fear before a brawl"),
            PotionCatalogEntry(type: .savor, guild: .spiceMerchants, tier: 1, basePriceSkint: 17, targetAspectID: "herba", effectDescription: "fill the air with an irresistible scent"),
            PotionCatalogEntry(type: .strength, guild: .mercenaries, tier: 2, basePriceSkint: 30, targetAspectID: "potentia", effectDescription: "make the drinker physically stronger"),
            PotionCatalogEntry(type: .warding, guild: .smugglers, tier: 2, basePriceSkint: 30, targetAspectID: "tutamen", effectDescription: "turn aside prying eyes and blows"),
            PotionCatalogEntry(type: .silence, guild: .thieves, tier: 2, basePriceSkint: 28, targetAspectID: "vacuos", effectDescription: "make the drinker move in utter silence"),
            PotionCatalogEntry(type: .charm, guild: .spiceMerchants, tier: 2, basePriceSkint: 30, targetAspectID: "sensus", effectDescription: "charm and sway whoever is nearby"),
            PotionCatalogEntry(type: .healing, guild: .mages, tier: 2, basePriceSkint: 32, targetAspectID: "sano", effectDescription: "knit wounds and restore vigor"),
            PotionCatalogEntry(type: .clarity, guild: .mages, tier: 3, basePriceSkint: 42, targetAspectID: "cognitio", effectDescription: "sharpen the mind to crystal clarity"),
            PotionCatalogEntry(type: .combat, guild: .mercenaries, tier: 3, basePriceSkint: 44, targetAspectID: "telum", effectDescription: "make a warrior deadly in a fight"),
            PotionCatalogEntry(type: .fortune, guild: .spiceMerchants, tier: 3, basePriceSkint: 44, targetAspectID: "lucrum", effectDescription: "draw fortune and profit to the drinker"),
            PotionCatalogEntry(type: .flight, guild: .mages, tier: 3, basePriceSkint: 46, targetAspectID: "volatus", effectDescription: "grant the drinker flight")
        ]
    )

    func catalogEntry(for potionType: PotionType) -> PotionCatalogEntry {
        catalog.first { $0.type == potionType } ?? catalog[0]
    }

    var aspectVocabulary: [AspectVocabularyEntry] {
        graph.allAspectIDs.compactMap { id in
            graph.aspect(id).map { AspectVocabularyEntry(id: id, keyword: $0.keyword, name: $0.name) }
        }
    }

    static let scanMaxAspects = 3

    func scanReward(for suggestedIDs: [String]) -> [String: Int] {
        var seen: Set<String> = []
        var ordered: [String] = []
        for id in suggestedIDs where graph.aspect(id) != nil && seen.insert(id).inserted {
            ordered.append(id)
        }

        var reward: [String: Int] = [:]
        for id in ordered.prefix(Self.scanMaxAspects) {
            let isPrimal = graph.aspect(id)?.parents.isEmpty == true
            reward[id] = isPrimal ? 3 : 2
        }
        return reward
    }

    func availableOrders(stage: (Guild) -> ReputationStage) -> [PotionCatalogEntry] {
        catalog.filter { stage($0.guild).rawValue + 1 >= $0.tier }
    }

    func pickOrder(stage: (Guild) -> ReputationStage) -> PotionCatalogEntry? {
        availableOrders(stage: stage).randomElement()
    }

    func makeSpec(for potionType: PotionType) -> HiddenOrderSpec {
        let entry = catalogEntry(for: potionType)
        let path = chain(to: entry.targetAspectID, desiredDepth: entry.tier + 1)
        let target = entry.targetAspectID
        let forbidden = forbiddenAspects(for: target, path: path, count: max(1, entry.tier - 1))

        var facts: [OrderFact] = [
            OrderFact(
                id: "core",
                note: "Wants a \(potionType.displayName) potion",
                hint: "You want a potion that will \(entry.effectDescription).",
                kind: .requiresAspect(target)
            )
        ]
        for (index, aspect) in forbidden.enumerated() {
            let keyword = graph.aspectKeyword(aspect)
            facts.append(OrderFact(
                id: "avoid\(index)",
                note: "Must not involve \(keyword)",
                hint: "I've a personal aversion to \(keyword), keep every last trace of it out of my potion, whatever you do.",
                kind: .forbidsAspect(aspect)
            ))
        }

        return HiddenOrderSpec(
            potionType: potionType,
            targetAspect: target,
            forbiddenAspects: forbidden,
            facts: facts
        )
    }

    func makeTarget(for spec: HiddenOrderSpec, seed: UInt64) -> PuzzleTarget {
        var rng = SeededRNG(seed: seed)
        let tier = catalogEntry(for: spec.potionType).tier
        let anchorCount = max(1, tier)
        let targetHex = Hex(q: 0, r: 0)
        let targetAspect = spec.targetAspect

        let chains = distinctChains(to: targetAspect, desiredDepth: tier + 1, count: anchorCount)
        var directions = Hex.directions
        directions.shuffle(using: &rng)

        var anchors: [PuzzleEndpoint] = []
        var idealPaths: [[String]] = []
        var corridor: Set<Hex> = [targetHex]
        var maxDistance = 1

        for (index, chain) in chains.enumerated() {
            let links = max(1, chain.count - 1)
            let direction = directions[index % directions.count]
            let anchorHex = Hex(q: direction.q * links, r: direction.r * links)
            corridor.formUnion(anchorHex.line(to: targetHex))
            anchors.append(PuzzleEndpoint(hex: anchorHex, aspect: chain.first ?? targetAspect))
            idealPaths.append(chain)
            maxDistance = max(maxDistance, links)
        }

        let radius = maxDistance + 1

        let density = min(0.45, 0.18 + Double(tier) * 0.09)
        var blocked: Set<Hex> = []
        for cell in Hex.board(radius: radius) where !corridor.contains(cell) {
            if Double.random(in: 0..<1, using: &rng) < density {
                blocked.insert(cell)
            }
        }

        return PuzzleTarget(
            potionType: spec.potionType,
            boardRadius: radius,
            cells: Hex.board(radius: radius),
            targetHex: targetHex,
            targetAspect: targetAspect,
            anchors: anchors,
            idealPaths: idealPaths,
            forbiddenAspects: spec.forbiddenAspects,
            blockedHexes: blocked
        )
    }

    private func distinctChains(to target: String, desiredDepth: Int, count: Int) -> [[String]] {
        var candidates: [[String]] = []
        for primal in graph.primalIDs {
            let path = graph.shortestPath(from: primal, to: target)
            if path.count >= 2 { candidates.append(path) }
        }
        candidates.sort { abs(($0.count - 1) - desiredDepth) < abs(($1.count - 1) - desiredDepth) }

        guard !candidates.isEmpty else { return Array(repeating: [target], count: count) }

        var chosen: [[String]] = []
        var usedPrimals: Set<String> = []
        for path in candidates where chosen.count < count {
            if let primal = path.first, usedPrimals.insert(primal).inserted {
                chosen.append(path)
            }
        }
        var index = 0
        while chosen.count < count {
            chosen.append(candidates[index % candidates.count])
            index += 1
        }
        return chosen
    }

    private func forbiddenAspects(for target: String, path: [String], count: Int) -> [String] {
        let onPath = Set(path)
        let targetParents = Set(graph.aspect(target)?.parents ?? [])

        let siblings = graph.allAspectIDs.filter { id in
            guard id != target, !onPath.contains(id) else { return false }
            return !Set(graph.aspect(id)?.parents ?? []).isDisjoint(with: targetParents)
        }

        let fallback = graph.allAspectIDs.filter { id in
            id != target && !onPath.contains(id) && graph.aspect(id)?.parents.isEmpty == false
        }

        let pool = siblings.isEmpty ? fallback : siblings
        return Array(pool.prefix(count))
    }

    private func chain(to target: String, desiredDepth: Int) -> [String] {
        var best = graph.nearestPrimalPath(to: target)

        for primal in graph.primalIDs {
            let candidate = graph.shortestPath(from: primal, to: target)
            guard candidate.count >= 2 else { continue }
            let candidateGap = abs((candidate.count - 1) - desiredDepth)
            let bestGap = abs((best.count - 1) - desiredDepth)
            if candidateGap < bestGap {
                best = candidate
            }
        }

        return best.isEmpty ? [target] : best
    }

    func validate(placements: [Hex: String], target: PuzzleTarget) -> CraftResult {
        var occupied = placements
        occupied[target.targetHex] = target.targetAspect
        for anchor in target.anchors { occupied[anchor.hex] = anchor.aspect }

        let reachable = reachable(from: target.targetHex, in: occupied)
        let unlinked = target.anchors.filter { !reachable.contains($0.hex) }
        guard unlinked.isEmpty else {
            let names = unlinked.map { graph.aspectName($0.aspect) }.joined(separator: ", ")
            return CraftResult(
                isValid: false,
                quality: 0,
                message: "Not yet linked to \(graph.aspectName(target.targetAspect)): \(names)."
            )
        }

        let strayWaste = max(0, placements.count - target.idealPlacements)
        var quality = max(0.35, 1.0 - Double(strayWaste) * 0.08)

        let forbidden = Set(target.forbiddenAspects)
        if let offender = placements.values.first(where: { forbidden.contains($0) }) {
            quality = min(quality, 0.2)
            return CraftResult(
                isValid: true,
                quality: quality,
                message: "Done, but it reeks of \(graph.aspectName(offender)), the customer wanted none of that."
            )
        }

        return CraftResult(isValid: true, quality: quality, message: "Stable transmutation.")
    }

    func idealSolution(target: PuzzleTarget) -> [(hex: Hex, aspectID: String)] {
        var result: [(hex: Hex, aspectID: String)] = []
        for (index, anchor) in target.anchors.enumerated() {
            let corridor = anchor.hex.line(to: target.targetHex)
            let chain = target.idealPaths[index]
            let count = min(corridor.count, chain.count)
            guard count > 2 else { continue }
            for step in 1..<(count - 1) {
                result.append((corridor[step], chain[step]))
            }
        }
        return result
    }

    func unconnectedAnchors(placements: [Hex: String], target: PuzzleTarget) -> [PuzzleEndpoint] {
        var occupied = placements
        occupied[target.targetHex] = target.targetAspect
        for anchor in target.anchors { occupied[anchor.hex] = anchor.aspect }
        let reach = reachable(from: target.targetHex, in: occupied)
        return target.anchors.filter { !reach.contains($0.hex) }
    }

    func candidateMoves(
        placements: [Hex: String],
        target: PuzzleTarget,
        inventory: [String: Int],
        unlimited: Bool = false,
        limit: Int = 8
    ) -> [ApprenticeMove] {
        var occupied = placements
        occupied[target.targetHex] = target.targetAspect
        for anchor in target.anchors { occupied[anchor.hex] = anchor.aspect }

        let boardCells = Set(target.cells)

        func isOpen(_ hex: Hex) -> Bool {
            boardCells.contains(hex)
                && occupied[hex] == nil
                && !target.blockedHexes.contains(hex)
                && !target.lockedHexes.contains(hex)
        }

        func links(for aspect: String, at hex: Hex) -> [String] {
            hex.neighbors().compactMap { occupied[$0] }.filter { graph.canLink(aspect, $0) }
        }

        var ideal: [ApprenticeMove] = []
        var idealCells: Set<Hex> = []
        for (anchorIndex, anchor) in target.anchors.enumerated() {
            let corridor = anchor.hex.line(to: target.targetHex)
            let chain = target.idealPaths[anchorIndex]
            let count = min(corridor.count, chain.count)
            guard count > 2 else { continue }
            for step in 1..<(count - 1) {
                let cell = corridor[step]
                let aspect = chain[step]
                let available = unlimited || (inventory[aspect] ?? 0) > 0
                guard isOpen(cell), available, idealCells.insert(cell).inserted else { continue }
                ideal.append(ApprenticeMove(hex: cell, aspectID: aspect, linkNames: links(for: aspect, at: cell)))
            }
        }

        let unconnected = unconnectedAnchors(placements: placements, target: target).map(\.hex)
        func nearness(_ hex: Hex) -> Int {
            unconnected.isEmpty ? 0 : (unconnected.map { hex.distance(to: $0) }.min() ?? 0)
        }
        let owned = unlimited ? graph.allAspectIDs.sorted() : inventory.filter { $0.value > 0 }.map(\.key).sorted()

        var frontier: Set<Hex> = []
        for hex in occupied.keys {
            for neighbor in hex.neighbors() where isOpen(neighbor) && !idealCells.contains(neighbor) {
                frontier.insert(neighbor)
            }
        }
        var distractors: [ApprenticeMove] = []
        for hex in frontier.sorted(by: { nearness($0) < nearness($1) }) {
            for aspect in owned {
                let linked = links(for: aspect, at: hex)
                if !linked.isEmpty {
                    distractors.append(ApprenticeMove(hex: hex, aspectID: aspect, linkNames: linked))
                    break
                }
            }
        }

        return Array((ideal + distractors).prefix(limit))
    }

    private func reachable(from start: Hex, in occupied: [Hex: String]) -> Set<Hex> {
        guard occupied[start] != nil else { return [] }

        var visited: Set<Hex> = [start]
        var queue = [start]
        var head = 0

        while head < queue.count {
            let hex = queue[head]
            head += 1
            guard let aspect = occupied[hex] else { continue }

            for neighbor in hex.neighbors() where !visited.contains(neighbor) {
                guard let other = occupied[neighbor], graph.canLink(aspect, other) else { continue }
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }

        return visited
    }
}

struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
