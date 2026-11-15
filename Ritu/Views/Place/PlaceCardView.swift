
import SwiftUI
import SwiftData
import UIKit

struct PlaceCardView: View {
    var trip: Trip
    @Bindable var place: Place
    var currentDay: DayPlan?
    var onChange: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(String(localized: "place.name"), text: $place.name)
                            .font(RituTheme.titleFont)
                        TextField(String(localized: "place.nameSecondary"), text: $place.nameSecondary)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    if !place.copyableAddress.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "place.address"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(place.copyableAddress)
                                .font(.body)
                            Button(String(localized: "place.copyAddress")) {
                                UIPasteboard.general.string = place.copyableAddress
                            }
                            .font(.footnote.weight(.medium))
                        }
                    }
                    TextField(String(localized: "place.address"), text: $place.address, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(String(localized: "place.hours"), text: $place.hoursText)
                        .monospacedDigit()
                    TextField(String(localized: "place.bookingRef"), text: $place.bookingRef)
                    TextField(String(localized: "place.note"), text: $place.note, axis: .vertical)
                        .lineLimit(3...8)

                    daySection
                    if place.coordinate.isValidCoordinate {
                        HandoffButtons(
                            origin: nil,
                            destination: place.coordinate,
                            destinationName: place.displayName,
                            mode: trip.defaultLocalMode
                        )
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done")) {
                        try? context.save()
                        onChange()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "place.delete"), role: .destructive) {
                        confirmDelete = true
                    }
                }
            }
            .confirmationDialog(String(localized: "place.delete"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(String(localized: "place.delete"), role: .destructive) {
                    DayAssembly.deletePlace(place, context: context)
                    try? context.save()
                    onChange()
                    dismiss()
                }
                Button(String(localized: "action.cancel"), role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var daySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "place.putOnDay"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        removeFromDays()
                    } label: {
                        Text(String(localized: "layer.unscheduled"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isUnscheduled ? Color.primary : Color.primary.opacity(0.06), in: Capsule())
                            .foregroundStyle(isUnscheduled ? Color(.systemBackground) : .primary)
                    }
                    .buttonStyle(.plain)
                    ForEach(0..<trip.dayCount, id: \.self) { offset in
                        let date = trip.dateForDayOffset(offset)
                        let selected = isOnDay(offset)
                        Button {
                            move(to: offset)
                        } label: {
                            Text(Formatters.dayRibbonLabel(date: date, calendar: trip.calendar))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selected ? DayPalette.color(forDayOffset: offset) : Color.primary.opacity(0.06), in: Capsule())
                                .foregroundStyle(selected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var isUnscheduled: Bool { trip.unscheduledPlaces.contains(where: { $0.id == place.id }) }

    private func isOnDay(_ offset: Int) -> Bool {
        trip.dayPlan(forOffset: offset)?.orderedStops.contains { $0.place?.id == place.id } == true
    }

    private func removeFromDays() {
        for plan in trip.dayPlans {
            for stop in plan.stops where stop.place?.id == place.id {
                DayAssembly.movePlaceToUnscheduled(stop, context: context)
            }
        }
        try? context.save()
        onChange()
    }

    private func move(to offset: Int) {
        removeFromDays()
        if let plan = trip.dayPlan(forOffset: offset) {
            DayAssembly.addPlace(place, to: plan)
        }
        try? context.save()
        onChange()
    }
}

