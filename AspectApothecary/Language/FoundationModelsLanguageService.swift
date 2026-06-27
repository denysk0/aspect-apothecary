import CoreGraphics
import Foundation
import FoundationModels
import OSLog

struct FoundationModelsLanguageService: LanguageService {
    private let fallback = LocalLanguageService()
    private let logger = Logger(subsystem: "dev.denyak.AspectApothecary", category: "FoundationModels")
    private let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
    private static var didWarmUp = false

    var statusText: String {
        switch model.availability {
        case .available:
            "Foundation Models available"
        case .unavailable(let reason):
            "Foundation Models unavailable: \(reason.displayName)"
        }
    }

    func warmUpFoundationModels() async -> Bool {
        guard model.isAvailable else { return false }
        if Self.didWarmUp { return true }

        for attempt in 1...4 {
            do {
                _ = try await plainTextResponse(
                    to: "Say OK.",
                    instructions: "You are a concise assistant.",
                    maximumResponseTokens: 10
                )
                Self.didWarmUp = true
                return true
            } catch {
                logger.error("Foundation Models warm-up attempt \(attempt) failed: \(error.diagnosticDescription, privacy: .public)")
                if attempt < 4 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
                }
            }
        }

        return false
    }

    func makeOrder(guild: Guild, potion: PotionType, effect: String) async -> ClientOrder {
        guard model.isAvailable else {
            return await fallback.makeOrder(guild: guild, potion: potion, effect: effect)
        }

        let prompt = """
        Invent one memorable customer at a mage's potion shop in Poena.
        They belong to the \(guild.displayName). Give them a vivid, slightly eccentric
        personality fitting their guild, a quirk, an attitude, a way of speaking
        (nervous, smug, dramatic, gruff, sly).
        Pick a distinctive, uncommon personaName (avoid plain names like "John" or "Mira").
        For "voice", write 4-8 words describing HOW they talk, tone, cadence, a verbal
        tic or favourite oath, so later lines can stay in the same voice.
        Private truth, not for the customer's opening line: they need a
        \(potion.displayName) potion, which will \(effect).
        Write requestText as symptoms, consequences, worries, or a suspicious
        anecdote only. The customer must NOT say the potion name, must NOT say
        "I need a potion that will...", and must NOT state the desired effect as
        a solution. Make the mage ask follow-up questions to discover the need.
        Keep requestText under 35 words. No prices.
        Return a single JSON object with keys: personaName, voice, requestText, deadlineHint.
        """

        do {
            let content = try await respondWithRetry(to: prompt, generating: FMOrderFlavor.self, temperature: 0.7)
            let requestText = content.requestText
                .trimmed(or: "I've a delicate problem, mage, and I'd rather not say too much in the open.")
                .safeOpeningRequest(potion: potion, effect: effect)
            return ClientOrder(
                personaName: content.personaName.trimmed(or: "Mira Vey"),
                guild: guild,
                desiredPotion: potion,
                requestText: requestText,
                deadlineHint: content.deadlineHint?.trimmedNilIfEmpty,
                voice: content.voice?.trimmedNilIfEmpty,
                source: .foundationModels
            )
        } catch {
            return await fallback.makeOrder(guild: guild, potion: potion, effect: effect)
        }
    }

    func answerQuestion(order: ClientOrder, facts: [OrderFact], question: String, previousReplies: [String], alreadyRevealed: Set<String>) async -> CustomerReply {
        let fallbackService = fallback
        guard model.isAvailable else {
            return await fallbackService.answerQuestion(order: order, facts: facts, question: question, previousReplies: previousReplies, alreadyRevealed: alreadyRevealed)
        }

        let pick = facts.unlocked(by: question, alreadySaid: previousReplies, alreadyRevealed: alreadyRevealed)
        let allowedIDs = Set(facts.map(\.id))
        let saidLine = previousReplies.isEmpty
            ? "Nothing yet."
            : previousReplies.map { "- \"\($0)\"" }.joined(separator: "\n")

        let factTask: String
        if let pick {
            factTask = """
            You MUST reveal exactly this one fact (in your own words) and list its id "\(pick.id)":
            \(pick.hint)
            Do NOT mention any other requirement or restriction.
            """
        } else {
            factTask = """
            You have no NEW fact to add. Reply briefly in character with COLOUR, mood,
            urgency, or a small personal aside. Do NOT re-explain the problem from your
            opening request, do NOT state what potion you need, and reveal no fact ids.
            """
        }

        let prompt = """
        You are \(order.personaName) of the \(order.guild.displayName) in Poena, answering
        the mage who will craft your potion. Stay in character but be DIRECT and brief.
        \(voiceLine(order))
        Opening request: "\(order.requestText)"
        The mage just asked: "\(question)"
        \(factTask)
        Lines you already said, do NOT repeat or paraphrase these:
        \(saidLine)
        Rules:
        - Answer the mage's actual question. Never contradict your opening request.
        - Stay in your established voice.
        - Maximum TWO sentences. Never name alchemical aspects, prices, or game terms.
        Return a single JSON object with keys: text, revealedFactIDs (array of fact ids).
        """

        do {
            let content = try await respondWithRetry(
                to: prompt,
                generating: FMCustomerReply.self,
                temperature: 0.3,
                maximumResponseTokens: 70
            )
            let text = content.text.trimmed(or: "")
            let revealed = content.revealedFactIDs.filter { allowedIDs.contains($0) }

            let isRepetitive = text.isEmpty
                || text.isSimilar(to: order.requestText)
                || previousReplies.contains { text.isSimilar(to: $0) }
            let isRamble = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count > 45
            let wrongReveal = pick.map { revealed != [$0.id] } ?? !revealed.isEmpty
            let leaksOtherFacts = text.leaksHiddenFacts(from: facts, except: pick)

            if isRepetitive || isRamble || wrongReveal || leaksOtherFacts {
                return await dialogueOrOffline(
                    order: order,
                    facts: facts,
                    question: question,
                    previousReplies: previousReplies,
                    alreadyRevealed: alreadyRevealed
                )
            }

            return CustomerReply(
                text: text,
                revealedFactIDs: pick.map { [$0.id] } ?? [],
                source: .foundationModels
            )
        } catch {
            return await dialogueOrOffline(
                order: order,
                facts: facts,
                question: question,
                previousReplies: previousReplies,
                alreadyRevealed: alreadyRevealed
            )
        }
    }

    private func dialogueOrOffline(order: ClientOrder, facts: [OrderFact], question: String, previousReplies: [String], alreadyRevealed: Set<String>) async -> CustomerReply {
        if let reply = try? await plainTextDialogue(order: order, facts: facts, question: question, previousReplies: previousReplies, alreadyRevealed: alreadyRevealed) {
            return reply
        }
        return await fallback.answerQuestion(order: order, facts: facts, question: question, previousReplies: previousReplies, alreadyRevealed: alreadyRevealed)
    }

    func describePotion(type: PotionType, quality: Double) async -> PotionDescription {
        guard model.isAvailable else {
            return await fallback.describePotion(type: type, quality: quality)
        }

        let prompt = """
        Write English flavor text for a crafted potion.
        The potion \(type.effectSummary).
        Engine quality: \(quality.formatted(.number.precision(.fractionLength(2)))).
        Describe ONLY that effect; do not invent any other use for it.
        Do not invent gameplay numbers, percentages, or durations. Keep properties under 30 words.
        Return a single JSON object with keys: name, properties.
        """

        do {
            let content = try await respondWithRetry(to: prompt, generating: FMPotionDescription.self)

            return PotionDescription(
                name: content.name.trimmed(or: "\(type.displayName) Phial"),
                properties: content.properties.trimmed(or: "A deterministic potion whose flavor text came from Foundation Models."),
                source: .foundationModels
            )
        } catch {
            return await fallback.describePotion(type: type, quality: quality)
        }
    }

    func writeReview(order: ClientOrder, quality: Double) async -> Review {
        guard model.isAvailable else {
            return await fallback.writeReview(order: order, quality: quality)
        }

        let expectedTone = if quality >= 0.8 {
            "praise"
        } else if quality >= 0.5 {
            "neutral"
        } else {
            "complaint"
        }

        let prompt = """
        Write one short English customer review for a potion shop.
        Customer: \(order.personaName) of the \(order.guild.displayName).
        \(voiceLine(order))
        The potion they bought \(order.desiredPotion.effectSummary).
        The review MUST be about that exact effect and how well it worked, written in
        the customer's own voice.
        Do NOT invent any other use for the potion (no battles, no unrelated tasks)
        unless the stated effect already covers it.
        Tone must be exactly: \(expectedTone). Do not change the tone or judge quality yourself.
        One or two sentences. Never name alchemical aspects or game terms.
        Return a single JSON object with keys: text, tone.
        """

        do {
            let content = try await respondWithRetry(to: prompt, generating: FMReview.self)
            let tone = ReviewTone(rawValue: content.tone) ?? ReviewTone(rawValue: expectedTone) ?? .neutral

            return Review(
                text: content.text.trimmed(or: "\(order.personaName) leaves a concise guild review."),
                tone: tone,
                source: .foundationModels
            )
        } catch {
            return await fallback.writeReview(order: order, quality: quality)
        }
    }

    func mapObjectToAspects(labels: [String], vocabulary: [AspectVocabularyEntry]) async -> ScanSuggestion {
        let fallbackService = fallback
        guard model.isAvailable, !labels.isEmpty else {
            return await fallbackService.mapObjectToAspects(labels: labels, vocabulary: vocabulary)
        }

        let allowedIDs = Set(vocabulary.map(\.id))
        let vocabularyLines = vocabulary.map { "- \($0.id): \($0.keyword)" }.joined(separator: "\n")
        let prompt = """
        A real-world object was photographed and recognized as: \(labels.joined(separator: ", ")).
        You assign alchemical aspects to objects in a fantasy apothecary.
        Choose 1 to 3 aspects from this list whose meaning best fits the object.
        Use only ids from this list, never invent ids:
        \(vocabularyLines)
        Return a single JSON object with keys: aspects (array of chosen ids), rationale (one short English sentence).
        """

        do {
            let content = try await respondWithRetry(to: prompt, generating: FMScanMapping.self)
            let valid = content.aspects.filter { allowedIDs.contains($0) }
            guard !valid.isEmpty else {
                return await fallbackService.mapObjectToAspects(labels: labels, vocabulary: vocabulary)
            }
            return ScanSuggestion(
                aspectIDs: valid,
                rationale: content.rationale.trimmed(or: "The bench distills those essences from it."),
                source: .foundationModels
            )
        } catch {
            return await fallbackService.mapObjectToAspects(labels: labels, vocabulary: vocabulary)
        }
    }

    func decideApprenticeMove(essence: String, unconnected: [String], forbidden: [String], options: [ApprenticeMoveOption]) async -> ApprenticeDecision {
        let fallbackService = fallback
        guard model.isAvailable, !options.isEmpty else {
            return await fallbackService.decideApprenticeMove(essence: essence, unconnected: unconnected, forbidden: forbidden, options: options)
        }

        let optionLines = options
            .map { "\($0.index): place \($0.aspect) (links to \($0.linksTo))" }
            .joined(separator: "\n")
        let avoidLine = forbidden.isEmpty
            ? "Nothing is off-limits."
            : "FORBIDDEN, never pick an option whose aspect is one of these, it RUINS the brew: \(forbidden.joined(separator: ", "))."
        let prompt = """
        You are an apprentice alchemist solving a Thaumcraft-style aspect-linking board.
        Goal: build one connected legal network from the central essence \(essence)
        to every required aspect.
        Rules:
        - Each option is already a legal placement; choose by strategy, not legality.
        - A useful move should connect an unconnected required aspect toward \(essence),
          or extend the connected network toward an unconnected required aspect.
        - Prefer the move that makes the most progress toward an unconnected required
          aspect; when unsure, the earliest-listed option is usually the best one.
        - Prefer moves that link to named neighbors different from the placed aspect.
        - Avoid duplicate/self-links like "Aer to Aer" unless every other option is worse.
        - Never claim a move connects to an aspect unless that aspect appears in that option.
        - If everything is already connected, set done true; otherwise choose one option.
        Still unconnected: \(unconnected.isEmpty ? "none" : unconnected.joined(separator: ", ")).
        \(avoidLine)
        Choose ONE move by its index that best makes progress:
        \(optionLines)
        Return a single JSON object with keys: index (one of the numbers above),
        thought (one short first-person sentence that mentions only the chosen option's
        aspect and listed links), done (boolean).
        """

        do {
            let content = try await respondWithRetry(
                to: prompt,
                generating: FMApprenticeDecision.self,
                temperature: 0.15,
                maximumResponseTokens: 60
            )
            if content.done {
                return ApprenticeDecision(chosenIndex: nil, thought: content.thought.trimmed(or: "Looks connected to me."), finished: true, source: .foundationModels)
            }
            let valid = options.contains { $0.index == content.index }
            return ApprenticeDecision(
                chosenIndex: valid ? content.index : options.first?.index,
                thought: content.thought.trimmed(or: "Let me try this link."),
                finished: false,
                source: .foundationModels
            )
        } catch {
            return await fallbackService.decideApprenticeMove(essence: essence, unconnected: unconnected, forbidden: forbidden, options: options)
        }
    }

    func runDiagnostics() async -> String {
        let availability = statusText

        guard model.isAvailable else {
            return "\(availability). No generation attempted."
        }

        var results: [String] = [availability]

        let warmed = await warmUpFoundationModels()
        results.append("Permissive warm-up \(warmed ? "OK" : "failed")")

        await appendPlainTextDiagnostic(
            label: "Permissive guardrails plain text",
            model: model,
            to: &results
        )

        do {
            let content = try await respondWithRetry(
                to: "Say OK. Return a single JSON object with key: message.",
                generating: FMDiagnostic.self
            )
            results.append("Permissive plain JSON decode OK: \(content.message)")
        } catch {
            results.append("Permissive plain JSON decode failed: \(error.diagnosticDescription)")
        }

        await appendVisionDiagnostic(to: &results)

        results.append("Default guardrails skipped: known to hit SensitiveContentAnalysisML error 15 on this runtime.")
        results.append("Structured skipped: the app intentionally avoids @Generable and uses permissive plain text plus JSONDecoder instead.")
        results.append("Image input skipped: text generation must work first; image probes add a separate model-load path.")

        let diagnostic = results.joined(separator: "\n")
        logger.error("Foundation Models diagnostic:\n\(diagnostic, privacy: .public)")
        return diagnostic
    }

    private func appendVisionDiagnostic(to results: inout [String]) async {
        guard let image = makeProbeImage() else {
            results.append("Vision classify skipped: could not build a test image.")
            return
        }
        do {
            let labels = try await VisionRecognizer().classify(image)
            results.append("Vision classify OK: [\(labels.joined(separator: ", "))]")

            let engine = PuzzleEngine.standard
            let suggestion = await mapObjectToAspects(labels: labels, vocabulary: engine.aspectVocabulary)
            let reward = engine.scanReward(for: suggestion.aspectIDs)
            let rewardText = reward
                .map { "\(engine.graph.aspectName($0.key))×\($0.value)" }
                .sorted()
                .joined(separator: ", ")
            results.append("Scan map OK: ids=\(suggestion.aspectIDs) -> grant=[\(rewardText)]")
        } catch {
            results.append("Vision classify failed: \(error.diagnosticDescription)")
        }
    }

    private func makeProbeImage() -> CGImage? {
        let side = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(CGColor(red: 0.85, green: 0.2, blue: 0.15, alpha: 1))
        context.fillEllipse(in: CGRect(x: 12, y: 12, width: 40, height: 40))
        return context.makeImage()
    }

    private func appendPlainTextDiagnostic(
        label: String,
        model: SystemLanguageModel,
        to results: inout [String]
    ) async {
        do {
            let response = try await plainTextResponse(
                model: model,
                to: "Say OK.",
                instructions: "You are a concise assistant.",
                maximumResponseTokens: 10
            )

            results.append("\(label) OK: \(response)")
        } catch {
            results.append("\(label) failed: \(error.diagnosticDescription)")
        }
    }

    private func respondWithRetry<Content: Decodable>(
        to prompt: String,
        generating type: Content.Type,
        temperature: Double = 0.4,
        maximumResponseTokens: Int = 180
    ) async throws -> Content {
        _ = await warmUpFoundationModels()

        var lastError: Error?
        for attempt in 1...4 {
            do {
                return try await respond(to: prompt, generating: type, temperature: temperature, maximumResponseTokens: maximumResponseTokens)
            } catch {
                lastError = error
                logger.error("Foundation Models JSON attempt \(attempt) failed: \(error.diagnosticDescription, privacy: .public)")
                if attempt < 4 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 700_000_000)
                }
            }
        }

        throw lastError ?? FoundationModelsLanguageError.emptyRetry
    }

    private func respond<Content: Decodable>(
        to prompt: String,
        generating type: Content.Type,
        temperature: Double = 0.4,
        maximumResponseTokens: Int = 180
    ) async throws -> Content {
        let session = LanguageModelSession(
            model: model,
            instructions: """
            You write concise English flavor text for a deterministic alchemy tycoon.
            You never decide mechanics, rewards, validation, economy, or scores.
            Return only valid minified JSON. Do not wrap it in Markdown.
            """
        )

        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(
                samplingMode: temperature < 0.25 ? .greedy : .random(top: 3),
                temperature: temperature,
                maximumResponseTokens: maximumResponseTokens
            )
        )

        let json = try response.content.extractedJSONObject()
        return try JSONDecoder().decode(Content.self, from: Data(json.utf8))
    }

    private func plainTextResponse(
        model: SystemLanguageModel? = nil,
        to prompt: String,
        instructions: String,
        maximumResponseTokens: Int,
        temperature: Double = 0.0
    ) async throws -> String {
        let session = LanguageModelSession(
            model: model ?? self.model,
            instructions: instructions
        )
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(
                samplingMode: temperature > 0 ? .random(top: 3) : .greedy,
                temperature: temperature,
                maximumResponseTokens: maximumResponseTokens
            )
        )
        return response.content
    }

    private func plainTextDialogue(
        order: ClientOrder,
        facts: [OrderFact],
        question: String,
        previousReplies: [String],
        alreadyRevealed: Set<String>
    ) async throws -> CustomerReply {
        let pick = facts.unlocked(by: question, alreadySaid: previousReplies, alreadyRevealed: alreadyRevealed)
        let saidLine = previousReplies.isEmpty
            ? "Nothing yet."
            : previousReplies.map { "- \"\($0)\"" }.joined(separator: "\n")
        let task = pick.map { "Tell the mage, in character, this single fact: \($0.hint)" }
            ?? """
            You have no NEW fact to add. Reply briefly in character with colour, your
            mood, urgency, or a small personal aside. Do NOT re-explain or restate the
            problem from your opening request, and reveal no new facts. A short "aye,
            that's the heart of it" plus a bit of personality is ideal.
            """
        let prompt = """
        You are \(order.personaName) of the \(order.guild.displayName) in Poena, replying to
        the mage who will craft your potion. Stay in character: keep your mood and quirks.
        \(voiceLine(order))
        Your opening request was: "\(order.requestText)"
        The mage just asked: "\(question)"
        \(task)
        Do not repeat or paraphrase these earlier lines word for word:
        \(saidLine)
        Reply in ONE or TWO short sentences. Never contradict your opening request.
        Never name alchemical aspects, prices, or game terms. Plain text only, no JSON.
        """
        let raw = try await plainTextResponse(
            to: prompt,
            instructions: dialogueInstructions,
            maximumResponseTokens: 70,
            temperature: 0.5
        )
        let text = raw.trimmed(or: "")
        guard !text.isEmpty,
              !text.isSimilar(to: order.requestText),
              !previousReplies.contains(where: { text.isSimilar(to: $0) }),
              !text.leaksHiddenFacts(from: facts, except: pick)
        else {
            throw FoundationModelsLanguageError.emptyRetry
        }
        return CustomerReply(
            text: text,
            revealedFactIDs: pick.map { [$0.id] } ?? [],
            source: .foundationModels
        )
    }

    private func voiceLine(_ order: ClientOrder) -> String {
        guard let voice = order.voice, !voice.isEmpty else { return "" }
        return "Your voice (keep it consistent): \(voice)."
    }

    private var dialogueInstructions: String {
        """
        You roleplay a single customer in an alchemy shop. You only write short
        in-character English dialogue. You never decide mechanics, rewards, or scores,
        and you never name alchemical aspects or game terms.
        """
    }
}

