
import SwiftUI

enum RituTheme {
    /// Ink used for typography and chrome, in place of a colorful accent.
    static let ink = Color("AccentColor")

    static var tripNameFont: Font { .system(.title, design: .default, weight: .semibold) }
    static var titleFont: Font { .system(.title2, design: .default, weight: .semibold) }
    static var bodyFont: Font { .system(.body, design: .default) }
    static var captionFont: Font { .system(.caption, design: .default) }

    /// Tabular lining figures for clocks and durations.
    static var timeFont: Font {
        .system(.body, design: .default, weight: .medium).monospacedDigit()
    }

    static var compactTimeFont: Font {
        .system(.subheadline, design: .default, weight: .medium).monospacedDigit()
    }

    static var nextStopTimeFont: Font {
        .system(.headline, design: .default, weight: .semibold).monospacedDigit()
    }

    static var sheetCorner: CGFloat { 28 }
    static var cardCorner: CGFloat { 22 }
    static var pinSize: CGFloat { 30 }
    static var crowdedPinSize: CGFloat { 22 }
}

extension View {
    /// Corners follow the screen when they sit near it, and keep a quiet radius elsewhere.
    @ViewBuilder
    func rituClip(cornerRadius: CGFloat = RituTheme.cardCorner) -> some View {
        if #available(iOS 26.0, *) {
            clipShape(RituShape.panel(cornerRadius))
        } else {
            clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    func rituGlass(cornerRadius: CGFloat = RituTheme.sheetCorner) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: RituShape.panel(cornerRadius))
        } else {
            background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

@available(iOS 26.0, *)
enum RituShape {
    static func panel(_ minimumRadius: CGFloat) -> ConcentricRectangle {
        ConcentricRectangle(corners: .concentric(minimum: minimumRadius), isUniform: false)
    }
}
