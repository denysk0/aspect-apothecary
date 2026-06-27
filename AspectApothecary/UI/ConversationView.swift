import SwiftUI

struct ConversationView: View {
    @Environment(GameState.self) private var game
    @State private var customQuestion = ""

    private let presetQuestions = [
        "What exactly do you need this to do?",
        "What side effects are unacceptable?",
        "What matters most to you here?",
        "What is the real danger here?"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                customerCard
                confirmedPanel
                conversationPanel
                askPanel
                craftLink
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("The Customer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var customerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let order = game.order {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.violet.opacity(0.15)).frame(width: 48, height: 48)
                        Image(systemName: order.guild.icon)
                            .font(.title3)
                            .foregroundStyle(Theme.violet)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.personaName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text(order.guild.displayName)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer()
                }
                ChatBubble(text: order.requestText, speaker: .customer, source: order.source)
            } else {
                Text("No customer at the counter.")
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .apothecaryCard()
    }

    private var confirmedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What You've Confirmed", systemImage: "checklist", tint: Theme.sage)

            if game.revealedFacts.isEmpty {
                Text("Nothing confirmed yet. Ask questions to learn what they need, and what to avoid.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                let needs = game.revealedFacts.filter { !$0.isForbidden }
                let avoids = game.revealedFacts.filter { $0.isForbidden }

                if !needs.isEmpty {
                    confirmedGroup(title: "Needs", icon: "target", tint: Theme.sage, facts: needs)
                }
                if !avoids.isEmpty {
                    confirmedGroup(title: "Avoid", icon: "nosign", tint: Theme.danger, facts: avoids)
                }
            }
        }
        .apothecaryCard()
    }

    private func confirmedGroup(title: String, icon: String, tint: Color, facts: [OrderFact]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            ForEach(facts) { fact in
                Label {
                    Text(fact.note).foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: icon).foregroundStyle(tint)
                }
                .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var conversationPanel: some View {
        if !game.transcript.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(game.transcript) { entry in
                    ChatBubble(text: entry.question, speaker: .mage)
                    ChatBubble(text: entry.reply, speaker: .customer, source: entry.source)
                }
                if game.isAwaitingReply {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("\(game.order?.personaName ?? "The customer") is thinking…")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .apothecaryCard()
        }
    }

    private var askPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Questions", systemImage: "bubble.left.and.bubble.right.fill")
                Spacer()
                PatienceMeter(total: patienceTotal, remaining: game.questionsRemaining)
            }

            ForEach(presetQuestions, id: \.self) { question in
                let used = wasAsked(question)
                Button {
                    ask(question)
                } label: {
                    HStack {
                        Text(question)
                            .foregroundStyle(used ? Theme.inkSoft : Theme.ink)
                        Spacer()
                        if used {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.sage)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(Theme.violet)
                .disabled(!canAsk || used)
            }

            HStack {
                TextField("Ask your own question", text: $customQuestion)
                    .textFieldStyle(.roundedBorder)
                Button("Ask") {
                    ask(customQuestion)
                    customQuestion = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.violet)
                .disabled(!canAsk || customQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if game.questionsRemaining == 0 {
                Label("They're out of patience. Craft with what you know, or risk the unknowns.", systemImage: "flame")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
        .apothecaryCard()
    }

    private var craftLink: some View {
        VStack(spacing: 10) {
            NavigationLink(value: AppRoute.crafting) {
                Label("Go to the Crafting Table", systemImage: "hexagon.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)
            .disabled(!game.canCraft)

            Text("You already know the potion they want. Asking more uncovers what to avoid, get it wrong and the brew is ruined.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)

            Button(role: .destructive) {
                game.declineOrder()
            } label: {
                Label("Turn Them Away", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var patienceTotal: Int {
        max(game.questionsRemaining, game.save?.customerPatience ?? UpgradeCatalog.basePatience)
    }

    private func wasAsked(_ question: String) -> Bool {
        game.transcript.contains { $0.question.caseInsensitiveCompare(question) == .orderedSame }
    }

    private var canAsk: Bool {
        game.questionsRemaining > 0 && !game.isAwaitingReply
    }

    private func ask(_ question: String) {
        Task { await game.askQuestion(question) }
    }
}

private extension OrderFact {
    var isForbidden: Bool {
        if case .forbidsAspect = kind { return true }
        return false
    }
}
