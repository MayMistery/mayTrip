
import SwiftUI
import SwiftData

struct TransferEditorView: View {
    var trip: Trip
    var transfer: Transfer?
    var prefilled: ConfirmationParser.Draft?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TransferKind = .flight
    @State private var bookingRef = ""
    @State private var note = ""
    @State private var legs: [LegDraft] = [LegDraft()]
    @State private var confirmDelete = false

    struct LegDraft: Identifiable {
        var id = UUID()
        var serviceNumber = ""
        var airlineOrOperator = ""
        var originCode = ""
        var originName = ""
        var destinationCode = ""
        var destinationName = ""
        var departureAt = Date()
        var arrivalAt = Date().addingTimeInterval(3600)
        var originTimeZoneIdentifier = TimeZone.current.identifier
        var destinationTimeZoneIdentifier = TimeZone.current.identifier
        var originLatitude: Double = 0
        var originLongitude: Double = 0
        var destinationLatitude: Double = 0
        var destinationLongitude: Double = 0
        var originAddress = ""
        var destinationAddress = ""
        var existingID: UUID?
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "transfer.kind"), selection: $kind) {
                        ForEach(TransferKind.allCases) { item in
                            Text(String(localized: item.localizedName)).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                ForEach($legs) { $leg in
                    Section(header: Text(legTitle(leg))) {
                        if kind == .flight || kind == .train {
                            TextField(kind == .flight ? String(localized: "transfer.flightNumber") : String(localized: "transfer.trainNumber"), text: $leg.serviceNumber)
                                .textInputAutocapitalization(.characters)
                            TextField(String(localized: "transfer.operator"), text: $leg.airlineOrOperator)
                        }
                        TextField(String(localized: "transfer.origin"), text: $leg.originCode)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: leg.originCode) { _, newValue in
                                applyAirport(newValue, toOriginOfBinding: $leg)
                            }
                        TextField(String(localized: "transfer.originName"), text: $leg.originName)
                        DatePicker(String(localized: "transfer.depart"), selection: $leg.departureAt)
                        TextField(String(localized: "transfer.destination"), text: $leg.destinationCode)
                            .textInputAutocapitalization(.characters)
                            .onChange(of: leg.destinationCode) { _, newValue in
                                applyAirport(newValue, toDestinationOfBinding: $leg)
                            }
                        TextField(String(localized: "transfer.destinationName"), text: $leg.destinationName)
                        DatePicker(String(localized: "transfer.arrive"), selection: $leg.arrivalAt)
                        if !leg.originName.isEmpty || !leg.destinationName.isEmpty {
                            Text(zoneHint(leg))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button(String(localized: "transfer.addLeg")) {
                        var next = LegDraft()
                        if let last = legs.last {
                            next.originCode = last.destinationCode
                            next.originName = last.destinationName
                            next.originTimeZoneIdentifier = last.destinationTimeZoneIdentifier
                            next.originLatitude = last.destinationLatitude
                            next.originLongitude = last.destinationLongitude
                            next.departureAt = last.arrivalAt.addingTimeInterval(90 * 60)
                            next.arrivalAt = next.departureAt.addingTimeInterval(3600)
                        }
                        legs.append(next)
                    }
                    if legs.count > 1 {
                        Button(String(localized: "transfer.removeLastLeg"), role: .destructive) {
                            _ = legs.popLast()
                        }
                    }
                }
                Section {
                    TextField(String(localized: "place.bookingRef"), text: $bookingRef)
                    TextField(String(localized: "place.note"), text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                if transfer != nil {
                    Section {
                        Button(String(localized: "transfer.delete"), role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(transfer == nil ? String(localized: "add.transfer") : String(localized: "transfer.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: hydrate)
            .confirmationDialog(String(localized: "transfer.delete"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(String(localized: "transfer.delete"), role: .destructive) {
                    if let transfer {
                        DayAssembly.deleteTransfer(transfer, from: trip, context: context)
                        try? context.save()
                    }
                    dismiss()
                }
                Button(String(localized: "action.cancel"), role: .cancel) {}
            }
        }
    }

    private func legTitle(_ leg: LegDraft) -> String {
        let index = (legs.firstIndex(where: { $0.id == leg.id }) ?? 0) + 1
        return String(format: String(localized: "transfer.leg %lld"), index)
    }

    private func zoneHint(_ leg: LegDraft) -> String {
        let depart = Formatters.clock(date: leg.departureAt, timeZone: TimeZone(identifier: leg.originTimeZoneIdentifier) ?? trip.timeZone)
        let arrive = Formatters.clock(date: leg.arrivalAt, timeZone: TimeZone(identifier: leg.destinationTimeZoneIdentifier) ?? trip.timeZone)
        return "\(depart) → \(arrive)"
    }

    private func applyAirport(_ raw: String, toOriginOfBinding leg: Binding<LegDraft>) {
        var value = leg.wrappedValue
        applyAirport(raw, toOrigin: true, of: &value)
        leg.wrappedValue = value
    }

    private func applyAirport(_ raw: String, toDestinationOfBinding leg: Binding<LegDraft>) {
        var value = leg.wrappedValue
        applyAirport(raw, toOrigin: false, of: &value)
        leg.wrappedValue = value
    }

    private func applyAirport(_ raw: String, toOrigin: Bool, of leg: inout LegDraft) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let airport = AirportCatalog.airport(iata: code) else { return }
        if toOrigin {
            leg.originCode = airport.iata
            if leg.originName.isEmpty { leg.originName = airport.nameZH }
            leg.originTimeZoneIdentifier = airport.timeZoneIdentifier
            leg.originLatitude = airport.latitude
            leg.originLongitude = airport.longitude
            leg.originAddress = airport.bilingualName
        } else {
            leg.destinationCode = airport.iata
            if leg.destinationName.isEmpty { leg.destinationName = airport.nameZH }
            leg.destinationTimeZoneIdentifier = airport.timeZoneIdentifier
            leg.destinationLatitude = airport.latitude
            leg.destinationLongitude = airport.longitude
            leg.destinationAddress = airport.bilingualName
        }
    }

    private func hydrate() {
        if let prefilled, prefilled.kind == .transfer {
            kind = prefilled.transferKind
            bookingRef = prefilled.bookingRef
            if !prefilled.note.isEmpty { note = prefilled.note }
            if !prefilled.legs.isEmpty {
                legs = prefilled.legs.map { draft in
                    var leg = LegDraft()
                    fill(&leg, from: draft)
                    return leg
                }
            }
            return
        }
        guard let transfer else { return }
        kind = transfer.kind
        bookingRef = transfer.bookingRef
        note = transfer.note
        if !transfer.orderedLegs.isEmpty {
            legs = transfer.orderedLegs.map { model in
                var draft = LegDraft()
                draft.existingID = model.id
                draft.serviceNumber = model.serviceNumber
                draft.airlineOrOperator = model.airlineOrOperator
                draft.originCode = model.originCode
                draft.originName = model.originName
                draft.destinationCode = model.destinationCode
                draft.destinationName = model.destinationName
                draft.departureAt = model.departureAt
                draft.arrivalAt = model.arrivalAt
                draft.originTimeZoneIdentifier = model.originTimeZoneIdentifier.isEmpty ? trip.timeZoneIdentifier : model.originTimeZoneIdentifier
                draft.destinationTimeZoneIdentifier = model.destinationTimeZoneIdentifier.isEmpty ? trip.timeZoneIdentifier : model.destinationTimeZoneIdentifier
                draft.originLatitude = model.originLatitude
                draft.originLongitude = model.originLongitude
                draft.destinationLatitude = model.destinationLatitude
                draft.destinationLongitude = model.destinationLongitude
                draft.originAddress = model.originAddress
                draft.destinationAddress = model.destinationAddress
                return draft
            }
        }
    }

    private func fill(_ leg: inout LegDraft, from draft: ConfirmationParser.LegDraft) {
        leg.serviceNumber = draft.serviceNumber
        leg.airlineOrOperator = draft.airlineOrOperator
        leg.originCode = draft.originCode
        leg.originName = draft.originName
        leg.destinationCode = draft.destinationCode
        leg.destinationName = draft.destinationName
        if let departure = draft.departureAt { leg.departureAt = departure }
        if let arrival = draft.arrivalAt { leg.arrivalAt = arrival }
        if !draft.originTimeZoneIdentifier.isEmpty { leg.originTimeZoneIdentifier = draft.originTimeZoneIdentifier }
        if !draft.destinationTimeZoneIdentifier.isEmpty { leg.destinationTimeZoneIdentifier = draft.destinationTimeZoneIdentifier }
        if let airport = AirportCatalog.airport(iata: draft.originCode) {
            applyAirport(airport.iata, toOrigin: true, of: &leg)
        }
        if let airport = AirportCatalog.airport(iata: draft.destinationCode) {
            applyAirport(airport.iata, toOrigin: false, of: &leg)
        }
    }

    private func save() {
        let target: Transfer
        if let transfer {
            target = transfer
        } else {
            let created = Transfer(kind: kind)
            context.insert(created)
            created.trip = trip
            trip.transfers.append(created)
            target = created
        }
        target.kind = kind
        target.bookingRef = bookingRef
        target.note = note

        let keepIDs = Set(legs.compactMap(\.existingID))
        for existing in target.legs where !keepIDs.contains(existing.id) {
            context.delete(existing)
        }

        for (index, draft) in legs.enumerated() {
            let model: TransferLeg
            if let id = draft.existingID, let found = target.legs.first(where: { $0.id == id }) {
                model = found
            } else {
                let created = TransferLeg(order: index)
                context.insert(created)
                created.transfer = target
                target.legs.append(created)
                model = created
            }
            model.order = index
            model.serviceNumber = draft.serviceNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            model.airlineOrOperator = draft.airlineOrOperator.trimmingCharacters(in: .whitespacesAndNewlines)
            model.originCode = draft.originCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            model.originName = draft.originName
            model.destinationCode = draft.destinationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            model.destinationName = draft.destinationName
            model.departureAt = draft.departureAt
            model.arrivalAt = draft.arrivalAt
            model.originTimeZoneIdentifier = draft.originTimeZoneIdentifier
            model.destinationTimeZoneIdentifier = draft.destinationTimeZoneIdentifier
            model.originLatitude = draft.originLatitude
            model.originLongitude = draft.originLongitude
            model.destinationLatitude = draft.destinationLatitude
            model.destinationLongitude = draft.destinationLongitude
            model.originAddress = draft.originAddress
            model.destinationAddress = draft.destinationAddress
        }

        DayAssembly.syncTransferStops(target, in: trip, context: context)
        try? context.save()
        dismiss()
    }
}

extension ConfirmationParser.Draft {
    var isEmpty: Bool { kind == .unknown }
}
