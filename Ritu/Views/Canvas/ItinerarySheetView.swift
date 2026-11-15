import SwiftUI

struct ItinerarySheetView: View {
    var trip: Trip
    var plan: DayPlan
    @Binding var selectedOffset: Int
    var compact: Bool
    var showsGrabber: Bool = true
    var selectedStopID: UUID?
    var onSelectStop: (DayStop) -> Void
    var onEditStop: (DayStop) -> Void
    var onGatherNearby: () -> Void
    var onAdd: () -> Void
    var onRefreshTimes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsGrabber {
                grabber
            }
            DayRibbonView(trip: trip, selectedOffset: $selectedOffset)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            if compact {
                NextStopBar(trip: trip, plan: plan)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            } else {
                header
                    .padding(.horizontal, 20)
                    .padding(.bottom, 6)
                if plan.feelsFull {
                    Text(String(format: String(localized: "day.full %lld"), plan.orderedStops.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                }
                if plan.orderedStops.isEmpty {
                    emptyDay
                } else {
                    timeline
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 8)
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
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Menu {
                Button(String(localized: "day.gather"), systemImage: "point.3.connected.trianglepath.dotted") {
                    onGatherNearby()
                }
                Button(String(localized: "action.add"), systemImage: "plus") {
                    onAdd()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(String(localized: "day.actions"))
            }
            .buttonStyle(.plain)
        }
    }

    private var cityHint: String? {
        let stays = plan.orderedStops.compactMap { $0.stay?.name }
        if let first = stays.first { return first }
        return trip.citiesText.isEmpty ? nil : trip.citiesText
    }

    private var emptyDay: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "day.empty.title"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button(String(localized: "action.add"), action: onAdd)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(plan.orderedStops.enumerated()), id: \.element.id) { index, stop in
                    StopRowView(
                        number: index + 1,
                        stop: stop,
                        color: DayPalette.color(forDayOffset: plan.dayOffset),
                        isSelected: selectedStopID == stop.id,
                        isCrowded: plan.feelsFull
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectStop(stop) }
                    .contextMenu { stopMenu(index: index, stop: stop) }

                    if index < plan.orderedStops.count - 1 {
                        InterStopRow(
                            from: stop,
                            to: plan.orderedStops[index + 1],
                            color: DayPalette.color(forDayOffset: plan.dayOffset),
                            isCrowded: plan.feelsFull,
                            onModeChange: { mode in
                                stop.modeToNext = mode
                                stop.clearRouteCache()
                                onRefreshTimes()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func stopMenu(index: Int, stop: DayStop) -> some View {
        if index > 0 {
            Button {
                move(index, by: -1)
            } label: {
                Label(String(localized: "stop.moveUp"), systemImage: "arrow.up")
            }
        }
        if index < plan.orderedStops.count - 1 {
            Button {
                move(index, by: 1)
            } label: {
                Label(String(localized: "stop.moveDown"), systemImage: "arrow.down")
            }
        }
        Button {
            onEditStop(stop)
        } label: {
            Label(String(localized: "action.edit"), systemImage: "pencil")
        }
        if stop.role == .sight {
            Button(role: .destructive) {
                if let context = plan.modelContext {
                    DayAssembly.movePlaceToUnscheduled(stop, context: context)
                    onRefreshTimes()
                }
            } label: {
                Label(String(localized: "place.moveUnscheduled"), systemImage: "tray.and.arrow.down")
            }
        }
    }

    private func move(_ index: Int, by delta: Int) {
        let target = delta > 0 ? index + 2 : index - 1
        guard target >= 0, target <= plan.orderedStops.count else { return }
        DayAssembly.moveStop(in: plan, from: IndexSet(integer: index), to: target)
        onRefreshTimes()
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
            ZStack {
                Circle()
                    .fill(isSelected ? color : Color(.systemBackground))
                Circle()
                    .strokeBorder(color, lineWidth: isSelected ? 0 : 1.5)
                Text("\(number)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : color)
            }
            .frame(width: 26, height: 26)
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
                                .foregroundStyle(Color(red: 0.18, green: 0.46, blue: 0.34))
                        } else if stop.place?.openState == .closed {
                            Text(String(localized: "place.closed"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Color(red: 0.70, green: 0.28, blue: 0.22))
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
        .padding(.vertical, isCrowded ? 4 : 7)
        .padding(.horizontal, 8)
        .background(isSelected ? color.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    var color: Color
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
                .fill(color.opacity(0.28))
                .frame(width: 1.5, height: isCrowded ? 22 : 28)
                .frame(width: 26)
                .padding(.leading, 8)
            if isLockedTransfer {
                Label(String(localized: mode.localizedName), systemImage: mode.symbolName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
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
                        .labelStyle(.titleAndIcon)
                }
            }
            Text(durationText)
                .font(RituTheme.compactTimeFont)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if !isLockedTransfer, to.coordinateIsValid {
                HandoffButtons(
                    origin: from.coordinateIsValid ? from.coordinate : nil,
                    destination: to.coordinate,
                    destinationName: to.title,
                    mode: mode
                )
            }
        }
        .padding(.vertical, isCrowded ? 1 : 2)
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
            Spacer(minLength: 8)
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
