
import SwiftUI

struct StopAnnotationView: View {
    var number: Int?
    var role: StopRole
    var color: Color
    var isSelected: Bool
    var isReceded: Bool
    var isCrowded: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(isReceded ? 0.55 : 0.95), lineWidth: isSelected ? 2.5 : 1.5)
                }
                .shadow(color: .black.opacity(isReceded ? 0 : 0.22), radius: isSelected ? 5 : 3, y: 1)
            symbol
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(foreground)
                .monospacedDigit()
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .opacity(isReceded ? 0.38 : 1)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
        .animation(.easeInOut(duration: 0.28), value: isReceded)
    }

    @ViewBuilder
    private var symbol: some View {
        if let number {
            Text("\(number)")
        } else {
            Image(systemName: glyph)
        }
    }

    private var glyph: String {
        switch role {
        case .stayMorning, .stayEvening: "bed.double.fill"
        case .transferDeparture, .transferArrival: "airplane"
        case .sight, .custom: "smallcircle.filled.circle"
        }
    }

    private var fill: Color {
        if role.isStay { return color.opacity(isReceded ? 0.7 : 1) }
        return color
    }

    private var foreground: Color { .white }

    private var size: CGFloat {
        if isCrowded { return isSelected ? 26 : RituTheme.crowdedPinSize }
        return isSelected ? 32 : RituTheme.pinSize
    }

    private var fontSize: CGFloat { isCrowded ? 11 : 13 }
}

struct UnscheduledAnnotationView: View {
    var isSelected: Bool

    var body: some View {
        Circle()
            .strokeBorder(Color.primary.opacity(0.55), lineWidth: 1.6)
            .background(Circle().fill(Color(.systemBackground).opacity(0.92)))
            .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
            .accessibilityLabel(String(localized: "layer.unscheduled"))
    }
}
