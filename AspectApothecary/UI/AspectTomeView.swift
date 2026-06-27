import SwiftUI

struct AspectTomeView: View {
    @Environment(GameState.self) private var game

    private var graph: AspectGraph { game.engine.graph }

    private var primals: [String] {
        graph.allAspectIDs.filter { graph.aspect($0)?.parents.isEmpty == true }
    }

    private var derived: [String] {
        graph.allAspectIDs.filter { graph.aspect($0)?.parents.isEmpty == false }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(game.save?.knownAspects.count ?? 0) / \(graph.allAspectIDs.count) aspects discovered")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                section("Primal", ids: primals)
                section("Derived", ids: derived)
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("Aspect Tome")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private func section(_ title: String, ids: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(ids, id: \.self) { id in
                    entry(id)
                }
            }
        }
    }

    private func entry(_ id: String) -> some View {
        let known = game.isKnown(id)
        let parents = graph.aspect(id)?.parents ?? []

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(known ? graph.aspectEmoji(id) : "❓")
                Text(known ? graph.aspectName(id) : "???")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if known, game.count(of: id) > 0 {
                    Text("×\(game.count(of: id))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if known {
                if parents.isEmpty {
                    Text("Primal, cannot be crafted")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        component(parents[0])
                        Text("+").font(.caption).foregroundStyle(.secondary)
                        component(parents.count > 1 ? parents[1] : parents[0])
                    }
                }
            } else {
                Text("Undiscovered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
        .opacity(known ? 1 : 0.6)
    }

    private func component(_ id: String) -> some View {
        let known = game.isKnown(id)
        return HStack(spacing: 3) {
            Text(known ? graph.aspectEmoji(id) : "❓")
            Text(known ? graph.aspectName(id) : "?")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(Theme.cardSunken, in: Capsule())
    }
}
