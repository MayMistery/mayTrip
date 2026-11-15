
import Foundation
import SwiftData
import CoreLocation

@Model
final class Transfer {
    var id: UUID = UUID()
    var kindRaw: String = TransferKind.flight.rawValue
    var bookingRef: String = ""
    var note: String = ""
    var addedAt: Date = Date()

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \TransferLeg.transfer)
    var legs: [TransferLeg] = []

    @Relationship(deleteRule: .nullify, inverse: \DayStop.transfer)
    var stops: [DayStop] = []

    init(kind: TransferKind) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.addedAt = Date()
    }

    var kind: TransferKind {
        get { TransferKind(rawValue: kindRaw) ?? .flight }
        set { kindRaw = newValue.rawValue }
    }

    var orderedLegs: [TransferLeg] {
        legs.sorted { $0.order < $1.order }
    }

    var firstLeg: TransferLeg? { orderedLegs.first }
    var lastLeg: TransferLeg? { orderedLegs.last }

    var title: String {
        let origin = firstLeg?.originCode.isEmpty == false ? firstLeg!.originCode : (firstLeg?.originName ?? "")
        let destination = lastLeg?.destinationCode.isEmpty == false ? lastLeg!.destinationCode : (lastLeg?.destinationName ?? "")
        if origin.isEmpty && destination.isEmpty {
            return String(localized: kind.localizedName)
        }
        return "\(origin) → \(destination)"
    }
}

@Model
final class TransferLeg {
    var id: UUID = UUID()
    var order: Int = 0
    var airlineOrOperator: String = ""
    var serviceNumber: String = ""
    var originName: String = ""
    var originCode: String = ""
    var originAddress: String = ""
    var originLatitude: Double = 0
    var originLongitude: Double = 0
    var originTimeZoneIdentifier: String = ""
    var destinationName: String = ""
    var destinationCode: String = ""
    var destinationAddress: String = ""
    var destinationLatitude: Double = 0
    var destinationLongitude: Double = 0
    var destinationTimeZoneIdentifier: String = ""
    /// Absolute departure instant.
    var departureAt: Date = Date()
    /// Absolute arrival instant.
    var arrivalAt: Date = Date()

    var transfer: Transfer?

    init(order: Int = 0) {
        self.id = UUID()
        self.order = order
    }

    var originCoordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude) }
        set {
            originLatitude = newValue.latitude
            originLongitude = newValue.longitude
        }
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude) }
        set {
            destinationLatitude = newValue.latitude
            destinationLongitude = newValue.longitude
        }
    }

    var originCoordinateIsValid: Bool {
        originLatitude != 0 || originLongitude != 0
    }

    var destinationCoordinateIsValid: Bool {
        destinationLatitude != 0 || destinationLongitude != 0
    }

    var originDisplayName: String {
        if !originName.isEmpty { return originName }
        if !originCode.isEmpty { return originCode }
        return String(localized: "transfer.origin")
    }

    var destinationDisplayName: String {
        if !destinationName.isEmpty { return destinationName }
        if !destinationCode.isEmpty { return destinationCode }
        return String(localized: "transfer.destination")
    }

    var serviceLabel: String {
        let parts = [airlineOrOperator, serviceNumber]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    var scheduledDuration: TimeInterval {
        max(0, arrivalAt.timeIntervalSince(departureAt))
    }

    var originTimeZone: TimeZone {
        TimeZone(identifier: originTimeZoneIdentifier) ?? .current
    }

    var destinationTimeZone: TimeZone {
        TimeZone(identifier: destinationTimeZoneIdentifier) ?? .current
    }
}
