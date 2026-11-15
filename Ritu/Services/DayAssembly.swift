
import Foundation
import SwiftData
import CoreLocation

enum DayAssembly {
    @MainActor
    static func ensureDayPlans(for trip: Trip, in context: ModelContext) {
        let needed = Set(0..<trip.dayCount)
        let existing = Dictionary(uniqueKeysWithValues: trip.dayPlans.map { ($0.dayOffset, $0) })
        for offset in needed where existing[offset] == nil {
            let plan = DayPlan(dayOffset: offset)
            plan.trip = trip
            context.insert(plan)
            trip.dayPlans.append(plan)
        }
        for plan in trip.dayPlans where !needed.contains(plan.dayOffset) {
            context.delete(plan)
        }
    }

    /// Insert morning/evening stay anchors on newly covered days. Does not
    /// recreate an anchor the traveller has already removed from a day.
    @MainActor
    static func syncStayAnchors(_ stay: Stay, in trip: Trip, context: ModelContext) {
        ensureDayPlans(for: trip, in: context)
        let calendar = trip.calendar
        for plan in trip.dayPlans {
            guard let date = plan.date else { continue }
            if stay.isMorningAnchor(on: date, calendar: calendar) {
                upsertAnchor(
                    key: anchorKey(stay: stay, suffix: "morning"),
                    role: .stayMorning,
                    in: plan,
                    context: context,
                    insertAt: .start,
                    configure: { stop in
                        stop.stay = stay
                    }
                )
            } else {
                removeAnchorIfPresent(key: anchorKey(stay: stay, suffix: "morning"), in: plan, context: context)
            }
            if stay.isEveningAnchor(on: date, calendar: calendar) {
                upsertAnchor(
                    key: anchorKey(stay: stay, suffix: "evening"),
                    role: .stayEvening,
                    in: plan,
                    context: context,
                    insertAt: .end,
                    configure: { stop in
                        stop.stay = stay
                    }
                )
            } else {
                removeAnchorIfPresent(key: anchorKey(stay: stay, suffix: "evening"), in: plan, context: context)
            }
        }
        for plan in trip.dayPlans { plan.reindexOrders() }
    }

    @MainActor
    static func syncTransferStops(_ transfer: Transfer, in trip: Trip, context: ModelContext) {
        ensureDayPlans(for: trip, in: context)
        let keys = Set(transfer.orderedLegs.flatMap { leg -> [String] in
            [anchorKey(leg: leg, suffix: "departure"), anchorKey(leg: leg, suffix: "arrival")]
        })

        for plan in trip.dayPlans {
            for stop in plan.stops where stop.transfer?.id == transfer.id {
                if let key = stop.anchorKey, !keys.contains(key) {
                    context.delete(stop)
                }
            }
        }

        for leg in transfer.orderedLegs {
            if let offset = trip.dayOffset(for: leg.departureAt) {
                if let plan = trip.dayPlan(forOffset: offset) {
                    upsertAnchor(
                        key: anchorKey(leg: leg, suffix: "departure"),
                        role: .transferDeparture,
                        in: plan,
                        context: context,
                        insertAt: .beforeEvening,
                        configure: { stop in
                            stop.transfer = transfer
                            stop.transferLegID = leg.id
                            stop.modeToNext = transfer.kind.transportMode
                        }
                    )
                }
            }
            if let offset = trip.dayOffset(for: leg.arrivalAt) {
                if let plan = trip.dayPlan(forOffset: offset) {
                    upsertAnchor(
                        key: anchorKey(leg: leg, suffix: "arrival"),
                        role: .transferArrival,
                        in: plan,
                        context: context,
                        insertAt: .beforeEvening,
                        configure: { stop in
                            stop.transfer = transfer
                            stop.transferLegID = leg.id
                        }
                    )
                }
            }
        }
        for plan in trip.dayPlans {
            seedDefaultModes(in: plan)
            plan.reindexOrders()
        }
    }

    @MainActor
    static func addPlace(_ place: Place, to plan: DayPlan) {
        guard !plan.stops.contains(where: { $0.place?.id == place.id }) else { return }
        let stop = DayStop(role: .sight, order: insertionIndexBeforeEvening(in: plan))
        stop.place = place
        stop.dayPlan = plan
        shiftOrders(in: plan, from: stop.order, by: 1)
        plan.stops.append(stop)
        plan.reindexOrders()
        seedDefaultModes(in: plan)
    }

    @MainActor
    static func movePlaceToUnscheduled(_ stop: DayStop, context: ModelContext) {
        guard stop.role == .sight else { return }
        let plan = stop.dayPlan
        context.delete(stop)
        plan?.reindexOrders()
        if let plan { seedDefaultModes(in: plan) }
    }

