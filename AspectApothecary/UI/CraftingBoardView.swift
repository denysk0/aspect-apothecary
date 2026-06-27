import SwiftUI

struct CraftingBoardView: View {
    let graph: AspectGraph
    let target: PuzzleTarget
    let placements: [Hex: String]
    let onTapCell: (Hex) -> Void

    private let boardHeight: CGFloat = 340

    var body: some View {
        GeometryReader { geo in
            let radius = CGFloat(target.boardRadius)
            let size = min(
                geo.size.width / (sqrt(3) * (2 * radius + 2)),
                geo.size.height / (1.5 * 2 * radius + 2)
            )
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                ForEach(target.cells) { hex in
                    cell(hex, size: size)
                        .position(position(of: hex, size: size, center: center))
                }
            }
        }
        .frame(height: boardHeight)
    }

    private func position(of hex: Hex, size: CGFloat, center: CGPoint) -> CGPoint {
        let x = size * sqrt(3) * (CGFloat(hex.q) + CGFloat(hex.r) / 2)
        let y = size * 1.5 * CGFloat(hex.r)
        return CGPoint(x: center.x + x, y: center.y + y)
    }

    @ViewBuilder
    private func cell(_ hex: Hex, size: CGFloat) -> some View {
        let width = sqrt(3) * size
        let height = 2 * size

        if target.blockedHexes.contains(hex) {
            HexagonShape()
                .fill(Color.primary.opacity(0.22))
                .overlay(
                    HexagonShape().strokeBorder(Color.primary.opacity(0.28), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "xmark")
                        .font(.system(size: max(7, size * 0.5), weight: .bold))
                        .foregroundStyle(Color.primary.opacity(0.35))
                )
                .frame(width: width, height: height)
        } else {
            let occupant = occupant(of: hex)
            let isLocked = target.lockedHexes.contains(hex)
            let hasConflict = occupant != nil && isConflicting(hex)

            HexagonShape()
                .fill(fillColor(for: occupant))
                .saturation(hasConflict ? 0.15 : 1)
                .overlay(
                    HexagonShape()
                        .strokeBorder(strokeColor(isLocked: isLocked, hasConflict: hasConflict),
                                      lineWidth: hasConflict || isLocked ? 3 : 1)
                )
                .overlay(label(for: occupant, isLocked: isLocked).padding(2))
                .frame(width: width, height: height)
                .contentShape(HexagonShape())
                .onTapGesture {
                    guard !isLocked else { return }
                    onTapCell(hex)
                }
        }
    }

    private func isConflicting(_ hex: Hex) -> Bool {
        guard let aspect = occupant(of: hex) else { return false }

        var hasNeighbor = false
        var hasLegalLink = false
        for neighbor in hex.neighbors() {
            guard let other = occupant(of: neighbor) else { continue }
            hasNeighbor = true
            if graph.canLink(aspect, other) { hasLegalLink = true; break }
        }
        return hasNeighbor && !hasLegalLink
    }

    @ViewBuilder
    private func label(for aspect: String?, isLocked: Bool) -> some View {
        if let aspect {
            VStack(spacing: 0) {
                Text(graph.aspectEmoji(aspect))
                    .font(.system(size: 13))
                Text(graph.aspectName(aspect))
                    .font(.system(size: 8, weight: .semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(radius: 1)
            }
        } else {
            Circle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 5, height: 5)
        }
    }

    private func occupant(of hex: Hex) -> String? {
        if hex == target.targetHex { return target.targetAspect }
        if let anchor = target.anchors.first(where: { $0.hex == hex }) { return anchor.aspect }
        return placements[hex]
    }

    private func fillColor(for aspect: String?) -> Color {
        guard let aspect, let hex = graph.aspect(aspect)?.colorHex else {
            return Color(.tertiarySystemGroupedBackground)
        }
        return Color(hex: hex)
    }

    private func strokeColor(isLocked: Bool, hasConflict: Bool) -> Color {
        if hasConflict { return .red }
        return isLocked ? .accentColor : Color.primary.opacity(0.15)
    }
}

struct HexagonShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    func path(in rect: CGRect) -> Path {
        let inset = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let w = inset.width
        let h = inset.height
        let x = inset.minX
        let y = inset.minY

        var path = Path()
        path.move(to: CGPoint(x: x + w / 2, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y + h / 4))
        path.addLine(to: CGPoint(x: x + w, y: y + h * 3 / 4))
        path.addLine(to: CGPoint(x: x + w / 2, y: y + h))
        path.addLine(to: CGPoint(x: x, y: y + h * 3 / 4))
        path.addLine(to: CGPoint(x: x, y: y + h / 4))
        path.closeSubpath()
        return path
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
