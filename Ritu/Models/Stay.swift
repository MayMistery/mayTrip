import Foundation
import SwiftData
import CoreLocation

@Model
final class Stay {
    var id: UUID = UUID()
    var name: String = ""
    var nameSecondary: String = ""
    var address: String = ""
    var addressSecondary: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    /// First night — the civil date of check-in, in the trip time zone.
    var checkInDate: Date = Date()
    /// Morning of departure — not a night stayed.
    var checkOutDate: Date = Date()
    /// Optional clock time as minutes from midnight, e.g. 15 * 60 for 15:00. -1 means unset.
    var checkInMinuteOfDay: Int = -1
    var checkOutMinuteOfDay: Int = -1
    var bookingRef: String = ""
    var note: String = ""
    var photoData: Data?
    var addedAt: Date = Date()

    var trip: Trip?

    @Relationship(deleteRule: .nullify, inverse: \DayStop.stay)
    var stops: [DayStop] = []

    init(
        name: String,
        address: String = "",
        latitude: Double,
        longitude: Double,
        checkInDate: Date,
        checkOutDate: Date
    ) {
        self.id = UUID()
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.checkInDate = checkInDate
        self.checkOutDate = checkOutDate
        self.addedAt = Date()
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var copyableAddress: String {
        let primary = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !primary.isEmpty { return primary }
        return addressSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Nights slept: check-in date through the day before check-out.
    func coversNight(of date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: checkInDate)
        let end = calendar.startOfDay(for: checkOutDate)
        return day >= start && day < end
    }

    /// Woke up here on this civil date (slept the previous night).
    func isMorningAnchor(on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: checkInDate)
        let end = calendar.startOfDay(for: checkOutDate)
        return day > start && day <= end
    }

    /// Sleeps here on this civil date (check-in through night before check-out).
    func isEveningAnchor(on date: Date, calendar: Calendar) -> Bool {
        coversNight(of: date, calendar: calendar)
    }

    var checkInTimeText: String? { Self.formatMinute(checkInMinuteOfDay) }
    var checkOutTimeText: String? { Self.formatMinute(checkOutMinuteOfDay) }

    private static func formatMinute(_ value: Int) -> String? {
        guard value >= 0 else { return nil }
        let hour = value / 60
        let minute = value % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}
