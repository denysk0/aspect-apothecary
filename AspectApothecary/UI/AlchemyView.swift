import SwiftUI

struct AlchemyView: View {
    @Environment(GameState.self) private var game
    @State private var first: String?
    @State private var second: String?
    @State private var message = "Pick two aspects to combine."

    private var graph: AspectGraph { game.engine.graph }

    private var resultAspect: String? {
        guard let first, let second else { return nil }
        return graph.combination(of: first, second)
    }

    private var canCombine: Bool {
        guard let first, let second, resultAspect != nil else { return false }
        return game.count(of: first) >= 1 && game.count(of: second) >= 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                benchPanel
                NavigationLink(value: AppRoute.tome) {
                    Label("Open the Aspect Tome", systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                libraryPanel
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("Alchemy Bench")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var benchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                slot(first) { first = nil; refreshMessage() }
                Image(systemName: "plus").foregroundStyle(.secondary)
                slot(second) { second = nil; refreshMessage() }
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                slot(resultAspect, isResult: true) { }
            }

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                combine()
            } label: {
                Label("Combine", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canCombine)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private func slot(_ aspect: String?, isResult: Bool = false, onClear: @escaping () -> Void) -> some View {
        let fill = aspect.flatMap { graph.aspect($0)?.colorHex }.map { Color(hex: $0) }
            ?? Theme.cardSunken

        return Button(action: onClear) {
            VStack(spacing: 1) {
                Text(aspect.map(graph.aspectEmoji) ?? "-")
                if let aspect {
                    Text(graph.aspectName(aspect))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(fill, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isResult ? Theme.violet : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(isResult)
    }

    private var libraryPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Inventory", systemImage: "books.vertical")
                .font(.headline)

            if game.ownedAspectIDs.isEmpty {
                Text("No aspects. Buy primals at the counter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                    ForEach(game.ownedAspectIDs, id: \.self) { aspectID in
                        Button {
                            select(aspectID)
                        } label: {
                            HStack(spacing: 6) {
                                Text(graph.aspectEmoji(aspectID))
                                Text(graph.aspectName(aspectID))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer(minLength: 0)
                                Text("\(game.count(of: aspectID))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(first == aspectID || second == aspectID ? .accentColor : .secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private func select(_ aspectID: String) {
        if first == aspectID { first = nil }
        else if second == aspectID { second = nil }
        else if first == nil { first = aspectID }
        else if second == nil { second = aspectID }
        else { first = second; second = aspectID }
        refreshMessage()
    }

    private func refreshMessage() {
        guard let first, let second else {
            message = "Pick two aspects to combine."
            return
        }
        if let child = graph.combination(of: first, second) {
            message = "These combine into \(graph.aspectName(child))."
        } else {
            message = "\(graph.aspectName(first)) and \(graph.aspectName(second)) do not combine."
        }
    }

    private func combine() {
        guard let first, let second, let child = game.combine(first, second) else { return }
        message = "Brewed \(graph.aspectName(child))."
        self.first = nil
        self.second = nil
    }
}
