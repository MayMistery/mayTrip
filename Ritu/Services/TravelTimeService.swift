
import Foundation
import MapKit

struct RouteEstimate: Sendable {
    var duration: TimeInterval
    var distance: CLLocationDistance
    var path: [CLLocationCoordinate2D]
    var isScheduled: Bool
}

enum TravelTimeService {
    /// Recalculate the hop from `stop` to `next`. Uses the scheduled transfer
    /// duration when the mode is a flight/train/bus tied to a transfer; otherwise
    /// asks MapKit and caches the result on the stop for offline use.
    @MainActor
    static func refreshRoute(from stop: DayStop, to next: DayStop, defaultMode: TransportMode) async {
        let mode = resolvedMode(from: stop, to: next, defaultMode: defaultMode)
        stop.modeToNext = mode

        if mode.isScheduledTransfer {
            if let scheduled = scheduledEstimate(from: stop, to: next) {
                stop.durationToNextSeconds = Int(scheduled.duration.rounded())
                stop.distanceToNextMeters = scheduled.distance
                stop.pathToNext = scheduled.path
                stop.routeUpdatedAt = Date()
                return
            }
        }

        guard stop.coordinateIsValid, next.coordinateIsValid else {
            stop.clearRouteCache()
            stop.modeToNext = mode
            return
        }

        if let estimate = await mapKitEstimate(from: stop.coordinate, to: next.coordinate, mode: mode) {
            stop.durationToNextSeconds = Int(estimate.duration.rounded())
            stop.distanceToNextMeters = estimate.distance
            stop.pathToNext = estimate.path
            stop.routeUpdatedAt = Date()
        } else if stop.pathToNext.isEmpty {
            // Keep any previous cache; if none, store a quiet straight / geodesic line
            // so the map still has a path while offline or when Directions fails.
            let fallback = geodesicPath(from: stop.coordinate, to: next.coordinate)
            let distance = distanceMetres(from: stop.coordinate, to: next.coordinate)
            stop.pathToNext = fallback
            if stop.durationToNextSeconds == nil {
                stop.distanceToNextMeters = distance
                stop.durationToNextSeconds = Int(roughDuration(distance: distance, mode: mode).rounded())
            }
        }
    }

    @MainActor
    static func refreshDay(_ plan: DayPlan, defaultMode: TransportMode) async {
        let stops = plan.orderedStops
        guard stops.count >= 2 else { return }
        for index in 0..<(stops.count - 1) {
            await refreshRoute(from: stops[index], to: stops[index + 1], defaultMode: defaultMode)
        }
        if let last = stops.last {
            last.modeToNext = nil
            last.clearRouteCache()
        }
    }

    static func resolvedMode(from stop: DayStop, to next: DayStop, defaultMode: TransportMode) -> TransportMode {
        if isTransferHop(from: stop, to: next), let transfer = stop.transfer ?? next.transfer {
            return transfer.kind.transportMode
        }
        return stop.modeToNext ?? defaultMode
    }

    static func isTransferHop(from stop: DayStop, to next: DayStop) -> Bool {
        guard stop.role == .transferDeparture, next.role == .transferArrival else { return false }
        return stop.transfer?.id == next.transfer?.id && stop.transferLegID == next.transferLegID
    }

    private static func scheduledEstimate(from stop: DayStop, to next: DayStop) -> RouteEstimate? {
        guard let leg = stop.transferLeg ?? next.transferLeg else { return nil }
        let path = geodesicPath(from: stop.coordinate, to: next.coordinate)
        let distance = distanceMetres(from: stop.coordinate, to: next.coordinate)
        let duration = leg.scheduledDuration > 60 ? leg.scheduledDuration : roughDuration(distance: distance, mode: .flight)
        return RouteEstimate(duration: duration, distance: distance, path: path, isScheduled: true)
    }

    private static func mapKitEstimate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        mode: TransportMode
    ) async -> RouteEstimate? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.requestsAlternateRoutes = false
        switch mode {
        case .walk:
            request.transportType = .walking
        case .transit, .train, .bus:
            request.transportType = .transit
        case .taxi, .drive, .flight:
            request.transportType = .automobile
        }

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
            let range = NSRange(location: 0, length: route.polyline.pointCount)
            route.polyline.getCoordinates(&coordinates, range: range)
            let valid = coordinates.filter { CLLocationCoordinate2DIsValid($0) }
            return RouteEstimate(duration: route.expectedTravelTime, distance: route.distance, path: valid, isScheduled: false)
        } catch {
            return nil
        }
    }

    static func geodesicPath(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, samples: Int = 32) -> [CLLocationCoordinate2D] {
        guard samples >= 2 else { return [from, to] }
        var ends = [from, to]
        let polyline = MKGeodesicPolyline(coordinates: &ends, count: 2)
        let count = max(polyline.pointCount, 2)
        var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: count)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: count))
        let valid = coordinates.filter { CLLocationCoordinate2DIsValid($0) }
        return valid.count >= 2 ? valid : [from, to]
    }

    static func distanceMetres(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    /// Honest fallback only — used when Directions is unavailable and nothing is cached.
    static func roughDuration(distance: CLLocationDistance, mode: TransportMode) -> TimeInterval {
        let speed: Double
        switch mode {
        case .walk: speed = 1.25
        case .transit, .bus, .train: speed = 8.0
        case .taxi, .drive: speed = 11.0
        case .flight: speed = 220.0
        }
        return distance / speed
    }
}
