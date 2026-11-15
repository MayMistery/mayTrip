
import Foundation
import CoreLocation

struct PlaceSearchResult: Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var nameSecondary: String = ""
    var address: String
    var addressSecondary: String = ""
    /// WGS-84.
    var coordinate: CLLocationCoordinate2D
    var hoursText: String = ""
    var openState: PlaceOpenState = .unknown
    var categoryHint: String = ""

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PlaceSearchResult, rhs: PlaceSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

enum PlaceSearchKind {
    case any
    case lodging
    case airport
    case station
}

/// Shared search surface. MapKit is the default provider.
/// A 高德 implementation can be swapped in (or used in parallel for mainland
/// China queries) without changing the UI.
protocol PlaceSearchProviding {
    func search(
        query: String,
        near regionCenter: CLLocationCoordinate2D?,
        kind: PlaceSearchKind
    ) async throws -> [PlaceSearchResult]
}

struct PlaceSearchRequest {
    var query: String
    var regionCenter: CLLocationCoordinate2D?
    var kind: PlaceSearchKind
}
