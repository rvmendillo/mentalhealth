import SwiftUI
import UIKit
import RenewedMindKit

/// App colors with light and dark variants.
enum Palette {
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    /// Calm teal — the primary brand color.
    static let teal = dynamic(light: rgb(36, 112, 120), dark: rgb(110, 196, 201))
    /// Warm gold accent, for Scripture and highlights.
    static let gold = dynamic(light: rgb(176, 128, 38), dark: rgb(232, 190, 110))
    static let rose = dynamic(light: rgb(181, 82, 92), dark: rgb(235, 140, 148))
    static let backgroundTop = dynamic(light: rgb(246, 243, 236), dark: rgb(16, 22, 26))
    static let backgroundBottom = dynamic(light: rgb(232, 241, 241), dark: rgb(10, 14, 18))
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    static let verseBackground = dynamic(light: rgb(250, 245, 232), dark: rgb(38, 34, 24))

    static func color(for dimension: WellnessDimension) -> Color {
        switch dimension {
        case .spiritual: return gold
        case .emotional: return rose
        case .mental: return teal
        case .physical: return dynamic(light: rgb(64, 132, 74), dark: rgb(130, 200, 140))
        case .social: return dynamic(light: rgb(84, 98, 170), dark: rgb(150, 164, 235))
        case .purpose: return dynamic(light: rgb(140, 92, 160), dark: rgb(200, 160, 220))
        }
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(colors: [Palette.backgroundTop, Palette.backgroundBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// A rounded card container used throughout the app.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct SectionLabel: View {
    let title: String
    var systemImage: String?
    var color: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title.uppercased())
        }
        .font(.caption.weight(.semibold))
        .tracking(0.8)
        .foregroundStyle(color)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Primary call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.teal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = Palette.teal

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(color.opacity(configuration.isPressed ? 0.22 : 0.12), in: Capsule())
            .contentShape(Capsule())
    }
}

/// Selectable capsule used for tags and filters.
struct Chip: View {
    let title: String
    var isSelected: Bool = false
    var color: Color = Palette.teal

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : color)
            .background(isSelected ? color : color.opacity(0.12), in: Capsule())
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Wraps subviews onto multiple lines, like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func phase() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    }
}

extension Theme {
    var color: Color {
        switch self {
        case .renewal, .peace, .rest: return Palette.teal
        case .joy, .gratitude, .hope, .purpose: return Palette.gold
        case .love, .comfort, .healing, .forgiveness: return Palette.rose
        case .identity, .strength, .courage, .connection: return Palette.color(for: .social)
        }
    }
}

extension Practice {
    var symbol: String {
        switch kind {
        case .breathing: return "wind"
        case .journal: return "square.and.pencil"
        case .timer: return "timer"
        case .guided: return "list.number"
        case .checklist: return "checklist"
        }
    }
}
