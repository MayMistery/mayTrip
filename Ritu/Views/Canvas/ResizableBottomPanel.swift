import SwiftUI

enum PanelDetent: Equatable {
    case compact
    case medium
    case large

    static func height(_ detent: PanelDetent, in total: CGFloat) -> CGFloat {
        switch detent {
        case .compact:
            return 156
        case .medium:
            return min(max(total * 0.46, 280), total * 0.62)
        case .large:
            return min(max(total - 72, 360), total * 0.88)
        }
    }
}

struct ResizableBottomPanel<Content: View>: View {
    @Binding var detent: PanelDetent
    var containerHeight: CGFloat
    @ViewBuilder var content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        let height = max(132, PanelDetent.height(detent, in: containerHeight) - dragOffset)
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: height)
            .background {
                panelFill
                    .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(height: 32)
                    .contentShape(Rectangle())
                    .gesture(drag)
                    .accessibilityHidden(true)
            }
    }

    @ViewBuilder
    private var panelFill: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: RituShape.panel(RituTheme.sheetCorner))
        } else {
            RoundedRectangle(cornerRadius: RituTheme.sheetCorner, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private func drag() -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let resting = PanelDetent.height(detent, in: containerHeight)
                let predicted = resting - value.predictedEndTranslation.height
                withAnimation(.smooth(duration: 0.28)) {
                    detent = nearest(to: predicted)
                    dragOffset = 0
                }
            }
    }

    private func nearest(to height: CGFloat) -> PanelDetent {
        let candidates: [PanelDetent] = [.compact, .medium, .large]
        return candidates.min { lhs, rhs in
            abs(PanelDetent.height(lhs, in: containerHeight) - height) < abs(PanelDetent.height(rhs, in: containerHeight) - height)
        } ?? .medium
    }
}
