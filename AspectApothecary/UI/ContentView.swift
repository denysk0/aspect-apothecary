import SwiftData
import SwiftUI

enum AppRoute: Hashable {
    case conversation
    case crafting
    case alchemy
    case cauldron
    case tome
    case scan
    case workshop
    case upgrades
}

struct AIBadge: View {
    enum Kind {
        case foundationModels
        case fallback
        case vision

        init(_ source: GenerationSource) {
            self = source == .foundationModels ? .foundationModels : .fallback
        }
    }

    let kind: Kind

    init(_ kind: Kind) { self.kind = kind }
    init(_ source: GenerationSource) { self.kind = Kind(source) }

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .accessibilityLabel(accessibility)
    }

    private var text: String {
        switch kind {
        case .foundationModels: "AI"
        case .fallback: "offline"
        case .vision: "Vision"
        }
    }

    private var icon: String {
        switch kind {
        case .foundationModels: "sparkles"
        case .fallback: "wifi.slash"
        case .vision: "camera.viewfinder"
        }
    }

    private var color: Color {
        switch kind {
        case .foundationModels: .purple
        case .fallback: .secondary
        case .vision: .blue
        }
    }

    private var accessibility: String {
        switch kind {
        case .foundationModels: "Generated live by on-device Foundation Models"
        case .fallback: "Local fallback text, the model was unavailable"
        case .vision: "Recognized by the on-device Vision classifier"
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var saves: [GameSave]
    @State private var game = GameState()

    private func ensureSave() -> GameSave {
        if let existing = saves.first { return existing }
        let created = GameSave()
        modelContext.insert(created)
        return created
    }

    var body: some View {
        @Bindable var game = game

        return NavigationStack(path: $game.path) {
            ShopfrontView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .conversation: ConversationView()
                    case .crafting: CraftingView()
                    case .alchemy: AlchemyView()
                    case .cauldron: CauldronView()
                    case .tome: AspectTomeView()
                    case .scan: ScanView()
                    case .workshop: WorkshopView()
                    case .upgrades: UpgradesView()
                    }
                }
        }
        .environment(game)
        .task {
            let save = ensureSave()
            game.save = save
            if game.queue.isEmpty && game.order == nil {
                game.startDay()
            }
            if ProcessInfo.processInfo.arguments.contains("--runFoundationModelsDiagnostics") {
                game.statusMessage = await game.language.runDiagnostics()
            }
        }
    }
}

struct ShopfrontView: View {
    @Environment(GameState.self) private var game

