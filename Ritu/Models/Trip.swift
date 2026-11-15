import Foundation
import SwiftData
import CoreLocation

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    /// Civil start of the first day, stored as a date. Interpreted in `timeZoneIdentifier`.
    var startDate: Date = Date()
    var endDate: Date = Date()
    /// Cities as the traveller typed them, e.g. "马德里、里斯本".
    var citiesText: String = ""
    var coverImageData: Data?
    var createdAt: Date = Date()
    /// IANA identifier used to slice the trip into days. Example: "Europe/Madrid".
    var timeZoneIdentifier: String = TimeZone.current.identifier
    var defaultLocalModeRaw: String = TransportMode.walk.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Place.trip)
    var places: [Place] = []

    @Relationship(deleteRule: .cascade, inverse: \Stay.trip)
    var stays: [Stay] = []

    @Relationship(deleteRule: .cascade, inverse: \Transfer.trip)
    var transfers: [Transfer] = []

    @Relationship(deleteRule: .cascade, inverse: \DayPlan.trip)
    var dayPlans: [DayPlan] = []

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        citiesText: String = "",
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.citiesText = citiesText
        self.createdAt = Date()
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var defaultLocalMode: TransportMode {
        get { TransportMode(rawValue: defaultLocalModeRaw) ?? .walk }
        set { defaultLocalModeRaw = newValue.rawValue }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    var dayCount: Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    func dateForDayOffset(_ offset: Int) -> Date {
        let start = calendar.startOfDay(for: startDate)
        return calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }

    func dayOffset(for date: Date) -> Int? {
        let start = calendar.startOfDay(for: startDate)
        let day = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: start, to: day).day else { return nil }
        guard offset >= 0, offset < dayCount else { return nil }
        return offset
    }

    func dayPlan(forOffset offset: Int) -> DayPlan? {
        dayPlans.first { $0.dayOffset == offset }
    }

    var unscheduledPlaces: [Place] {
        places
            .filter { place in
                !dayPlans.contains { plan in
                    plan.orderedStops.contains { $0.place?.id == place.id }
                }
            }
            .sorted { $0.addedAt < $1.addedAt }
    }

    var citiesList: [String] {
        citiesText
            .split { $0 == "、" || $0 == "," || $0 == "，" || $0 == ";" || $0 == "；" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
