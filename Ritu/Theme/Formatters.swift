
import Foundation

enum Formatters {
    static func dayRibbonLabel(date: Date, calendar: Calendar) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let weekdayText = symbols[(weekday - 1 + symbols.count) % symbols.count]
        let day = calendar.component(.day, from: date)
        return "\(weekdayText) \(day)"
    }

    static func longDayTitle(date: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return formatter.string(from: date)
    }

    static func tripDateRange(start: Date, end: Date, calendar: Calendar, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        let year = calendar.component(.year, from: end)
        return "\(startText) – \(endText)，\(year)"
    }

    static func clock(date: Date, timeZone: TimeZone, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter.string(from: date)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours == 0 {
            return String(format: String(localized: "duration.minutes %lld"), minutes)
        }
        if minutes == 0 {
            return String(format: String(localized: "duration.hours %lld"), hours)
        }
        return String(format: String(localized: "duration.hoursMinutes %lld %lld"), hours, minutes)
    }

    static func duration(seconds: Int) -> String {
        duration(TimeInterval(seconds))
    }
}
