
import Foundation
import SwiftData

@Model
final class DayPlan {
    var id: UUID = UUID()
    var dayOffset: Int = 0

    var trip: Trip?

    @Relationship(deleteRule: .cascade, inverse: \DayStop.dayPlan)
    var stops: [DayStop] = []

    init(dayOffset: Int) {
        self.id = UUID()
        self.dayOffset = dayOffset
    }

    var orderedStops: [DayStop] {
        stops.sorted { $0.order < $1.order }
    }

    var date: Date? {
        trip?.dateForDayOffset(dayOffset)
    }

    /// Sights only — used to decide if a day feels too full.
    var sightCount: Int {
        stops.filter { $0.role == .sight }.count
    }

    var feelsFull: Bool {
        sightCount >= 6 || stops.count >= 8
    }

    func reindexOrders() {
        for (index, stop) in orderedStops.enumerated() {
            stop.order = index
        }
    }
}
