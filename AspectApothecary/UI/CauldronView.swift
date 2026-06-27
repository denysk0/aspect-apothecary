import SwiftUI

struct CauldronView: View {
    @Environment(GameState.self) private var game

    private var graph: AspectGraph { game.engine.graph }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(game.save?.skint ?? 0) skint")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                ownedPanel
                shopPanel
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("The Cauldron")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var ownedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your Stores", systemImage: "shippingbox")
                .font(.headline)

            if game.ownedItems.isEmpty {
                Text("No items. Buy some below, then toss them in.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(game.ownedItems, id: \.item.id) { owned in
                    itemRow(owned.item, trailing: {
                        Button {
                            game.tossItem(owned.item)
                        } label: {
                            Label("Toss ×\(owned.quantity)", systemImage: "flame")
                        }
                        .buttonStyle(.borderedProminent)
                    })
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private var shopPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Market", systemImage: "cart")
                .font(.headline)

            ForEach(CauldronCatalog.items) { item in
                itemRow(item, trailing: {
                    Button {
                        game.buyItem(item)
                    } label: {
                        Text("\(item.priceSkint) skint")
                    }
                    .buttonStyle(.bordered)
                    .disabled((game.save?.skint ?? 0) < item.priceSkint)
                })
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private func itemRow<Trailing: View>(_ item: CauldronItem, @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                    Text(item.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailing()
            }

            HStack(spacing: 6) {
                ForEach(item.yield, id: \.aspect) { entry in
                    HStack(spacing: 4) {
                        Text(graph.aspectEmoji(entry.aspect))
                            .font(.caption)
                        Text("\(graph.aspectName(entry.aspect)) ×\(entry.quantity)")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Theme.cardSunken, in: Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}
