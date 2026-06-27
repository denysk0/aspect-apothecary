import SwiftUI
import UIKit

enum Theme {

    static let backgroundTop = Color.adaptive(light: "F4ECDB", dark: "1E1A24")
    static let backgroundBottom = Color.adaptive(light: "E6D7BC", dark: "131017")
    static let card = Color.adaptive(light: "FCF7EC", dark: "26212F")
    static let cardSunken = Color.adaptive(light: "F1E7D2", dark: "1C1825")
    static let cardStroke = Color.adaptive(light: "DBC9A4", dark: "3A3346")

    static let ink = Color.adaptive(light: "3A2E22", dark: "EDE6D8")
    static let inkSoft = Color.adaptive(light: "7A6A55", dark: "A99F8E")

    static let gold = Color.adaptive(light: "B07D1A", dark: "E2B956")
    static let sage = Color.adaptive(light: "5C7E54", dark: "8FB07F")
    static let violet = Color.adaptive(light: "6E46AE", dark: "B493DD")
    static let danger = Color.adaptive(light: "B23A48", dark: "E0707E")

    static let cornerRadius: CGFloat = 16
}

struct ApothecaryBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Theme.backgroundTop, Theme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct ApothecaryCard: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func apothecaryCard(padding: CGFloat = 16) -> some View {
        modifier(ApothecaryCard(padding: padding))
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var tint: Color = Theme.violet

    var body: some View {
        Label {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    var tint: Color = Theme.ink
    var caption: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.cardSunken, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
    }
}

struct TierBadge: View {
    let tier: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<max(tier, 1), id: \.self) { _ in
                Image(systemName: "star.fill")
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.gold)
        .accessibilityLabel("Tier \(tier)")
    }
}

struct PatienceMeter: View {
    let total: Int
    let remaining: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Image(systemName: index < remaining ? "flame.fill" : "flame")
                    .foregroundStyle(index < remaining ? Theme.gold : Theme.inkSoft.opacity(0.5))
            }
        }
        .font(.footnote)
        .accessibilityLabel("\(remaining) of \(total) patience left")
    }
}

struct ChatBubble: View {
    enum Speaker { case customer, mage }

    let text: String
    let speaker: Speaker
    var source: GenerationSource?

    var body: some View {
        HStack {
            if speaker == .mage { Spacer(minLength: 36) }
            Text(text)
                .font(speaker == .customer ? .callout : .subheadline)
                .foregroundStyle(speaker == .customer ? Theme.ink : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .clipShape(BubbleShape(tail: speaker))
                .accessibilityLabel(accessibility)
            if speaker == .customer { Spacer(minLength: 36) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch speaker {
        case .customer: Theme.cardSunken
        case .mage: Theme.violet
        }
    }

    private var accessibility: String {
        let who = speaker == .customer ? "Customer" : "You"
        guard let source else { return "\(who): \(text)" }
        let prov = source == .foundationModels ? "AI generated" : "offline fallback"
        return "\(who) (\(prov)): \(text)"
    }
}

private struct BubbleShape: Shape {
    let tail: ChatBubble.Speaker

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: 14, style: .continuous)
    }
}

extension Color {
    static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hexString: dark)
                : UIColor(hexString: light)
        })
    }
}

extension UIColor {
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255,
            green: CGFloat((value & 0x00FF00) >> 8) / 255,
            blue: CGFloat(value & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
