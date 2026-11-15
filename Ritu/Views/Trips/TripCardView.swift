import SwiftUI
import UIKit

struct TripCardView: View {
    var trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover
                .frame(height: 112)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(rangeText)
                    .font(.subheadline.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                if !trip.citiesText.isEmpty {
                    Text(trip.citiesText)
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .rituClip()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var cover: some View {
        if let data = trip.coverImageData, let image = uiImage(from: data) {
            image
                .resizable()
                .scaledToFill()
        } else {
            defaultCover
        }
    }

    private var defaultCover: some View {
        let color = DayPalette.color(forDayOffset: trip.name.hashValue)
        return ZStack {
            LinearGradient(
                colors: [color.opacity(0.28), color.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Path { path in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    path.move(to: CGPoint(x: width * 0.10, y: height * 0.72))
                    path.addQuadCurve(
                        to: CGPoint(x: width * 0.90, y: height * 0.36),
                        control: CGPoint(x: width * 0.46, y: height * 0.22)
                    )
                }
                .stroke(color.opacity(0.70), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
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
