import SwiftUI

struct UpgradesView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerPanel
                ForEach(UpgradeCatalog.all) { upgrade in
                    upgradeRow(upgrade)
                }
            }
            .padding(20)
        }
        .background(ApothecaryBackground())
        .navigationTitle("Upgrades")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.backgroundTop, for: .navigationBar)
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(game.save?.skint ?? 0) skint")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Text("Invest profit in your shop. Upgrades are permanent and tier up in price.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }

    private func upgradeRow(_ upgrade: Upgrade) -> some View {
        let level = game.save?.upgradeLevel(upgrade.kind) ?? 0
        let price = upgrade.price(currentLevel: level)
        let affordable = price.map { (game.save?.skint ?? 0) >= $0 } ?? false

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: upgrade.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(upgrade.name)
                        .font(.subheadline.weight(.semibold))
                    Text("Level \(level) / \(upgrade.maxLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(upgrade.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let price {
                Button {
                    game.buyUpgrade(upgrade)
                } label: {
                    Label("Buy · \(price) skint", systemImage: "cart.fill.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!affordable)
            } else {
                Label("Maxed out", systemImage: "checkmark.seal.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8))
    }
}
