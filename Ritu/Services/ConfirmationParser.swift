
import Foundation

/// A deliberately simple, honest parser. It is not TripIt: it does not
/// understand arbitrary airline emails, and it never invents missing fields.
enum ConfirmationParser {
    struct Draft: Equatable {
        enum Kind: Equatable {
            case transfer
            case stay
            case place
            case unknown
        }

        var kind: Kind = .unknown
        var transferKind: TransferKind = .flight
        var legs: [LegDraft] = []
        var name: String = ""
        var address: String = ""
        var bookingRef: String = ""
        var note: String = ""
        var checkIn: Date?
        var checkOut: Date?
        var query: String = ""
        var warnings: [String] = []
    }

    struct LegDraft: Equatable {
        var serviceNumber: String = ""
        var airlineOrOperator: String = ""
        var originCode: String = ""
        var originName: String = ""
        var destinationCode: String = ""
        var destinationName: String = ""
        var departureAt: Date?
        var arrivalAt: Date?
        var originTimeZoneIdentifier: String = ""
        var destinationTimeZoneIdentifier: String = ""
    }

    static func parse(_ raw: String, referenceYear: Int = Calendar.current.component(.year, from: Date())) -> Draft {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var draft = Draft()
        draft.note = text
        draft.query = firstMeaningfulLine(of: text)

        if let ref = firstMatch(in: text, pattern: #"(?i)(?:confirmation|booking|确认号|订单号|PNR)[:：#\s]*([A-Z0-9]{5,8})"#) {
            draft.bookingRef = ref.uppercased()
        }

        let flightTokens = flightNumbers(in: text)
        let airportPairs = airportPairs(in: text)
        let looksLikeStay = containsStayKeyword(text)
        let looksLikeRail = containsRailKeyword(text)
        let looksLikeBus = containsBusKeyword(text)

        if !flightTokens.isEmpty || (!airportPairs.isEmpty && !looksLikeStay) {
            draft.kind = .transfer
            draft.transferKind = looksLikeRail ? .train : (looksLikeBus ? .bus : .flight)
            draft.legs = buildLegs(
                text: text,
                flightTokens: flightTokens,
                pairs: airportPairs,
                referenceYear: referenceYear
            )
            if draft.legs.isEmpty {
                draft.warnings.append(String(localized: "paste.warning.incompleteTransfer"))
            } else {
                draft.warnings.append(String(localized: "paste.warning.confirmTimes"))
            }
            return draft
        }

        if looksLikeStay {
            draft.kind = .stay
            draft.name = stayName(from: text)
            draft.address = stayAddress(from: text)
            let dates = dates(in: text, referenceYear: referenceYear)
            if dates.count >= 1 { draft.checkIn = dates[0] }
            if dates.count >= 2 { draft.checkOut = dates[1] }
            if draft.name.isEmpty {
                draft.warnings.append(String(localized: "paste.warning.stayName"))
            }
            return draft
        }

        if !text.isEmpty {
            draft.kind = .place
            draft.name = draft.query
            draft.warnings.append(String(localized: "paste.warning.searchPlace"))
        }
        return draft
    }

    // MARK: - Flights

