
import Foundation
import CoreLocation

/// Helpers for mainland China coordinate systems.
///
/// Day-to-day storage in 日图 is **WGS-84**, which is what MapKit uses as its
/// interchange system. When talking to 高德 or 百度 APIs you must convert:
///
/// - 高德 / 腾讯: **GCJ-02** ("Mars coordinates")
/// - 百度: **BD-09** (a further offset on top of GCJ-02)
///
/// Passing raw WGS-84 into a 高德 search or URI without declaring the datum
/// can place a pin hundreds of metres off. MapKit itself offsets the base map
/// when the device is in mainland China (Apple licenses 高德 data there); still
/// convert at the boundary when you add a 高德 search provider or `iosamap://`
/// handoff with `dev=0`.
///
/// The handoff helper uses `dev=1` on 高德 URIs, which declares WGS-84 so we
/// do not convert on that path. Search against 高德 Web 服务 must convert.
enum CoordinateConversion {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    static func isLikelyMainlandChina(latitude: Double, longitude: Double) -> Bool {
        // Approximate bounding box; excludes Taiwan, Hong Kong, Macau on purpose.
        latitude >= 18.0 && latitude <= 53.6 && longitude >= 73.6 && longitude <= 135.1
            && !isHongKongMacau(latitude: latitude, longitude: longitude)
            && !isTaiwan(latitude: latitude, longitude: longitude)
    }

    private static func isHongKongMacau(latitude: Double, longitude: Double) -> Bool {
        latitude >= 22.13 && latitude <= 22.58 && longitude >= 113.75 && longitude <= 114.51
    }

    private static func isTaiwan(latitude: Double, longitude: Double) -> Bool {
        latitude >= 21.8 && latitude <= 25.4 && longitude >= 119.9 && longitude <= 122.1
    }

    static func wgs84ToGCJ02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        guard isLikelyMainlandChina(latitude: lat, longitude: lon) else { return coordinate }
        let (dLat, dLon) = delta(lat: lat, lon: lon)
        return CLLocationCoordinate2D(latitude: lat + dLat, longitude: lon + dLon)
    }

    static func gcj02ToWGS84(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        guard isLikelyMainlandChina(latitude: lat, longitude: lon) else { return coordinate }
        let (dLat, dLon) = delta(lat: lat, lon: lon)
        return CLLocationCoordinate2D(latitude: lat - dLat, longitude: lon - dLon)
    }

    private static func delta(lat: Double, lon: Double) -> (Double, Double) {
        var dLat = transformLat(x: lon - 105.0, y: lat - 35.0)
        var dLon = transformLon(x: lon - 105.0, y: lat - 35.0)
        let radLat = lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return (dLat, dLon)
    }

    private static func transformLat(x: Double, y: Double) -> Double {
        var result = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        result += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return result
    }

    private static func transformLon(x: Double, y: Double) -> Double {
        var result = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        result += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        result += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        result += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return result
    }
}

extension CLLocationCoordinate2D {
    var isValidCoordinate: Bool {
        CLLocationCoordinate2DIsValid(self) && !(latitude == 0 && longitude == 0)
    }
}
