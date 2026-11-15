
import SwiftUI

struct ItinerarySheetView: View {
    var trip: Trip
    var plan: DayPlan
    @Binding var selectedOffset: Int
    var compact: Bool
    var selectedStopID: UUID?
    var onSelectStop: (DayStop) -> Void
    var onEditStop: (DayStop) -> Void
    var onGatherNearby: () -> Void
    var onAdd: () -> Void
    var onRefreshTimes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber
            DayRibbonView(trip: trip, selectedOffset: $selectedOffset)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            if compact {
                NextStopBar(trip: trip, plan: plan)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            } else {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                if plan.feelsFull {
                    Text(String(format: String(localized: "day.full %lld"), plan.orderedStops.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }
                if plan.orderedStops.isEmpty {
                    emptyDay
                } else {
                    list
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.longDayTitle(date: plan.date ?? trip.dateForDayOffset(plan.dayOffset), calendar: trip.calendar))
                    .font(.title3.weight(.semibold))
                if let cities = cityHint, !cities.isEmpty {
                    Text(cities)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button(String(localized: "day.gather"), systemImage: "point.3.connected.trianglepath.dotted") {
                    onGatherNearby()
                }
                Button(String(localized: "action.add"), systemImage: "plus") {
                    onAdd()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .accessibilityLabel(String(localized: "day.actions"))
            }
        }
    }

    private var cityHint: String? {
        let stays = plan.orderedStops.compactMap { $0.stay?.name }
        if let first = stays.first { return first }
        return trip.citiesText.isEmpty ? nil : trip.citiesText
    }

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "day.empty.title"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button(String(localized: "action.add")) { onAdd() }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        List {
            ForEach(Array(plan.orderedStops.enumerated()), id: \.element.id) { index, stop in
                VStack(alignment: .leading, spacing: 0) {
                    StopRowView(
                        number: index + 1,
                        stop: stop,
                        color: DayPalette.color(forDayOffset: plan.dayOffset),
                        isSelected: selectedStopID == stop.id,
                        isCrowded: plan.feelsFull
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectStop(stop) }
                    .onLongPressGesture { onEditStop(stop) }

                    if index < plan.orderedStops.count - 1 {
                        InterStopRow(
                            from: stop,
                            to: plan.orderedStops[index + 1],
                            isCrowded: plan.feelsFull,
                            onModeChange: { mode in
                                stop.modeToNext = mode
                                stop.clearRouteCache()
                                onRefreshTimes()
                            }
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: plan.feelsFull ? 4 : 8, leading: 16, bottom: plan.feelsFull ? 4 : 8, trailing: 16))
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if stop.role == .sight {
                        Button {
                            if let context = plan.modelContext {
                                DayAssembly.movePlaceToUnscheduled(stop, context: context)
                                onRefreshTimes()
                            }
                        } label: {
                            Label(String(localized: "place.moveUnscheduled"), systemImage: "tray.and.arrow.down")
                        }
                    }
                }
            }
            .onMove { source, destination in
                DayAssembly.moveStop(in: plan, from: source, to: destination)
                onRefreshTimes()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }
}

struct StopRowView: View {
    var number: Int
    var stop: DayStop
    var color: Color
    var isSelected: Bool
    var isCrowded: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .frame(width: 22, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(stop.title)
                    .font(isCrowded ? .body.weight(.medium) : .body.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = stop.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if stop.role == .sight, let hours = stop.place?.hoursText, !hours.isEmpty {
                    HStack(spacing: 6) {
                        Text(hours)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                        if stop.place?.openState == .open {
                            Text(String(localized: "place.open"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color(red: 0.22, green: 0.48, blue: 0.36))
                        } else if stop.place?.openState == .closed {
                            Text(String(localized: "place.closed"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color(red: 0.72, green: 0.32, blue: 0.22))
                        }
                    }
                }
                if stop.role.isTransferEndpoint, let leg = stop.transferLeg {
                    Text(clockLine(for: stop, leg: leg))
                        .font(RituTheme.compactTimeFont)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, isCrowded ? 2 : 4)
        .padding(.horizontal, 4)
        .background(isSelected ? color.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func clockLine(for stop: DayStop, leg: TransferLeg) -> String {
        if stop.role == .transferDeparture {
            return Formatters.clock(date: leg.departureAt, timeZone: leg.originTimeZone)
        }
        return Formatters.clock(date: leg.arrivalAt, timeZone: leg.destinationTimeZone)
    }
}

struct InterStopRow: View {
    var from: DayStop
    var to: DayStop
    var isCrowded: Bool
    var onModeChange: (TransportMode) -> Void

    private var isLockedTransfer: Bool {
        TravelTimeService.isTransferHop(from: from, to: to)
    }

    private var mode: TransportMode {
        from.modeToNext ?? .walk
    }

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
                .padding(.leading, 31)
                .padding(.vertical, 2)
            if isLockedTransfer {
                Label(String(localized: mode.localizedName), systemImage: mode.symbolName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    ForEach(TransportMode.localModes) { item in
                        Button {
                            onModeChange(item)
                        } label: {
                            Label(String(localized: item.localizedName), systemImage: item.symbolName)
                        }
                    }
                } label: {
                    Label(String(localized: mode.localizedName), systemImage: mode.symbolName)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            Text(durationText)
                .font(RituTheme.compactTimeFont)
                .foregroundStyle(.secondary)
            Spacer()
            if !isLockedTransfer, to.coordinateIsValid {
                HandoffButtons(
                    origin: from.coordinateIsValid ? from.coordinate : nil,
                    destination: to.coordinate,
                    destinationName: to.title,
                    mode: mode
                )
            }
        }
        .padding(.vertical, isCrowded ? 2 : 6)
        .padding(.trailing, 8)
    }

    private var durationText: String {
        if let seconds = from.durationToNextSeconds {
            return Formatters.duration(seconds: seconds)
        }
        return String(localized: "duration.unknown")
    }
}

struct NextStopBar: View {
    var trip: Trip
    var plan: DayPlan

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "day.next"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer()
            if let duration = hopText {
                Text(duration)
                    .font(RituTheme.nextStopTimeFont)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var first: DayStop? { plan.orderedStops.first }

    private var title: String {
        first?.title ?? String(localized: "day.empty.short")
    }

    private var hopText: String? {
        guard let first, let seconds = first.durationToNextSeconds else { return nil }
        let mode = first.modeToNext.map { String(localized: $0.localizedName) } ?? ""
        return [mode, Formatters.duration(seconds: seconds)].filter { !$0.isEmpty }.joined(separator: "  ")
    }
}
