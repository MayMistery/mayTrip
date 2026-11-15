import Foundation
import SwiftData
import CoreLocation

@Model
final class Place {
    var id: UUID = UUID()
    /// Primary display name — often the local or official name.
    var name: String = ""
    /// The other script, e.g. Chinese if `name` is Latin, or vice versa.
    var nameSecondary: String = ""
    /// Address in the script a taxi driver is most likely to need.
    var address: String = ""
    var addressSecondary: String = ""
    /// WGS-84 latitude.
    var latitude: Double = 0
    var longitude: Double = 0
    var hoursText: String = ""
    var openStateRaw: String = PlaceOpenState.unknown.rawValue
    var hoursSnapshotAt: Date?
    var note: String = ""
    var bookingRef: String = ""
    var photoData: Data?
    var addedAt: Date = Date()

    var trip: Trip?

    @Relationship(deleteRule: .nullify, inverse: \DayStop.place)
    var stops: [DayStop] = []

    init(
        name: String,
        nameSecondary: String = "",
        address: String = "",
        addressSecondary: String = "",
        latitude: Double,
        longitude: Double
    ) {
        self.id = UUID()
        self.name = name
        self.nameSecondary = nameSecondary
        self.address = address
        self.addressSecondary = addressSecondary
        self.latitude = latitude
        self.longitude = longitude
        self.addedAt = Date()
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var openState: PlaceOpenState {
        get { PlaceOpenState(rawValue: openStateRaw) ?? .unknown }
        set { openStateRaw = newValue.rawValue }
    }

    var displayName: String { name }

    var bilingualSubtitle: String? {
        let secondary = nameSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
        return secondary.isEmpty ? nil : secondary
    }

    var copyableAddress: String {
        let primary = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        return addressSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
