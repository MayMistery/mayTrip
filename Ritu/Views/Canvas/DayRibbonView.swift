import SwiftUI

struct DayRibbonView: View {
    var trip: Trip
    @Binding var selectedOffset: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<trip.dayCount, id: \.self) { offset in
                        dayButton(offset)
                            .id(offset)
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(selectedOffset, anchor: .center)
            }
            .onChange(of: selectedOffset) { _, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func dayButton(_ offset: Int) -> some View {
        let date = trip.dateForDayOffset(offset)
        let selected = selectedOffset == offset
        let color = DayPalette.color(forDayOffset: offset)
        let hasStops = trip.dayPlan(forOffset: offset)?.orderedStops.isEmpty == false
        return Button {
            selectedOffset = offset
        } label: {
            VStack(spacing: 3) {
                Text(Formatters.dayRibbonLabel(date: date, calendar: trip.calendar))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Circle()
                    .fill(hasStops ? (selected ? Color.white.opacity(0.92) : color) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? color : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Formatters.longDayTitle(date: date, calendar: trip.calendar))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
