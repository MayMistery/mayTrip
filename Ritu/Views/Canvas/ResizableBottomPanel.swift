
import SwiftUI

enum PanelDetent: Equatable {
    case compact
    case medium
    case large
}

struct ResizableBottomPanel<Content: View>: View {
    @Binding var detent: PanelDetent
    var compactHeight: CGFloat = 156
    @ViewBuilder var content: (PanelDetent) -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let medium = max(geometry.size.height * 0.38, 240)
            let large = max(geometry.size.height - 56, 360)
            let height = currentHeight(medium: medium, large: large) - dragOffset

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content(detent)
                    .frame(height: max(compactHeight, height), alignment: .top)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 18, y: -4)
                    .ignoresSafeArea(edges: .bottom)
                    .overlay(alignment: .top) {
                        Color.clear
                            .frame(height: 32)
                            .contentShape(Rectangle())
                            .gesture(drag(medium: medium, large: large))
                            .accessibilityHidden(true)
                    }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func currentHeight(medium: CGFloat, large: CGFloat) -> CGFloat {
        switch detent {
        case .compact: compactHeight
        case .medium: medium
        case .large: large
        }
    }

    private func drag(medium: CGFloat, large: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let predicted = currentHeight(medium: medium, large: large) - value.predictedEndTranslation.height
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
                    detent = nearest(to: predicted, medium: medium, large: large)
                    dragOffset = 0
                }
            }
    }

    private func nearest(to height: CGFloat, medium: CGFloat, large: CGFloat) -> PanelDetent {
        let candidates: [(PanelDetent, CGFloat)] = [
            (.compact, compactHeight),
            (.medium, medium),
            (.large, large)
        ]
        return candidates.min(by: { abs($0.1 - height) < abs($1.1 - height) })?.0 ?? .medium
    }
}