    private var hasActiveOrder: Bool {
        game.order != nil && !game.activeResolved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if hasActiveOrder {
                    orderPanel
                    orderActionPanel
                } else {
                    queuePanel
                }
                reputationPanel
                utilityPanel
                resultPanel
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .safeAreaInset(edge: .top) { hud }
        .navigationTitle("Aspect Apothecary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                StatPill(icon: "circle.hexagongrid.fill", value: "\(game.save?.skint ?? 0)", tint: Theme.gold, caption: "skint")
                StatPill(icon: "sun.max.fill", value: "Day \(game.save?.day ?? 1)", tint: Theme.violet)
                StatPill(icon: "house.fill", value: "\(game.rentDue)", tint: Theme.danger, caption: "rent tonight")
                Spacer(minLength: 0)
            }
            if let missed = game.save?.missedRent, missed > 0 {
                Label("Behind on rent ×\(missed)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.cardStroke).frame(height: 1)
        }
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Customers Waiting", systemImage: "person.3.fill")

            if game.queue.isEmpty {
                Text("The shop is quiet. Close up for the night when you're ready.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)

                Button {
                    game.endDay()
                } label: {
                    Label("Close Up · pay \(game.rentDue) rent", systemImage: "moon.stars.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.violet)
            } else {
                Text("Pick who to serve. Each is one job; once all are handled the day ends and rent is due.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)

                ForEach(game.queue) { customer in
                    Button {
                        Task { await game.acceptCustomer(customer) }
                    } label: {
                        customerRow(customer)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .apothecaryCard()
    }

    private func customerRow(_ customer: GameState.QueuedCustomer) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.violet.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: customer.entry.guild.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.violet)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(customer.entry.guild.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    TierBadge(tier: customer.entry.tier)
                    Text("pays \(customer.entry.basePriceSkint)+ skint")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
    }

    private var orderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "At the Counter", systemImage: "scroll")

            if let order = game.order {
                Text(order.personaName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    Image(systemName: order.guild.icon)
                        .font(.caption)
                    Text(order.guild.displayName)
                        .font(.footnote)
                }
                .foregroundStyle(Theme.inkSoft)
                Text("\"\(order.requestText)\"")
                    .font(.callout)
                    .italic()
                    .foregroundStyle(Theme.ink)
                if let deadlineHint = order.deadlineHint {
                    Label(deadlineHint, systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .apothecaryCard()
    }

    private var orderActionPanel: some View {
        VStack(spacing: 10) {
            NavigationLink(value: AppRoute.conversation) {
                Label("Talk to the Customer", systemImage: "bubble.left.and.bubble.right.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.violet)

            HStack(spacing: 10) {
                NavigationLink(value: AppRoute.crafting) {
                    Label("Craft", systemImage: "hexagon.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.sage)
                .disabled(!game.canCraft)

                if game.apprenticeUnlocked {
                    NavigationLink(value: AppRoute.workshop) {
                        Label("Apprentice", systemImage: "person.fill.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.violet)
                    .disabled(!game.canCraft)
                }
            }

            Button(role: .destructive) {
                game.declineOrder()
            } label: {
                Label("Turn Them Away", systemImage: "figure.walk")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var reputationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Standing with the Guilds", systemImage: "person.2.wave.2.fill")

            if let save = game.save {
                ForEach(Guild.allCases) { guild in
                    let stage = save.reputationStage(for: guild)
                    HStack(spacing: 10) {
                        Image(systemName: guild.icon)
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 22)
                        Text(guild.displayName)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 110, alignment: .leading)
                        reputationBar(stage: stage)
                        Text(stage.displayName)
                            .font(.caption2)
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 78, alignment: .trailing)
                    }
                }
            }
        }
        .apothecaryCard()
    }

    private func reputationBar(stage: ReputationStage) -> some View {
        let maxRaw = Double(ReputationStage.trust.rawValue)
        let fraction = maxRaw > 0 ? Double(stage.rawValue) / maxRaw : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardSunken)
                Capsule()
                    .fill(LinearGradient(colors: [Theme.violet.opacity(0.7), Theme.violet], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 8)
        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
    }

    private var utilityPanel: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            utilityTile(.alchemy, title: "Alchemy Bench", icon: "atom", tint: Theme.sage)
            utilityTile(.cauldron, title: "The Cauldron", icon: "cart.fill", tint: Theme.gold)
            utilityTile(.scan, title: "Scanning Bench", icon: "camera.viewfinder", tint: Theme.violet)
            utilityTile(.upgrades, title: "Upgrades", icon: "wrench.and.screwdriver.fill", tint: Theme.gold)
            utilityTile(.tome, title: "Aspect Tome", icon: "book.fill", tint: Theme.sage)
        }
    }

    private func utilityTile(_ route: AppRoute, title: String, icon: String, tint: Color) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultPanel: some View {
        let hasContent = game.pendingPayment != nil || game.potionDescription != nil || game.review != nil
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Counter", systemImage: "checkmark.seal.fill", tint: Theme.gold)

            Text(game.statusMessage)
                .font(.callout)
                .foregroundStyle(Theme.ink)

            if let options = game.pendingPayment {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How will they pay?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    ForEach(options) { option in
                        Button {
                            game.settlePayment(option)
                        } label: {
                            Label(option.label, systemImage: option.itemID == nil ? "dollarsign.circle.fill" : "shippingbox.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.gold)
                    }
                }
            }

            if let potionDescription = game.potionDescription {
                Divider().overlay(Theme.cardStroke)
                HStack(spacing: 10) {
                    if let potion = game.lastPotionType {
                        ZStack {
                            Circle().fill(Theme.sage.opacity(0.15)).frame(width: 40, height: 40)
                            Image(systemName: potion.icon)
                                .font(.title3)
                                .foregroundStyle(Theme.sage)
                        }
                    }
                    Text(potionDescription.name)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                }
                Text(potionDescription.properties)
                    .font(.callout)
                    .foregroundStyle(Theme.inkSoft)
            }

            if let review = game.review {
                Text(review.text)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
            }

            if !hasContent {
                Text("Crafted potions and reviews will appear here.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .apothecaryCard()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: GameSave.self, inMemory: true)
}