private struct FMOrderFlavor: Decodable {
    let personaName: String

    let voice: String?

    let requestText: String

    let deadlineHint: String?
}

private struct FMCustomerReply: Decodable {
    let text: String

    let revealedFactIDs: [String]

    enum CodingKeys: String, CodingKey {
        case text
        case revealedFactIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = (try? container.decode(String.self, forKey: .text)) ?? ""
        if let strings = try? container.decode([String].self, forKey: .revealedFactIDs) {
            revealedFactIDs = strings
        } else if let mixed = try? container.decode([FlexibleStringValue].self, forKey: .revealedFactIDs) {
            revealedFactIDs = mixed.map(\.stringValue)
        } else {
            revealedFactIDs = []
        }
    }
}

private struct FlexibleStringValue: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            stringValue = value
        } else if let value = try? container.decode(Int.self) {
            stringValue = String(value)
        } else if let value = try? container.decode(Double.self) {
            stringValue = String(value)
        } else {
            stringValue = ""
        }
    }
}

private struct FMPotionDescription: Decodable {
    let name: String

    let properties: String
}

private struct FMReview: Decodable {
    let text: String

    let tone: String
}

private struct FMApprenticeDecision: Decodable {
    let index: Int

    let thought: String

    let done: Bool

    enum CodingKeys: String, CodingKey {
        case index
        case thought
        case done
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        thought = (try? container.decode(String.self, forKey: .thought)) ?? ""
        if let value = try? container.decode(Int.self, forKey: .index) {
            index = value
        } else if let text = try? container.decode(String.self, forKey: .index), let value = Int(text) {
            index = value
        } else {
            index = 0
        }
        if let value = try? container.decode(Bool.self, forKey: .done) {
            done = value
        } else if let text = try? container.decode(String.self, forKey: .done) {
            done = (text as NSString).boolValue
        } else {
            done = false
        }
    }
}

