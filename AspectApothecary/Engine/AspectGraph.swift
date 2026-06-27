import Foundation

struct AspectGraph {
    let aspects: [String: Aspect]

    static let standard = AspectGraph(aspects: Dictionary(
        uniqueKeysWithValues: standardAspects.map { ($0.id, $0) }
    ))

    var allAspectIDs: [String] {
        aspects.values.map(\.id).sorted()
    }

    var primalIDs: [String] {
        aspects.values
            .filter { $0.parents.isEmpty }
            .map(\.id)
            .sorted()
    }

    func aspect(_ id: String) -> Aspect? {
        aspects[id]
    }

    func aspectName(_ id: String) -> String {
        aspects[id]?.name ?? id.capitalized
    }

    func aspectKeyword(_ id: String) -> String {
        aspects[id]?.keyword ?? id
    }

    func aspectEmoji(_ id: String) -> String {
        aspects[id]?.emoji ?? "❓"
    }

    func neighbors(of id: String) -> [String] {
        var result = Set(aspects[id]?.parents ?? [])
        for aspect in aspects.values where aspect.parents.contains(id) {
            result.insert(aspect.id)
        }
        return result.sorted()
    }

    func combination(of lhs: String, _ rhs: String) -> String? {
        let pair = Set([lhs, rhs])
        return aspects.values.first { Set($0.parents) == pair }?.id
    }

    func canLink(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs != rhs else { return true }
        return aspects[lhs]?.parents.contains(rhs) == true
            || aspects[rhs]?.parents.contains(lhs) == true
    }

    func shortestPath(from start: String, to end: String) -> [String] {
        guard aspects[start] != nil, aspects[end] != nil else { return [] }
        if start == end { return [start] }

        var cameFrom: [String: String] = [:]
        var visited: Set<String> = [start]
        var queue = [start]
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1

            for next in neighbors(of: current) where !visited.contains(next) {
                visited.insert(next)
                cameFrom[next] = current
                if next == end {
                    return reconstruct(to: end, cameFrom: cameFrom)
                }
                queue.append(next)
            }
        }

        return []
    }

    func nearestPrimalPath(to target: String) -> [String] {
        guard let aspect = aspects[target] else { return [] }
        if aspect.parents.isEmpty { return [target] }

        var cameFrom: [String: String] = [:]
        var visited: Set<String> = [target]
        var queue = [target]
        var head = 0

        while head < queue.count {
            let current = queue[head]
            head += 1

            if aspects[current]?.parents.isEmpty == true {
                return reconstruct(to: current, cameFrom: cameFrom).reversed()
            }

            for next in neighbors(of: current) where !visited.contains(next) {
                visited.insert(next)
                cameFrom[next] = current
                queue.append(next)
            }
        }

        return [target]
    }

    private func reconstruct(to end: String, cameFrom: [String: String]) -> [String] {
        var path = [end]
        var current = end
        while let previous = cameFrom[current] {
            path.append(previous)
            current = previous
        }
        return path.reversed()
    }
}