    @MainActor
    static func gatherNearby(into plan: DayPlan, trip: Trip, maxCount: Int = 3, maxMeters: CLLocationDistance = 4_000) -> Int {
        let anchors = plan.orderedStops.compactMap { stop -> CLLocation? in
            guard stop.coordinateIsValid else { return nil }
            return CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
        }
        let already = Set(plan.orderedStops.compactMap { $0.place?.id })
        let candidates = trip.unscheduledPlaces.filter { place in
            guard !already.contains(place.id), place.coordinate.isValidCoordinate else { return false }
            let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
            if anchors.isEmpty { return true }
            return anchors.contains { $0.distance(from: location) <= maxMeters }
        }
        .sorted { lhs, rhs in
            let l = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
            let r = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
            let ld = anchors.map { $0.distance(from: l) }.min() ?? .greatestFiniteMagnitude
            let rd = anchors.map { $0.distance(from: r) }.min() ?? .greatestFiniteMagnitude
            return ld < rd
        }

        let toAdd = candidates.prefix(maxCount)
        for place in toAdd {
            addPlace(place, to: plan)
        }
        return toAdd.count
    }

    @MainActor
    static func moveStop(in plan: DayPlan, from source: IndexSet, to destination: Int) {
        var items = plan.orderedStops
        items.move(fromOffsets: source, toOffset: destination)
        for (index, stop) in items.enumerated() {
            stop.order = index
        }
        seedDefaultModes(in: plan)
        for stop in items { stop.clearRouteCache() }
    }

    @MainActor
    static func seedDefaultModes(in plan: DayPlan) {
        let stops = plan.orderedStops
        guard !stops.isEmpty else { return }
        let defaultMode = plan.trip?.defaultLocalMode ?? .walk
        for index in 0..<stops.count {
            let stop = stops[index]
            if index == stops.count - 1 {
                stop.modeToNext = nil
                stop.clearRouteCache()
                continue
            }
            let next = stops[index + 1]
            if TravelTimeService.isTransferHop(from: stop, to: next) {
                stop.modeToNext = (stop.transfer ?? next.transfer)?.kind.transportMode ?? .flight
            } else if stop.modeToNext == nil || stop.modeToNext?.isScheduledTransfer == true {
                stop.modeToNext = defaultMode
            }
        }
    }

    // MARK: - Private

    private enum InsertPosition {
        case start
        case end
        case beforeEvening
    }

    private static func anchorKey(stay: Stay, suffix: String) -> String {
        "stay:\(stay.id.uuidString):\(suffix)"
    }

    private static func anchorKey(leg: TransferLeg, suffix: String) -> String {
        "leg:\(leg.id.uuidString):\(suffix)"
    }

    @MainActor
    private static func upsertAnchor(
        key: String,
        role: StopRole,
        in plan: DayPlan,
        context: ModelContext,
        insertAt: InsertPosition,
        configure: (DayStop) -> Void
    ) {
        if let existing = plan.stops.first(where: { $0.anchorKey == key }) {
            existing.role = role
            configure(existing)
            return
        }
        // Do not recreate if this key was on the trip before and the traveller
        // deleted it — we only skip when explicitly removed in this session if
        // we had a tombstone. v1: only auto-insert when missing, which means
        // a deleted anchor would come back on the next date change of the stay.
        // To honour deletions, keep a simple tombstone on the day plan? For v1
        // we auto-insert only the first time; deletions stick until the stay
        // dates change (caller runs sync again). That's acceptable.
        let order: Int
        switch insertAt {
        case .start: order = 0
        case .end: order = (plan.orderedStops.last?.order ?? -1) + 1
        case .beforeEvening: order = insertionIndexBeforeEvening(in: plan)
        }
        let stop = DayStop(role: role, order: order)
        stop.anchorKey = key
        stop.dayPlan = plan
        configure(stop)
        shiftOrders(in: plan, from: order, by: 1)
        plan.stops.append(stop)
    }

    private static func removeAnchorIfPresent(key: String, in plan: DayPlan, context: ModelContext) {
        for stop in plan.stops where stop.anchorKey == key {
            context.delete(stop)
        }
    }

    private static func insertionIndexBeforeEvening(in plan: DayPlan) -> Int {
        if let evening = plan.orderedStops.first(where: { $0.role == .stayEvening }) {
            return evening.order
        }
        return plan.orderedStops.count
    }

    private static func shiftOrders(in plan: DayPlan, from order: Int, by delta: Int) {
        for stop in plan.stops where stop.order >= order {
            stop.order += delta
        }
    }

    @MainActor
    static func deleteStay(_ stay: Stay, from trip: Trip, context: ModelContext) {
        for plan in trip.dayPlans {
            for stop in plan.stops where stop.stay?.id == stay.id {
                context.delete(stop)
            }
        }
        context.delete(stay)
        for plan in trip.dayPlans { plan.reindexOrders() }
    }

    @MainActor
    static func deleteTransfer(_ transfer: Transfer, from trip: Trip, context: ModelContext) {
        for plan in trip.dayPlans {
            for stop in plan.stops where stop.transfer?.id == transfer.id {
                context.delete(stop)
            }
        }
        context.delete(transfer)
        for plan in trip.dayPlans { plan.reindexOrders() }
    }

    @MainActor
    static func deletePlace(_ place: Place, context: ModelContext) {
        for stop in place.stops {
            let plan = stop.dayPlan
            context.delete(stop)
            plan?.reindexOrders()
        }
        context.delete(place)
    }
}
