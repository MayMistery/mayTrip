
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

    static var sheetCorner: CGFloat { 20 }
    static var pinSize: CGFloat { 28 }
    static var crowdedPinSize: CGFloat { 24 }
}