private extension AspectGraph {
    static let standardAspects: [Aspect] = [
        Aspect(id: "aer", name: "Aer", keyword: "air", emoji: "💨", parents: [], colorHex: "C2D6E8"),
        Aspect(id: "aqua", name: "Aqua", keyword: "water", emoji: "💧", parents: [], colorHex: "2F80ED"),
        Aspect(id: "ignis", name: "Ignis", keyword: "fire", emoji: "🔥", parents: [], colorHex: "D94B35"),
        Aspect(id: "ordo", name: "Ordo", keyword: "order", emoji: "⚖️", parents: [], colorHex: "D6CFA0"),
        Aspect(id: "perditio", name: "Perditio", keyword: "chaos", emoji: "🌀", parents: [], colorHex: "3A3340"),
        Aspect(id: "terra", name: "Terra", keyword: "earth", emoji: "🪨", parents: [], colorHex: "6E8B3D"),

        Aspect(id: "alienis", name: "Alienis", keyword: "eldritch", emoji: "👁️", parents: ["tenebrae", "vacuos"], colorHex: "5B3A6B"),
        Aspect(id: "arbor", name: "Arbor", keyword: "tree", emoji: "🌳", parents: ["aer", "herba"], colorHex: "4E7A3A"),
        Aspect(id: "auram", name: "Auram", keyword: "aura", emoji: "🌟", parents: ["aer", "praecantatio"], colorHex: "C9A86A"),
        Aspect(id: "bestia", name: "Bestia", keyword: "animal", emoji: "🐾", parents: ["motus", "victus"], colorHex: "8B5A2B"),
        Aspect(id: "cognitio", name: "Cognitio", keyword: "mind", emoji: "🧠", parents: ["ignis", "spiritus"], colorHex: "C26FB0"),
        Aspect(id: "corpus", name: "Corpus", keyword: "flesh", emoji: "🥩", parents: ["bestia", "mortuus"], colorHex: "B5564E"),
        Aspect(id: "exanimis", name: "Exanimis", keyword: "undead", emoji: "🧟", parents: ["motus", "mortuus"], colorHex: "6A7B5A"),
        Aspect(id: "fabrico", name: "Fabrico", keyword: "craft", emoji: "🔨", parents: ["humanus", "instrumentum"], colorHex: "A8772F"),
        Aspect(id: "fames", name: "Fames", keyword: "hunger", emoji: "🍽️", parents: ["vacuos", "victus"], colorHex: "7A5A3A"),
        Aspect(id: "gelum", name: "Gelum", keyword: "cold", emoji: "❄️", parents: ["ignis", "perditio"], colorHex: "9FD3E0"),
        Aspect(id: "herba", name: "Herba", keyword: "plant", emoji: "🌿", parents: ["terra", "victus"], colorHex: "5FA83F"),
        Aspect(id: "humanus", name: "Humanus", keyword: "human", emoji: "🧍", parents: ["bestia", "cognitio"], colorHex: "D69A6A"),
        Aspect(id: "instrumentum", name: "Instrumentum", keyword: "tool", emoji: "🛠️", parents: ["humanus", "ordo"], colorHex: "9A8C6B"),
        Aspect(id: "iter", name: "Iter", keyword: "travel", emoji: "🧭", parents: ["motus", "terra"], colorHex: "8FB76A"),
        Aspect(id: "limus", name: "Limus", keyword: "slime", emoji: "🟩", parents: ["aqua", "victus"], colorHex: "7FB04A"),
        Aspect(id: "lucrum", name: "Lucrum", keyword: "greed", emoji: "💰", parents: ["fames", "humanus"], colorHex: "D4AF37"),
        Aspect(id: "lux", name: "Lux", keyword: "light", emoji: "💡", parents: ["aer", "ignis"], colorHex: "F2E27A"),
        Aspect(id: "machina", name: "Machina", keyword: "machine", emoji: "⚙️", parents: ["instrumentum", "motus"], colorHex: "8C8C9A"),
        Aspect(id: "messis", name: "Messis", keyword: "crop", emoji: "🌾", parents: ["herba", "humanus"], colorHex: "B7C25A"),
        Aspect(id: "metallum", name: "Metallum", keyword: "metal", emoji: "🔩", parents: ["terra", "vitreus"], colorHex: "9AA0A6"),
        Aspect(id: "meto", name: "Meto", keyword: "harvest", emoji: "🌽", parents: ["instrumentum", "messis"], colorHex: "B0A050"),
        Aspect(id: "mortuus", name: "Mortuus", keyword: "death", emoji: "☠️", parents: ["perditio", "victus"], colorHex: "5A5560"),
        Aspect(id: "motus", name: "Motus", keyword: "motion", emoji: "🏃", parents: ["aer", "ordo"], colorHex: "9FCB6F"),
        Aspect(id: "pannus", name: "Pannus", keyword: "cloth", emoji: "🧵", parents: ["bestia", "instrumentum"], colorHex: "C8B89A"),
        Aspect(id: "perfodio", name: "Perfodio", keyword: "mining", emoji: "⛏️", parents: ["humanus", "terra"], colorHex: "7A6A55"),
        Aspect(id: "permutatio", name: "Permutatio", keyword: "exchange", emoji: "🔄", parents: ["ordo", "perditio"], colorHex: "8A7AA0"),
        Aspect(id: "potentia", name: "Potentia", keyword: "energy", emoji: "⚡", parents: ["ignis", "ordo"], colorHex: "E0B84F"),
        Aspect(id: "praecantatio", name: "Praecantatio", keyword: "magic", emoji: "🪄", parents: ["potentia", "vacuos"], colorHex: "7E5BB5"),
        Aspect(id: "sano", name: "Sano", keyword: "healing", emoji: "🩹", parents: ["ordo", "victus"], colorHex: "7FC9A0"),
        Aspect(id: "sensus", name: "Sensus", keyword: "senses", emoji: "👀", parents: ["aer", "spiritus"], colorHex: "C9A0D0"),
        Aspect(id: "spiritus", name: "Spiritus", keyword: "soul", emoji: "👻", parents: ["mortuus", "victus"], colorHex: "BFD3D9"),
        Aspect(id: "telum", name: "Telum", keyword: "weapon", emoji: "⚔️", parents: ["ignis", "instrumentum"], colorHex: "C0584A"),
        Aspect(id: "tempestas", name: "Tempestas", keyword: "weather", emoji: "⛈️", parents: ["aer", "aqua"], colorHex: "6FA0C9"),
        Aspect(id: "tenebrae", name: "Tenebrae", keyword: "darkness", emoji: "🌑", parents: ["lux", "vacuos"], colorHex: "2E2A33"),
        Aspect(id: "tutamen", name: "Tutamen", keyword: "armor", emoji: "🛡️", parents: ["instrumentum", "terra"], colorHex: "8A9AA8"),
        Aspect(id: "vacuos", name: "Vacuos", keyword: "void", emoji: "⚫", parents: ["aer", "perditio"], colorHex: "4A4458"),
        Aspect(id: "venenum", name: "Venenum", keyword: "poison", emoji: "🐍", parents: ["aqua", "perditio"], colorHex: "6FA84A"),
        Aspect(id: "victus", name: "Victus", keyword: "life", emoji: "❤️", parents: ["aqua", "terra"], colorHex: "C94F6B"),
        Aspect(id: "vinculum", name: "Vinculum", keyword: "trap", emoji: "🪤", parents: ["motus", "perditio"], colorHex: "6A6A8A"),
        Aspect(id: "vitium", name: "Vitium", keyword: "taint", emoji: "☣️", parents: ["perditio", "praecantatio"], colorHex: "5A3A55"),
        Aspect(id: "vitreus", name: "Vitreus", keyword: "crystal", emoji: "💎", parents: ["ordo", "terra"], colorHex: "BFE0E8"),
        Aspect(id: "volatus", name: "Volatus", keyword: "flight", emoji: "🪶", parents: ["aer", "motus"], colorHex: "A8C9E0")
    ]
}
