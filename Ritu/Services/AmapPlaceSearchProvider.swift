
import Foundation
import CoreLocation

/// Placeholder 高德 Web 服务 search provider.
///
/// To enable:
/// 1. Register at https://lbs.amap.com/ and create a Key (个人开发者可实名后用于选型与测试).
/// 2. Add the key to Info.plist as `AMAP_WEB_SERVICE_KEY`, or pass it to the initializer.
/// 3. Prefer `PlaceSearchRouter`, which can send mainland-China queries here and
///    keep MapKit for everywhere else.
///
/// Coordinate contract: this type must return **WGS-84** to the rest of the app.
/// 高德's REST API speaks **GCJ-02**. Convert with `CoordinateConversion.gcj02ToWGS84`
/// on the way in, and `wgs84ToGCJ02` on the way out if you send a location bias.
///
/// This stub does not call the network. It fails with `AmapSearchError.missingAPIKey`
/// so the UI can fall back to MapKit without pretending results exist.
struct AmapPlaceSearchProvider: PlaceSearchProviding {
    var apiKey: String

    init(apiKey: String = AmapPlaceSearchProvider.configuredAPIKey()) {
        self.apiKey = apiKey
    }

    static func configuredAPIKey() -> String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "AMAP_WEB_SERVICE_KEY") as? String {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    func search(
        query: String,
        near regionCenter: CLLocationCoordinate2D?,
        kind: PlaceSearchKind
    ) async throws -> [PlaceSearchResult] {
        guard isConfigured else { throw AmapSearchError.missingAPIKey }
        // Intentionally not implemented: do not ship an unverified HTTP client
        // without a key and a chance to test GCJ-02 offsets on device.
        throw AmapSearchError.notImplemented
    }
}

enum AmapSearchError: Error, LocalizedError {
    case missingAPIKey
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            String(localized: "search.amap.missingKey")
        case .notImplemented:
            String(localized: "search.amap.notImplemented")
        }
    }
}

/// Routes queries to MapKit, leaving a clear seat for 高德.
struct PlaceSearchRouter: PlaceSearchProviding {
    var mapKit: MapKitPlaceSearchProvider = MapKitPlaceSearchProvider()
    var amap: AmapPlaceSearchProvider = AmapPlaceSearchProvider()

    func search(
        query: String,
        near regionCenter: CLLocationCoordinate2D?,
        kind: PlaceSearchKind
    ) async throws -> [PlaceSearchResult] {
        // When a 高德 key is present *and* the bias is in mainland China,
        // prefer 高德 for long-tail Chinese POI. Until then, MapKit is enough
        // (and already uses 高德 base data when the device is in China).
        if amap.isConfigured,
           let regionCenter,
           CoordinateConversion.isLikelyMainlandChina(
            latitude: regionCenter.latitude,
            longitude: regionCenter.longitude
           ) {
            do {
                let results = try await amap.search(query: query, near: regionCenter, kind: kind)
                if !results.isEmpty { return results }
            } catch {
                // Fall through to MapKit rather than failing the add-place flow.
            }
        }
        return try await mapKit.search(query: query, near: regionCenter, kind: kind)
    }
}
