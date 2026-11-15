
import SwiftUI

enum DayPalette {
    /// Refined, map-legible colors. Used only for days — not for chrome.
    private static let colors: [Color] = [
        Color(red: 0.72, green: 0.32, blue: 0.22), // terracotta
        Color(red: 0.28, green: 0.45, blue: 0.40), // olive
        Color(red: 0.27, green: 0.34, blue: 0.56), // indigo
        Color(red: 0.78, green: 0.52, blue: 0.22), // ochre
        Color(red: 0.22, green: 0.48, blue: 0.52), // teal
        Color(red: 0.48, green: 0.30, blue: 0.46), // plum
        Color(red: 0.35, green: 0.42, blue: 0.50), // slate
        Color(red: 0.62, green: 0.28, blue: 0.32), // brick
    ]

    static func color(forDayOffset offset: Int) -> Color {
        colors[abs(offset) % colors.count]
    }
}
