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
            plate
            if !isReceded {
                symbol
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : color)
                    .monospacedDigit()
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .opacity(isReceded ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.22), value: isSelected)
        .animation(.easeInOut(duration: 0.25), value: isReceded)
    }

    @ViewBuilder
    private var plate: some View {
        let fill = isReceded ? color.opacity(0.45) : (isSelected ? color : Color.white)
        let line = isSelected ? Color.white : color
        switch role {
        case .stayMorning, .stayEvening:
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .strokeBorder(line, lineWidth: isSelected ? 2 : 1.5)
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(isReceded ? 0 : 0.16), radius: 3, y: 1)
        default:
            Circle()
                .fill(fill)
                .overlay {
                    Circle()
                        .strokeBorder(line, lineWidth: isSelected ? 2 : 1.5)
                }
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(isReceded ? 0 : 0.16), radius: 3, y: 1)
        }
    }

    @ViewBuilder
    private var symbol: some View {
        if let number {
            Text("\(number)")
        } else if role.isTransferEndpoint {
            Image(systemName: "airplane")
        } else if role.isStay {
            Image(systemName: "bed.double.fill")
        } else {
            Image(systemName: "smallcircle.filled.circle")
        }
    }

    private var size: CGFloat {
        if isReceded { return 12 }
        if isCrowded { return isSelected ? 26 : RituTheme.crowdedPinSize }
        return isSelected ? 34 : RituTheme.pinSize
    }

    private var fontSize: CGFloat { isCrowded ? 11 : 13 }
}

struct UnscheduledAnnotationView: View {
    var isSelected: Bool

    var body: some View {
        Circle()
            .strokeBorder(
                Color.primary.opacity(isSelected ? 0.8 : 0.45),
                style: StrokeStyle(lineWidth: 1.5, dash: [2.4, 2.2])
            )
            .background(Circle().fill(Color(.systemBackground).opacity(0.92)))
            .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
            .accessibilityLabel(String(localized: "layer.unscheduled"))
    }
}