private struct FMScanMapping: Decodable {
    let aspects: [String]

    let rationale: String
}

private struct FMDiagnostic: Decodable {
    let message: String
}

private extension SystemLanguageModel.Availability.UnavailableReason {
    var displayName: String {
        switch self {
        case .deviceNotEligible:
            "device not eligible"
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence not enabled"
        case .modelNotReady:
            "model not ready"
        @unknown default:
            "unknown reason"
        }
    }
}

private extension String {
    func trimmed(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }

    var trimmedNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func isSimilar(to other: String, threshold: Double = 0.5) -> Bool {
        let a = wordSet
        let b = other.wordSet
        guard !a.isEmpty, !b.isEmpty else { return false }
        let intersection = Double(a.intersection(b).count)
        let union = Double(a.union(b).count)
        guard union > 0 else { return false }
        return intersection / union >= threshold
    }

    func leaksHiddenFacts(from facts: [OrderFact], except allowed: OrderFact?) -> Bool {
        for fact in facts where fact.id != allowed?.id {
            if localizedCaseInsensitiveContains(fact.note) { return true }
            if isSimilar(to: fact.hint, threshold: 0.35) { return true }
        }
        return false
    }

    private var wordSet: Set<String> {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let cleaned = String(unicodeScalars.filter { allowed.contains($0) }).lowercased()
        return Set(cleaned.split(separator: " ").map(String.init).filter { $0.count > 3 })
    }

