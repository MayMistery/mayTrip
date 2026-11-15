
import Foundation
import CoreLocation

enum CoordinateCodec {
    static func encode(_ coordinates: [CLLocationCoordinate2D]) -> Data? {
        guard !coordinates.isEmpty else { return nil }
        var pairs: [Double] = []
        pairs.reserveCapacity(coordinates.count * 2)
        for coordinate in coordinates {
            pairs.append(coordinate.latitude)
            pairs.append(coordinate.longitude)
        }
        return try? JSONEncoder().encode(pairs)
    }

    static func decode(_ data: Data?) -> [CLLocationCoordinate2D] {
        guard let data, let pairs = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        var coordinates: [CLLocationCoordinate2D] = []
        var index = 0
        while index + 1 < pairs.count {
            coordinates.append(CLLocationCoordinate2D(latitude: pairs[index], longitude: pairs[index + 1]))
            index += 2
        }
        return coordinates
    }
}
