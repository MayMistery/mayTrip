
import SwiftUI
import UIKit

struct TripCardView: View {
    var trip: Trip

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cover
            LinearGradient(
                colors: [.clear, .black.opacity(0.58)],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(RituTheme.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(rangeText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.88))
                if !trip.citiesText.isEmpty {
                    Text(trip.citiesText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(20)
        }
        .frame(minHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var cover: some View {
        if let data = trip.coverImageData, let image = uiImage(from: data) {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)
        } else {
            defaultCover
        }
    }

    private var defaultCover: some View {
        let color = DayPalette.color(forDayOffset: trip.name.hashValue)
        return ZStack {
            color.opacity(0.85)
            GeometryReader { proxy in
                Path { path in
                    let w = proxy.size.width
                    let h = proxy.size.height
                    path.move(to: CGPoint(x: w * 0.08, y: h * 0.72))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.92, y: h * 0.38),
                        control: CGPoint(x: w * 0.48, y: h * 0.18)
                    )
                }
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)
    }

    private var rangeText: String {
        Formatters.tripDateRange(start: trip.startDate, end: trip.endDate, calendar: trip.calendar)
    }

    private var accessibilityLabel: String {
        [trip.name, rangeText, trip.citiesText].filter { !$0.isEmpty }.joined(separator: "，")
    }

    private func uiImage(from data: Data) -> Image? {
        #if canImport(UIKit)
        if let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        #endif
        return nil
    }
}

