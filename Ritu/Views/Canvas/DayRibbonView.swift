
import SwiftUI

struct DayRibbonView: View {
    var trip: Trip
    @Binding var selectedOffset: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<trip.dayCount, id: \.self) { offset in
                        dayButton(offset)
                            .id(offset)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .contain)
    }

    private func dayButton(_ offset: Int) -> some View {
        let date = trip.dateForDayOffset(offset)
        let selected = selectedOffset == offset
        let color = DayPalette.color(forDayOffset: offset)
        return Button {
            selectedOffset = offset
        } label: {
            VStack(spacing: 2) {
                Text(Formatters.dayRibbonLabel(date: date, calendar: trip.calendar))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if let plan = trip.dayPlan(forOffset: offset), !plan.orderedStops.isEmpty {
                    Circle()
                        .fill(selected ? Color.white.opacity(0.9) : color)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? .white : .primary)
            .background(selected ? color : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Formatters.longDayTitle(date: date, calendar: trip.calendar))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
