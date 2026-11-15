
import SwiftUI
import SwiftData
import CoreLocation

struct StayEditorView: View {
    var trip: Trip
    var stay: Stay?
    var prefilled: ConfirmationParser.Draft? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameSecondary = ""
    @State private var address = ""
    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var checkInDate = Date()
    @State private var checkOutDate = Date()
    @State private var checkInTime = Date()
    @State private var checkOutTime = Date()
    @State private var includeCheckInTime = true
    @State private var includeCheckOutTime = true
    @State private var bookingRef = ""
    @State private var note = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var confirmDelete = false

    private let search = PlaceSearchRouter()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "stay.search"), text: $query)
                        .onSubmit { Task { await runSearch() } }
                    if isSearching { ProgressView() }
                    ForEach(results) { result in
                        Button {
                            name = result.name
                            address = result.address
                            latitude = result.coordinate.latitude
                            longitude = result.coordinate.longitude
                            results = []
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).foregroundStyle(.primary)
                                Text(result.address).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    TextField(String(localized: "stay.name"), text: $name)
                    TextField(String(localized: "place.nameSecondary"), text: $nameSecondary)
                    TextField(String(localized: "place.address"), text: $address, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section {
                    DatePicker(String(localized: "stay.checkInDate"), selection: $checkInDate, displayedComponents: .date)
                    Toggle(String(localized: "stay.includeCheckInTime"), isOn: $includeCheckInTime)
                    if includeCheckInTime {
                        DatePicker(String(localized: "stay.checkInTime"), selection: $checkInTime, displayedComponents: .hourAndMinute)
                    }
                    DatePicker(String(localized: "stay.checkOutDate"), selection: $checkOutDate, in: checkInDate..., displayedComponents: .date)
                    Toggle(String(localized: "stay.includeCheckOutTime"), isOn: $includeCheckOutTime)
                    if includeCheckOutTime {
                        DatePicker(String(localized: "stay.checkOutTime"), selection: $checkOutTime, displayedComponents: .hourAndMinute)
                    }
                }
                Section {
                    TextField(String(localized: "place.bookingRef"), text: $bookingRef)
                    TextField(String(localized: "place.note"), text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }
                if stay != nil {
                    Section {
                        Button(String(localized: "stay.delete"), role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(stay == nil ? String(localized: "add.stay") : String(localized: "stay.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: hydrate)
            .confirmationDialog(String(localized: "stay.delete"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(String(localized: "stay.delete"), role: .destructive) {
                    if let stay {
                        DayAssembly.deleteStay(stay, from: trip, context: context)
                        try? context.save()
                    }
                    dismiss()
                }
                Button(String(localized: "action.cancel"), role: .cancel) {}
            }
        }
    }

    private func hydrate() {
        let calendar = trip.calendar
        if let prefilled, prefilled.kind == .stay {
            name = prefilled.name
            address = prefilled.address
            bookingRef = prefilled.bookingRef
            note = prefilled.note
            if let checkIn = prefilled.checkIn { checkInDate = checkIn }
            if let checkOut = prefilled.checkOut { checkOutDate = checkOut }
            query = prefilled.name
            return
        }
        if let stay {
            name = stay.name
            nameSecondary = stay.nameSecondary
            address = stay.address
            checkInDate = stay.checkInDate
            checkOutDate = stay.checkOutDate
            bookingRef = stay.bookingRef
            note = stay.note
            latitude = stay.latitude
            longitude = stay.longitude
            includeCheckInTime = stay.checkInMinuteOfDay >= 0
            includeCheckOutTime = stay.checkOutMinuteOfDay >= 0
            let display = Calendar.current
            let inMinute = stay.checkInMinuteOfDay >= 0 ? stay.checkInMinuteOfDay : 15 * 60
            let outMinute = stay.checkOutMinuteOfDay >= 0 ? stay.checkOutMinuteOfDay : 11 * 60
            if let date = CivilTime.applying(minuteOfDay: inMinute, to: Date(), calendar: display) {
                checkInTime = date
            }
            if let date = CivilTime.applying(minuteOfDay: outMinute, to: Date(), calendar: display) {
                checkOutTime = date
            }
        } else {
            checkInDate = trip.dateForDayOffset(0)
            checkOutDate = trip.endDate
            if let inTime = CivilTime.applying(minuteOfDay: 15 * 60, to: checkInDate, calendar: calendar) {
                checkInTime = inTime
            }
            if let outTime = CivilTime.applying(minuteOfDay: 11 * 60, to: checkOutDate, calendar: calendar) {
                checkOutTime = outTime
            }
        }
    }

    private func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude).isValidCoordinate
            ? CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            : trip.stays.last?.coordinate
        results = (try? await search.search(query: text, near: center, kind: .lodging)) ?? []
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let target: Stay
        if let stay {
            target = stay
        } else {
            let created = Stay(
                name: trimmed,
                address: address,
                latitude: latitude,
                longitude: longitude,
                checkInDate: checkInDate,
                checkOutDate: max(checkOutDate, checkInDate)
            )
            context.insert(created)
            created.trip = trip
            trip.stays.append(created)
            target = created
        }
        target.name = trimmed
        target.nameSecondary = nameSecondary
        target.address = address
        target.checkInDate = checkInDate
        target.checkOutDate = max(checkOutDate, checkInDate)
        target.bookingRef = bookingRef
        target.note = note
        target.latitude = latitude
        target.longitude = longitude
        target.checkInMinuteOfDay = includeCheckInTime ? CivilTime.minuteOfDay(from: checkInTime, timeZone: .current) : -1
        target.checkOutMinuteOfDay = includeCheckOutTime ? CivilTime.minuteOfDay(from: checkOutTime, timeZone: .current) : -1
        DayAssembly.syncStayAnchors(target, in: trip, context: context)
        try? context.save()
        dismiss()
    }
}
