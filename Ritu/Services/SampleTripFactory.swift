
import Foundation
import SwiftData
import CoreLocation

/// A short Spain–Portugal itinerary that shows the first-class objects:
/// a multi-leg arrival, nights in two cities, an inter-city hop, and
/// a day's sights with commuting between hotel and places.
enum SampleTripFactory {
    @MainActor
    static func makeSpainPortugal(in context: ModelContext) -> Trip {
        let madridTZ = TimeZone(identifier: "Europe/Madrid") ?? .current
        let lisbonTZ = TimeZone(identifier: "Europe/Lisbon") ?? madridTZ
        let shanghaiTZ = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let parisTZ = TimeZone(identifier: "Europe/Paris") ?? madridTZ

        let trip = Trip(
            name: "西班牙与葡萄牙",
            startDate: CivilTime.date(year: 2027, month: 4, day: 10, timeZone: madridTZ),
            endDate: CivilTime.date(year: 2027, month: 4, day: 15, timeZone: madridTZ),
            citiesText: "马德里、里斯本",
            timeZoneIdentifier: "Europe/Madrid"
        )
        context.insert(trip)
        DayAssembly.ensureDayPlans(for: trip, in: context)

        // Outbound: home → Madrid, with a layover. Times are illustrative.
        let outbound = Transfer(kind: .flight)
        outbound.note = "示例航段，时刻仅供演示。"
        context.insert(outbound)
        outbound.trip = trip
        trip.transfers.append(outbound)

        let pek = AirportCatalog.airport(iata: "PEK")!
        let cdg = AirportCatalog.airport(iata: "CDG")!
        let mad = AirportCatalog.airport(iata: "MAD")!
        let lis = AirportCatalog.airport(iata: "LIS")!

        let leg1 = TransferLeg(order: 0)
        leg1.airlineOrOperator = "CA"
        leg1.serviceNumber = "897"
        apply(airport: pek, toOriginOf: leg1)
        apply(airport: cdg, toDestinationOf: leg1)
        leg1.departureAt = CivilTime.date(year: 2027, month: 4, day: 10, hour: 1, minute: 30, timeZone: shanghaiTZ)
        leg1.arrivalAt = CivilTime.date(year: 2027, month: 4, day: 10, hour: 8, minute: 45, timeZone: parisTZ)
        leg1.transfer = outbound
        context.insert(leg1)
        outbound.legs.append(leg1)

        let leg2 = TransferLeg(order: 1)
        leg2.airlineOrOperator = "AF"
        leg2.serviceNumber = "1100"
        apply(airport: cdg, toOriginOf: leg2)
        apply(airport: mad, toDestinationOf: leg2)
        leg2.departureAt = CivilTime.date(year: 2027, month: 4, day: 10, hour: 11, minute: 20, timeZone: parisTZ)
        leg2.arrivalAt = CivilTime.date(year: 2027, month: 4, day: 10, hour: 13, minute: 25, timeZone: madridTZ)
        leg2.transfer = outbound
        context.insert(leg2)
        outbound.legs.append(leg2)

        DayAssembly.syncTransferStops(outbound, in: trip, context: context)

        let madridStay = Stay(
            name: "Barrio de las Letras 住宿",
            address: "Calle de las Huertas, Madrid",
            latitude: 40.4140,
            longitude: -3.6985,
            checkInDate: CivilTime.date(year: 2027, month: 4, day: 10, timeZone: madridTZ),
            checkOutDate: CivilTime.date(year: 2027, month: 4, day: 12, timeZone: madridTZ)
        )
        madridStay.nameSecondary = "马德里文学街区"
        madridStay.checkInMinuteOfDay = 15 * 60
        madridStay.checkOutMinuteOfDay = 11 * 60
        madridStay.note = "入住日从机场到酒店；12 日早晨退房后前往机场。"
        context.insert(madridStay)
        madridStay.trip = trip
        trip.stays.append(madridStay)
        DayAssembly.syncStayAnchors(madridStay, in: trip, context: context)

        // Madrid sights on 11 April.
        let prado = makePlace(
            name: "普拉多博物馆",
            secondary: "Museo Nacional del Prado",
            address: "Paseo del Prado, s/n, 28014 Madrid",
            latitude: 40.4138,
            longitude: -3.6921,
            hours: "10:00 – 20:00",
            note: "建议先在网上预约时段。"
        )
        let retiro = makePlace(
            name: "丽池公园",
            secondary: "Parque del Retiro",
            address: "Plaza de la Independencia, 7, 28001 Madrid",
            latitude: 40.4153,
            longitude: -3.6844,
            hours: "园门清晨至夜间",
            note: "可以走到水晶宫。"
        )
        let mayor = makePlace(
            name: "主广场",
            secondary: "Plaza Mayor",
            address: "Plaza Mayor, 28012 Madrid",
            latitude: 40.4155,
            longitude: -3.7074,
            hours: "",
            note: ""
        )
        for place in [prado, retiro, mayor] {
            context.insert(place)
            place.trip = trip
            trip.places.append(place)
        }
        if let april11 = trip.dayPlan(forOffset: 1) {
            DayAssembly.addPlace(prado, to: april11)
            DayAssembly.addPlace(retiro, to: april11)
            DayAssembly.addPlace(mayor, to: april11)
        }

        // Madrid → Lisbon on 12 April (open-jaw continuation).
        let hop = Transfer(kind: .flight)
        hop.note = "跨城转机，示例航班。"
        context.insert(hop)
        hop.trip = trip
        trip.transfers.append(hop)

        let hopLeg = TransferLeg(order: 0)
        hopLeg.airlineOrOperator = "IB"
        hopLeg.serviceNumber = "3171"
        apply(airport: mad, toOriginOf: hopLeg)
        apply(airport: lis, toDestinationOf: hopLeg)
        hopLeg.departureAt = CivilTime.date(year: 2027, month: 4, day: 12, hour: 14, minute: 15, timeZone: madridTZ)
        hopLeg.arrivalAt = CivilTime.date(year: 2027, month: 4, day: 12, hour: 14, minute: 35, timeZone: lisbonTZ)
        hopLeg.transfer = hop
        context.insert(hopLeg)
        hop.legs.append(hopLeg)
        DayAssembly.syncTransferStops(hop, in: trip, context: context)

        let lisbonStay = Stay(
            name: "Alfama 住宿",
            address: "Rua de São Pedro, Lisboa",
            latitude: 38.7110,
            longitude: -9.1280,
            checkInDate: CivilTime.date(year: 2027, month: 4, day: 12, timeZone: lisbonTZ),
            checkOutDate: CivilTime.date(year: 2027, month: 4, day: 15, timeZone: lisbonTZ)
        )
        lisbonStay.nameSecondary = "里斯本阿尔法玛"
        lisbonStay.checkInMinuteOfDay = 15 * 60
        lisbonStay.checkOutMinuteOfDay = 11 * 60
        context.insert(lisbonStay)
        lisbonStay.trip = trip
        trip.stays.append(lisbonStay)
        DayAssembly.syncStayAnchors(lisbonStay, in: trip, context: context)

        let jeronimos = makePlace(
            name: "热罗尼莫斯修道院",
            secondary: "Mosteiro dos Jerónimos",
            address: "Praça do Império 1400-206 Lisboa",
            latitude: 38.6979,
            longitude: -9.2067,
            hours: "9:30 – 18:00",
            note: "建议上午前往贝伦。"
        )
        let pasteis = makePlace(
            name: "贝伦蛋挞店",
            secondary: "Pastéis de Belém",
            address: "R. de Belém 84 92, 1300-085 Lisboa",
            latitude: 38.6972,
            longitude: -9.2032,
            hours: "8:00 – 21:00",
            note: ""
        )
        let alfama = makePlace(
            name: "阿尔法玛",
            secondary: "Alfama",
            address: "Alfama, Lisboa",
            latitude: 38.7120,
            longitude: -9.1300,
            hours: "",
            note: "傍晚走回住宿附近。"
        )
        for place in [jeronimos, pasteis, alfama] {
            context.insert(place)
            place.trip = trip
            trip.places.append(place)
        }
        if let april13 = trip.dayPlan(forOffset: 3) {
            DayAssembly.addPlace(jeronimos, to: april13)
            DayAssembly.addPlace(pasteis, to: april13)
            DayAssembly.addPlace(alfama, to: april13)
        }

        // A loose pin, so 未安排 is visible if the traveller wants to gather it.
        let lx = makePlace(
            name: "LX Factory",
            secondary: "LX Factory",
            address: "R. Rodrigues de Faria 103, 1300-501 Lisboa",
            latitude: 38.7024,
            longitude: -9.1787,
            hours: "",
            note: "还没安排进某一天。"
        )
        context.insert(lx)
        lx.trip = trip
        trip.places.append(lx)

        // Return LIS → PEK, one-stop. Illustrative.
        let inbound = Transfer(kind: .flight)
        inbound.note = "回程示例。"
        context.insert(inbound)
        inbound.trip = trip
        trip.transfers.append(inbound)

        let home1 = TransferLeg(order: 0)
        home1.airlineOrOperator = "AF"
        home1.serviceNumber = "1625"
        apply(airport: lis, toOriginOf: home1)
        apply(airport: cdg, toDestinationOf: home1)
        home1.departureAt = CivilTime.date(year: 2027, month: 4, day: 15, hour: 13, minute: 5, timeZone: lisbonTZ)
        home1.arrivalAt = CivilTime.date(year: 2027, month: 4, day: 15, hour: 16, minute: 40, timeZone: parisTZ)
        home1.transfer = inbound
        context.insert(home1)
        inbound.legs.append(home1)

        let home2 = TransferLeg(order: 1)
        home2.airlineOrOperator = "CA"
        home2.serviceNumber = "876"
        apply(airport: cdg, toOriginOf: home2)
        apply(airport: pek, toDestinationOf: home2)
        home2.departureAt = CivilTime.date(year: 2027, month: 4, day: 15, hour: 20, minute: 10, timeZone: parisTZ)
        home2.arrivalAt = CivilTime.date(year: 2027, month: 4, day: 16, hour: 12, minute: 30, timeZone: shanghaiTZ)
        home2.transfer = inbound
        context.insert(home2)
        inbound.legs.append(home2)
        DayAssembly.syncTransferStops(inbound, in: trip, context: context)

        return trip
    }

    private static func makePlace(
        name: String,
        secondary: String,
        address: String,
        latitude: Double,
        longitude: Double,
        hours: String,
        note: String
    ) -> Place {
        let place = Place(
            name: name,
            nameSecondary: secondary,
            address: address,
            latitude: latitude,
            longitude: longitude
        )
        place.hoursText = hours
        place.note = note
        return place
    }

    private static func apply(airport: AirportRecord, toOriginOf leg: TransferLeg) {
        leg.originName = airport.nameZH
        leg.originCode = airport.iata
        leg.originAddress = airport.bilingualName
        leg.originCoordinate = airport.coordinate
        leg.originTimeZoneIdentifier = airport.timeZoneIdentifier
    }

    private static func apply(airport: AirportRecord, toDestinationOf leg: TransferLeg) {
        leg.destinationName = airport.nameZH
        leg.destinationCode = airport.iata
        leg.destinationAddress = airport.bilingualName
        leg.destinationCoordinate = airport.coordinate
        leg.destinationTimeZoneIdentifier = airport.timeZoneIdentifier
    }
}
