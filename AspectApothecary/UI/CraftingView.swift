import SwiftUI

struct CraftingView: View {
    @Environment(GameState.self) private var game
    @State private var selectedAspect: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let target = game.target {
                    boardPanel(target: target)
                    recipePanel
                    palettePanel
                } else {
                    Text("No active order. Return to the counter for a new one.")
                        .foregroundStyle(Theme.inkSoft)
                        .apothecaryCard()
                }
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .safeAreaInset(edge: .bottom) {
            if game.target != nil { actionBar }
        }
        .navigationTitle("Crafting Table")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private func boardPanel(target: PuzzleTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Link \(anchorNames(target)) to \(game.engine.graph.aspectName(target.targetAspect))")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            CraftingBoardView(
                graph: game.engine.graph,
                target: target,
                placements: game.placements,
                onTapCell: { handleTap($0) }
            )

            if let hint = game.autoBuildHint {
                Label(hint, systemImage: "wand.and.stars")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .apothecaryCard()
    }

    private var recipePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Recipe", systemImage: "list.bullet.clipboard", tint: Theme.sage)
            Text("What the customer's needs translate to on the board.")
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)

            ForEach(game.revealedFacts) { fact in
                Label {
                    Text(recipeNote(for: fact.kind)).foregroundStyle(Theme.ink)
                } icon: {
                    Image(systemName: iconName(for: fact.kind)).foregroundStyle(color(for: fact.kind))
                }
                .font(.footnote)
            }
        }
        .apothecaryCard()
    }

    private var palettePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Aspects", systemImage: "circle.grid.2x2.fill")

            Text("Tap an aspect, then an empty cell to place it. Tap a placed cell to take it back.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)

            NavigationLink(value: AppRoute.alchemy) {
                Label("Alchemy Bench", systemImage: "atom")
            }
            .buttonStyle(.bordered)
            .tint(Theme.sage)

            if game.ownedAspectIDs.isEmpty {
                Text("Out of aspects. Buy primals at the counter or combine at the bench.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    ForEach(game.ownedAspectIDs, id: \.self) { aspectID in
                        paletteChip(aspectID)
                    }
                }
            }
        }
        .apothecaryCard()
    }

    private func paletteChip(_ aspectID: String) -> some View {
        let isSelected = selectedAspect == aspectID
        return Button {
            selectedAspect = isSelected ? nil : aspectID
        } label: {
            HStack(spacing: 6) {
                Text(game.engine.graph.aspectEmoji(aspectID))
                Text(game.engine.graph.aspectName(aspectID))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? .white : Theme.ink)
                Spacer(minLength: 0)
                Text("\(game.count(of: aspectID))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : Theme.inkSoft)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Theme.violet : Theme.cardSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                game.refundPlacements()
                selectedAspect = nil
            } label: {
                Image(systemName: "trash")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.bordered)

            Button {
                game.autoBuild()
            } label: {
                Label("Auto-Build", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.bordered)
            .tint(Theme.violet)

            Button {
                Task { await game.craft() }
            } label: {
                Label("Craft", systemImage: "flask.fill")
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.sage)
            .disabled(game.placements.isEmpty && !canCraftEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardStroke).frame(height: 1)
        }
    }

    private func recipeNote(for kind: FactKind) -> String {
        let graph = game.engine.graph
        switch kind {
        case .requiresAspect(let aspect):
            return "Target: \(graph.aspectName(aspect))"
        case .forbidsAspect(let aspect):
            return "Forbidden: \(graph.aspectName(aspect)) (\(graph.aspectKeyword(aspect)))"
        }
    }

    private func anchorNames(_ target: PuzzleTarget) -> String {
        let names = target.anchors.map { game.engine.graph.aspectName($0.aspect) }
        return ListFormatter.localizedString(byJoining: names)
    }

    private var canCraftEmpty: Bool {
        guard let target = game.target else { return false }
        return game.engine.validate(placements: game.placements, target: target).isValid
    }

    private func handleTap(_ hex: Hex) {
        if game.placements[hex] != nil {
            game.clear(at: hex)
        } else if let selectedAspect, game.count(of: selectedAspect) > 0 {
            game.place(selectedAspect, at: hex)
        }
    }

    private func iconName(for kind: FactKind) -> String {
        switch kind {
        case .requiresAspect: "target"
        case .forbidsAspect: "nosign"
        }
    }

    private func color(for kind: FactKind) -> Color {
        switch kind {
        case .requiresAspect: Theme.sage
        case .forbidsAspect: Theme.danger
        }
    }
}