    private static func flightNumbers(in text: String) -> [String] {
        let pattern = #"\b([A-Z]{2}|[A-Z]\d|\d[A-Z])\s?(\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let airline = Range(match.range(at: 1), in: text),
                  let number = Range(match.range(at: 2), in: text) else { return nil }
            let token = text[airline] + text[number]
            // Avoid matching random short words followed by years, e.g. "IN 2027".
            if text[airline].count == 2, Int(text[number]) ?? 0 >= 1900, text[number].count == 4 {
                return nil
            }
            return token.uppercased()
        }
    }

    private static func airportPairs(in text: String) -> [(String, String)] {
        let pattern = #"\b([A-Z]{3})\s*[-–—到至→>]+\s*([A-Z]{3})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let a = Range(match.range(at: 1), in: text),
                  let b = Range(match.range(at: 2), in: text) else { return nil }
            return (text[a].uppercased(), text[b].uppercased())
        }
    }

    private static func buildLegs(
        text: String,
        flightTokens: [String],
        pairs: [(String, String)],
        referenceYear: Int
    ) -> [LegDraft] {
        let times = clockTimes(in: text)
        let foundDates = dates(in: text, referenceYear: referenceYear)
        let count = max(flightTokens.count, pairs.count, 1)
        var legs: [LegDraft] = []
        for index in 0..<count {
            var leg = LegDraft()
            if index < flightTokens.count {
                leg.serviceNumber = flightTokens[index]
            }
            if index < pairs.count {
                leg.originCode = pairs[index].0
                leg.destinationCode = pairs[index].1
            } else if index == 0, let inferred = inferPairFromCodes(in: text) {
                leg.originCode = inferred.0
                leg.destinationCode = inferred.1
            }
            if let origin = AirportCatalog.airport(iata: leg.originCode) {
                leg.originName = origin.nameZH
                leg.originTimeZoneIdentifier = origin.timeZoneIdentifier
            }
            if let destination = AirportCatalog.airport(iata: leg.destinationCode) {
                leg.destinationName = destination.nameZH
                leg.destinationTimeZoneIdentifier = destination.timeZoneIdentifier
            }
            let date = foundDates[safe: index] ?? foundDates.first
            let departClock = times[safe: index * 2]
            let arriveClock = times[safe: index * 2 + 1]
            if let date, let departClock {
                let zone = TimeZone(identifier: leg.originTimeZoneIdentifier) ?? .current
                leg.departureAt = combining(date: date, clock: departClock, timeZone: zone)
            }
            if let date, let arriveClock {
                let zone = TimeZone(identifier: leg.destinationTimeZoneIdentifier) ?? .current
                var arrival = combining(date: date, clock: arriveClock, timeZone: zone)
                if let departure = leg.departureAt, arrival <= departure {
                    arrival = arrival.addingTimeInterval(24 * 60 * 60)
                }
                leg.arrivalAt = arrival
            }
            legs.append(leg)
        }
        if legs.count == 1, legs[0].originCode.isEmpty, legs[0].serviceNumber.isEmpty {
            return []
        }
        return legs
    }

    private static func inferPairFromCodes(in text: String) -> (String, String)? {
        let pattern = #"\b([A-Z]{3})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let codes = regex.matches(in: text, range: range).compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: text) else { return nil }
            let code = text[r].uppercased()
            return AirportCatalog.airport(iata: code) == nil ? nil : code
        }
        guard codes.count >= 2 else { return nil }
        return (codes[0], codes[1])
    }

    // MARK: - Places & stays

    private static func containsStayKeyword(_ text: String) -> Bool {
        let keys = ["hotel", "hostel", "airbnb", "riads", "酒店", "宾馆", "民宿", "住宿", "check-in", "check in", "入住", "退房"]
        let lower = text.lowercased()
        return keys.contains { lower.contains($0) }
    }

    private static func containsRailKeyword(_ text: String) -> Bool {
        let keys = ["train", "renfe", "ave", "铁路", "高铁", "火车", "车站"]
        let lower = text.lowercased()
        return keys.contains { lower.contains($0) }
    }

    private static func containsBusKeyword(_ text: String) -> Bool {
        let keys = ["bus", "coach", "flixbus", "大巴", "巴士", "汽车票"]
        let lower = text.lowercased()
        return keys.contains { lower.contains($0) }
    }

    private static func stayName(from text: String) -> String {
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed.lowercased().hasPrefix("check") { continue }
            if trimmed.contains("入住") || trimmed.contains("退房") { continue }
            return trimmed
        }
        return ""
    }

    private static func stayAddress(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if lines.count >= 2 { return lines[1] }
        return ""
    }

    private static func firstMeaningfulLine(of text: String) -> String {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? text
    }

    // MARK: - Dates and times

    private static func clockTimes(in text: String) -> [(Int, Int)] {
        let pattern = #"\b([01]?\d|2[0-3])[:.：]([0-5]\d)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let h = Range(match.range(at: 1), in: text),
                  let m = Range(match.range(at: 2), in: text),
                  let hour = Int(text[h]), let minute = Int(text[m]) else { return nil }
            return (hour, minute)
        }
    }

    private static func dates(in text: String, referenceYear: Int) -> [Date] {
        var results: [Date] = []
        let patterns = [
            #"\b(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})日?\b"#,
            #"\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b"#
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                if index == 0,
                   let y = int(text, match, 1),
                   let m = int(text, match, 2),
                   let d = int(text, match, 3) {
                    results.append(CivilTime.date(year: y, month: m, day: d, timeZone: .current))
                } else if index == 1,
                          let a = int(text, match, 1),
                          let b = int(text, match, 2),
                          let y = int(text, match, 3) {
                    // Prefer day-month when the first number is > 12; otherwise month-day.
                    let (month, day) = a > 12 ? (b, a) : (a, b)
                    results.append(CivilTime.date(year: y, month: month, day: day, timeZone: .current))
                }
            }
        }

        let monthNames = [
            "january": 1, "jan": 1, "february": 2, "feb": 2, "march": 3, "mar": 3,
            "april": 4, "apr": 4, "may": 5, "june": 6, "jun": 6, "july": 7, "jul": 7,
            "august": 8, "aug": 8, "september": 9, "sep": 9, "sept": 9,
            "october": 10, "oct": 10, "november": 11, "nov": 11, "december": 12, "dec": 12
        ]
        let named = #"\b(\d{1,2})\s+([A-Za-z]{3,9})\s+(\d{4})?\b"#
        if let regex = try? NSRegularExpression(pattern: named) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, range: range) {
                guard let d = int(text, match, 1),
                      let monthRange = Range(match.range(at: 2), in: text) else { continue }
                let monthKey = text[monthRange].lowercased()
                guard let month = monthNames[monthKey] else { continue }
                let year: Int
                if match.range(at: 3).location != NSNotFound, let y = int(text, match, 3) {
                    year = y
                } else {
                    year = referenceYear
                }
                results.append(CivilTime.date(year: year, month: month, day: d, timeZone: .current))
            }
        }
        return results
    }

    private static func combining(date: Date, clock: (Int, Int), timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = clock.0
        components.minute = clock.1
        components.timeZone = timeZone
        return calendar.date(from: components) ?? date
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    private static func int(_ text: String, _ match: NSTextCheckingResult, _ index: Int) -> Int? {
        guard let r = Range(match.range(at: index), in: text) else { return nil }
        return Int(text[r])
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
