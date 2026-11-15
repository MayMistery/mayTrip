
import Foundation
import MapKit

struct MapKitPlaceSearchProvider: PlaceSearchProviding {
    func search(
        query: String,
        near regionCenter: CLLocationCoordinate2D?,
        kind: PlaceSearchKind
    ) async throws -> [PlaceSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = queryForKind(trimmed, kind: kind)
        request.resultTypes = .pointOfInterest
        if let regionCenter, CLLocationCoordinate2DIsValid(regionCenter) {
            request.region = MKCoordinateRegion(
                center: regionCenter,
                span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
            )
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.prefix(20).map { item in
            let name = item.name ?? trimmed
            let address = formattedAddress(for: item)
            let hours = hoursText(for: item)
            return PlaceSearchResult(
                name: name,
                address: address,
                coordinate: item.placemark.coordinate,
                hoursText: hours,
                openState: openState(for: item),
                categoryHint: item.pointOfInterestCategory?.rawValue ?? ""
            )
        }
    }

    private func queryForKind(_ query: String, kind: PlaceSearchKind) -> String {
        switch kind {
        case .any:
            return query
        case .lodging:
            if query.localizedCaseInsensitiveContains("hotel")
                || query.contains("酒店")
                || query.contains("民宿")
                || query.localizedCaseInsensitiveContains("airbnb") {
                return query
            }
            return "\(query) hotel"
        case .airport:
            if query.count == 3, query.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) {
                return "\(query) airport"
            }
            return query
        case .station:
            return query
        }
    }

    private func formattedAddress(for item: MKMapItem) -> String {
        if let full = item.placemark.title, !full.isEmpty {
            // MapKit often prefixes the name; keep the address portion if possible.
            let name = item.name ?? ""
            if !name.isEmpty, full.hasPrefix(name) {
                let rest = full.dropFirst(name.count).trimmingCharacters(in: CharacterSet(charactersIn: " ,，"))
                if !rest.isEmpty { return rest }
            }
            return full
        }
        return [
            item.placemark.thoroughfare,
            item.placemark.subThoroughfare,
            item.placemark.locality,
            item.placemark.administrativeArea,
            item.placemark.country
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    private func hoursText(for item: MKMapItem) -> String {
        if #available(iOS 18.0, *) {
            // Keep a short snapshot when MapKit exposes hours; otherwise leave blank.
        }
        return ""
    }

    private func openState(for item: MKMapItem) -> PlaceOpenState {
        .unknown
    }
}
