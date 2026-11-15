
import Foundation
import SwiftData
import CoreLocation

@Model
final class DayStop {
    var id: UUID = UUID()
    var order: Int = 0
    var roleRaw: String = StopRole.sight.rawValue
    /// Stable key for auto-inserted anchors, e.g. "stay:{id}:morning".
    var anchorKey: String?
    var modeToNextRaw: String?
    var durationToNextSeconds: Int?
    var distanceToNextMeters: Double?
    var pathToNextData: Data?
    var routeUpdatedAt: Date?
    var customTitle: String = ""
    var customLatitude: Double = 0
    var customLongitude: Double = 0

    var dayPlan: DayPlan?
    var place: Place?
    var stay: Stay?
    var transfer: Transfer?
    var transferLegID: UUID?

    init(role: StopRole, order: Int) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.order = order
    }

    var role: StopRole {
        get { StopRole(rawValue: roleRaw) ?? .sight }
        set { roleRaw = newValue.rawValue }
    }

    var modeToNext: TransportMode? {
        get {
            guard let modeToNextRaw else { return nil }
            return TransportMode(rawValue: modeToNextRaw)
        }
        set { modeToNextRaw = newValue?.rawValue }
    }

    var transferLeg: TransferLeg? {
        guard let transferLegID, let transfer else { return nil }
        return transfer.legs.first { $0.id == transferLegID }
    }

    var coordinate: CLLocationCoordinate2D {
        if role == .sight, let place {
            return place.coordinate
        }
        if role.isStay, let stay {
            return stay.coordinate
        }
        if role == .transferDeparture, let leg = transferLeg {
            return leg.originCoordinate
        }
        if role == .transferArrival, let leg = transferLeg {
            return leg.destinationCoordinate
        }
        return CLLocationCoordinate2D(latitude: customLatitude, longitude: customLongitude)
    }

    var coordinateIsValid: Bool {
        let coord = coordinate
        return coord.latitude != 0 || coord.longitude != 0
    }

    var title: String {
        if !customTitle.isEmpty { return customTitle }
        switch role {
        case .sight:
            return place?.displayName ?? String(localized: "place.untitled")
        case .stayMorning, .stayEvening:
            return stay?.name ?? String(localized: "stay.untitled")
        case .transferDeparture:
            return transferLeg?.originDisplayName ?? String(localized: "transfer.origin")
        case .transferArrival:
            return transferLeg?.destinationDisplayName ?? String(localized: "transfer.destination")
        case .custom:
            return customTitle.isEmpty ? String(localized: "place.untitled") : customTitle
        }
    }

    var subtitle: String? {
        switch role {
        case .sight:
            return place?.bilingualSubtitle
        case .stayMorning:
            if let time = stay?.checkOutTimeText {
                return String(format: String(localized: "stay.checkout %@"), time)
            }
            return String(localized: "stay.morning")
        case .stayEvening:
            if let time = stay?.checkInTimeText {
                return String(format: String(localized: "stay.checkin %@"), time)
            }
            return String(localized: "stay.evening")
        case .transferDeparture:
            let leg = transferLeg
            let service = leg?.serviceLabel ?? ""
            return service.isEmpty ? String(localized: "stop.depart") : service
        case .transferArrival:
            let service = transferLeg?.serviceLabel ?? ""
            return service.isEmpty ? String(localized: "stop.arrive") : service
        case .custom:
            return nil
        }
    }

    var copyableAddress: String {
        switch role {
        case .sight:
            return place?.copyableAddress ?? ""
        case .stayMorning, .stayEvening:
            return stay?.copyableAddress ?? ""
        case .transferDeparture:
            return transferLeg?.originAddress ?? ""
        case .transferArrival:
            return transferLeg?.destinationAddress ?? ""
        case .custom:
            return ""
        }
    }

    var pathToNext: [CLLocationCoordinate2D] {
        get { CoordinateCodec.decode(pathToNextData) }
        set { pathToNextData = CoordinateCodec.encode(newValue) }
    }

    func clearRouteCache() {
        durationToNextSeconds = nil
        distanceToNextMeters = nil
        pathToNextData = nil
        routeUpdatedAt = nil
    }
}
