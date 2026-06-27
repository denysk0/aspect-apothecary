import SwiftUI

struct WorkshopView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let target = game.target {
                    introPanel
                    boardPanel(target: target)
                    if !game.workshopSteps.isEmpty {
                        logPanel
                    }
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
            if game.target != nil { controlBar }
        }
        .navigationTitle("Workshop")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var introPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Autonomous Apprentice", systemImage: "person.fill.badge.plus")
            Text("The apprentice solves the linking puzzle itself, one move at a time. It's capable but imperfect, watch it reason. A wrong link ruins the brew, but it never costs your aspects.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)
        }
        .apothecaryCard()
    }

    private func boardPanel(target: PuzzleTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Linking to \(game.engine.graph.aspectName(target.targetAspect))")
                .font(.headline)
                .foregroundStyle(Theme.ink)

            CraftingBoardView(
                graph: game.engine.graph,
                target: target,
                placements: game.placements,
                onTapCell: { _ in }
            )
            .allowsHitTesting(false)
        }
        .apothecaryCard()
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Apprentice's Thoughts", systemImage: "text.bubble.fill")

            ForEach(Array(game.workshopSteps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(Theme.violet.opacity(0.15)).frame(width: 26, height: 26)
                        Text("\(index + 1)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(Theme.violet)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.thought)
                            .font(.callout)
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Theme.cardSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if step.aspect != "-" {
                            Text("placed \(step.aspect)")
                                .font(.caption)
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
            }
        }
        .apothecaryCard()
    }

    private var controlBar: some View {
        VStack(spacing: 10) {
            if game.apprenticeWorking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("The apprentice is working…")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                .frame(maxWidth: .infinity)
            } else if let verdict = game.apprenticeVerdict {
                Text(verdict)
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 10) {
                    if !game.activeResolved {
                        Button {
                            Task { await game.runApprentice() }
                        } label: {
                            Label("Try Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 30)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.violet)
                    }
                    Button {
                        game.path = []
                    } label: {
                        Label("Back to Counter", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.sage)
                }
            } else if !game.activeResolved {
                Button {
                    Task { await game.runApprentice() }
                } label: {
                    Label("Send in the Apprentice", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.violet)
                .disabled(!game.canCraft)
            }

            if !game.canCraft && !game.activeResolved && game.apprenticeVerdict == nil {
                Text("Accept an order at the counter before the apprentice can start.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardStroke).frame(height: 1)
        }
    }
}