    func safeOpeningRequest(potion: PotionType, effect: String) -> String {
        let lowered = lowercased()
        let forbiddenTerms = [
            potion.displayName.lowercased(),
            potion.rawValue.lowercased(),
            "i need a potion",
            "need a potion",
            "potion that will",
            "that will \(effect.lowercased())"
        ] + effect
            .lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 5 }

        let leaked = forbiddenTerms.contains { lowered.contains($0) }
        guard !leaked else {
            return potion.vagueRequest
        }
        return self
    }

    func extractedJSONObject() throws -> String {
        let text = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = text.firstIndex(of: "{") else {
            throw FoundationModelsLanguageError.invalidJSON(text)
        }

        var depth = 0
        var isInString = false
        var isEscaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if isEscaped {
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else if character == "\"" {
                isInString.toggle()
            } else if !isInString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                }
            }

            index = text.index(after: index)
        }

        throw FoundationModelsLanguageError.invalidJSON(text)
    }
}

private enum FoundationModelsLanguageError: Error {
    case invalidJSON(String)
    case emptyRetry
}

private extension Error {
    var diagnosticDescription: String {
        (self as NSError).diagnosticDescription()
    }
}

private extension NSError {
    func diagnosticDescription(depth: Int = 0) -> String {
        let nsError = self as NSError
        var parts = [
            "\(type(of: nsError))",
            "domain=\(nsError.domain)",
            "code=\(nsError.code)",
            nsError.localizedDescription
        ]

        let visibleUserInfo = nsError.userInfo.filter { key, _ in
            key != NSMultipleUnderlyingErrorsKey && key != NSUnderlyingErrorKey
        }
        if !visibleUserInfo.isEmpty {
            let userInfo = visibleUserInfo
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: "; ")
            parts.append("userInfo={\(userInfo)}")
        }

        let underlying = nsError.underlyingErrors
        if !underlying.isEmpty, depth < 4 {
            let descriptions = underlying
                .map { $0.diagnosticDescription(depth: depth + 1) }
                .joined(separator: " || ")
            parts.append("underlying=[\(descriptions)]")
        }

        return parts.joined(separator: " | ")
    }

    var underlyingErrors: [NSError] {
        var errors: [NSError] = []
        if let error = userInfo[NSUnderlyingErrorKey] as? NSError {
            errors.append(error)
        }
        if let multiple = userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError] {
            errors.append(contentsOf: multiple)
        }
        return errors
    }
}
