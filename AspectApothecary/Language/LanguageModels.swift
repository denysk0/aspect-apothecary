import Foundation

enum GenerationSource: Sendable {
    case foundationModels
    case fallback
}

struct ClientOrder: Identifiable {
    let id = UUID()
    let personaName: String
    let guild: Guild
    let desiredPotion: PotionType
    let requestText: String
    let deadlineHint: String?
    var voice: String?
    var source: GenerationSource = .fallback
}

struct PotionDescription {
    let name: String
    let properties: String
    var source: GenerationSource = .fallback
}

enum ReviewTone: String, Codable {
    case praise
    case neutral
    case complaint
}

struct Review {
    let text: String
    let tone: ReviewTone
    var source: GenerationSource = .fallback
}

struct CustomerReply {
    let text: String
    let revealedFactIDs: [String]
    var source: GenerationSource = .fallback
}

struct AspectVocabularyEntry: Sendable {
    let id: String
    let keyword: String
    let name: String
}

struct ScanSuggestion {
    let aspectIDs: [String]
    let rationale: String
    var source: GenerationSource = .fallback
}

struct ApprenticeMoveOption: Sendable {
    let index: Int
    let aspect: String
    let linksTo: String
}

struct ApprenticeDecision {
    let chosenIndex: Int?
    let thought: String
    let finished: Bool
    var source: GenerationSource = .fallback
}

@MainActor
protocol LanguageService {
    var statusText: String { get }

    func warmUpFoundationModels() async -> Bool
    func makeOrder(guild: Guild, potion: PotionType, effect: String) async -> ClientOrder
    func answerQuestion(order: ClientOrder, facts: [OrderFact], question: String, previousReplies: [String], alreadyRevealed: Set<String>) async -> CustomerReply
    func describePotion(type: PotionType, quality: Double) async -> PotionDescription
    func writeReview(order: ClientOrder, quality: Double) async -> Review
    func mapObjectToAspects(labels: [String], vocabulary: [AspectVocabularyEntry]) async -> ScanSuggestion
    func decideApprenticeMove(essence: String, unconnected: [String], forbidden: [String], options: [ApprenticeMoveOption]) async -> ApprenticeDecision
    func runDiagnostics() async -> String
}
