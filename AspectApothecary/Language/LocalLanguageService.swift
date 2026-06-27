import Foundation

struct LocalLanguageService: LanguageService {
    let statusText = "Local fallback text"

    func warmUpFoundationModels() async -> Bool {
        false
    }

    func makeOrder(guild: Guild, potion: PotionType, effect: String) async -> ClientOrder {
        ClientOrder(
            personaName: "Mira Vey",
            guild: guild,
            desiredPotion: potion,
            requestText: potion.vagueRequest,
            deadlineHint: "Before dusk",
            voice: "wary and plain-spoken, keeps things short"
        )
    }

    func answerQuestion(order: ClientOrder, facts: [OrderFact], question: String, previousReplies: [String], alreadyRevealed: Set<String>) async -> CustomerReply {
        let reveal = facts.unlocked(by: question, alreadySaid: previousReplies, alreadyRevealed: alreadyRevealed)

        guard let reveal else {
            let dodges = [
                "\(order.personaName) folds their arms. \"You know the shape of it now, mage. Get to mixing.\"",
                "\(order.personaName) shrugs. \"That's all I can tell you. The rest is your craft, not mine.\"",
                "\(order.personaName) sighs. \"I've said my piece. Don't make me repeat myself.\""
            ]
            let pick = dodges[previousReplies.count % dodges.count]
            return CustomerReply(text: pick, revealedFactIDs: [])
        }

        let lines: [String]
        if case .forbidsAspect = reveal.kind {
            let word = reveal.keyword
            lines = [
                "\(order.personaName) leans in: \"I can't abide \(word), keep it out of this, all of it.\"",
                "\(order.personaName) lowers their voice: \"No \(word). Call it a quirk, but mark it well.\"",
                "\(order.personaName) grimaces. \"Whatever you do, not a trace of \(word). I won't have it.\""
            ]
        } else {
            lines = [
                "\(order.personaName) leans in: \"\(reveal.note).\" That much you should know.",
                "\(order.personaName) lowers their voice: \"\(reveal.note), mark it well.\"",
                "\(order.personaName) nods slowly. \"\(reveal.note). Don't forget it.\""
            ]
        }
        let pick = lines[previousReplies.count % lines.count]
        return CustomerReply(text: pick, revealedFactIDs: [reveal.id])
    }

    func describePotion(type: PotionType, quality: Double) async -> PotionDescription {
        let prefix = quality > 0.8 ? "Pristine" : "Serviceable"

        return PotionDescription(
            name: "\(prefix) \(type.displayName) Phial",
            properties: "A compact potion prepared from linked aspects. Its effect is deterministic; only the wording is allowed to vary."
        )
    }

    func writeReview(order: ClientOrder, quality: Double) async -> Review {
        let tone: ReviewTone = if quality >= 0.8 {
            .praise
        } else if quality >= 0.5 {
            .neutral
        } else {
            .complaint
        }

        let text = switch tone {
        case .praise:
            "\(order.personaName) reports that the potion performed cleanly and improved the guild's trust."
        case .neutral:
            "\(order.personaName) says the potion worked, though the craft could have been tighter."
        case .complaint:
            "\(order.personaName) warns the guild that the potion was unstable."
        }

        return Review(text: text, tone: tone)
    }

    func mapObjectToAspects(labels: [String], vocabulary: [AspectVocabularyEntry]) async -> ScanSuggestion {
        let haystack = labels.joined(separator: " ").lowercased()
        let byKeyword = Dictionary(vocabulary.map { ($0.keyword, $0.id) }, uniquingKeysWith: { first, _ in first })

        var hits: [String] = []
        for entry in vocabulary where haystack.contains(entry.keyword) {
            hits.append(entry.id)
        }

        let associations: [(needle: String, keyword: String)] = [
            ("moon", "light"), ("sky", "air"), ("celestial", "light"), ("night", "darkness"),
            ("plant", "plant"), ("tree", "tree"), ("flower", "plant"), ("food", "life"),
            ("metal", "metal"), ("tool", "tool"), ("machine", "machine"), ("water", "water"),
            ("animal", "animal"), ("fire", "fire"), ("stone", "earth"), ("rock", "earth")
        ]
        for assoc in associations where haystack.contains(assoc.needle) {
            if let id = byKeyword[assoc.keyword] { hits.append(id) }
        }

        if hits.isEmpty, let fallback = byKeyword["order"] ?? vocabulary.first?.id {
            hits = [fallback]
        }

        return ScanSuggestion(
            aspectIDs: hits,
            rationale: "The bench reads this object as carrying those essences."
        )
    }

    func decideApprenticeMove(essence: String, unconnected: [String], forbidden: [String], options: [ApprenticeMoveOption]) async -> ApprenticeDecision {
        guard let first = options.first else {
            return ApprenticeDecision(chosenIndex: nil, thought: "No move presents itself; the apprentice stops.", finished: true)
        }
        return ApprenticeDecision(
            chosenIndex: first.index,
            thought: "Linking \(first.aspect) toward \(essence).",
            finished: false
        )
    }

    func runDiagnostics() async -> String {
        "Local fallback is active. Foundation Models was not used."
    }
}
