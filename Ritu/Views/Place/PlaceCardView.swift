
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
            Form {
                Section {
                    TextField(String(localized: "place.name"), text: $place.name)
                    TextField(String(localized: "place.nameSecondary"), text: $place.nameSecondary)
                }
                if !place.copyableAddress.isEmpty {
                    Section {
                        Text(place.copyableAddress)
                        Button(String(localized: "place.copyAddress")) {
                            UIPasteboard.general.string = place.copyableAddress
                        }
                    }
                }
                Section {
                    TextField(String(localized: "place.address"), text: $place.address, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(String(localized: "place.hours"), text: $place.hoursText)
                        .monospacedDigit()
                    TextField(String(localized: "place.bookingRef"), text: $place.bookingRef)
                    TextField(String(localized: "place.note"), text: $place.note, axis: .vertical)
                        .lineLimit(3...8)
                }
                daySection
                if place.coordinate.isValidCoordinate {
                    Section {
                        HandoffButtons(
                            origin: nil,
                            destination: place.coordinate,
                            destinationName: place.displayName,
                            mode: trip.defaultLocalMode
                        )
                    }
                }
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
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        removeFromDays()
                    } label: {
                        Text(String(localized: "layer.unscheduled"))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isUnscheduled ? Color.primary : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(isUnscheduled ? Color(.systemBackground) : Color.primary)
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
                                .background(selected ? DayPalette.color(forDayOffset: offset) : Color(.secondarySystemFill), in: Capsule())
                                .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text(String(localized: "place.putOnDay"))
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

