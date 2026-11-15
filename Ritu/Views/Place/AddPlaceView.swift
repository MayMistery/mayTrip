
import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddPlaceView: View {
    var trip: Trip
    var dayPlan: DayPlan?
    var initialCoordinate: CLLocationCoordinate2D?
    var initialQuery: String = ""
    var onFinished: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [PlaceSearchResult] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var name = ""
    @State private var nameSecondary = ""
    @State private var address = ""
    @State private var hours = ""
    @State private var note = ""
    @State private var bookingRef = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var assignToDay = true
    @FocusState private var queryFocused: Bool

    private let search = PlaceSearchRouter()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "place.search"), text: $query)
                        .textInputAutocapitalization(.never)
                        .focused($queryFocused)
                        .onSubmit { Task { await runSearch() } }
                    if isSearching {
                        ProgressView()
                    }
                    if let errorText {
                        Text(errorText).foregroundStyle(.secondary)
                    }
                    ForEach(results) { result in
                        Button {
                            apply(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .foregroundStyle(.primary)
                                if !result.address.isEmpty {
                                    Text(result.address)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField(String(localized: "place.name"), text: $name)
                    TextField(String(localized: "place.nameSecondary"), text: $nameSecondary)
                    TextField(String(localized: "place.address"), text: $address, axis: .vertical)
                        .lineLimit(2...4)
                    TextField(String(localized: "place.hours"), text: $hours)
                    TextField(String(localized: "place.note"), text: $note, axis: .vertical)
                        .lineLimit(2...5)
                    TextField(String(localized: "place.bookingRef"), text: $bookingRef)
                    if dayPlan != nil {
                        Toggle(String(localized: "place.addToDay"), isOn: $assignToDay)
                    }
                } footer: {
                    if let coordinate {
                        Text(String(format: "WGS-84  %.4f, %.4f", coordinate.latitude, coordinate.longitude))
                            .font(.footnote.monospacedDigit())
                    } else if initialCoordinate != nil {
                        Text(String(localized: "place.droppedPin"))
                    }
                }
            }
            .navigationTitle(String(localized: "add.place"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.add")) { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || resolvedCoordinate == nil)
                        .fontWeight(.semibold)
                }
            }
            .task { await prepare() }
            .onChange(of: query) { _, _ in
                errorText = nil
            }
        }
    }

    private var resolvedCoordinate: CLLocationCoordinate2D? {
        coordinate ?? initialCoordinate
    }

    private func prepare() async {
        if !initialQuery.isEmpty {
            query = initialQuery
            name = initialQuery
            await runSearch()
        }
        if let initialCoordinate {
            coordinate = initialCoordinate
            if name.isEmpty {
                name = String(localized: "place.droppedPin")
            }
            await reverseIfNeeded()
        }
        queryFocused = true
    }

    private func runSearch() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        let center = resolvedCoordinate
            ?? trip.dayPlan(forOffset: dayPlan?.dayOffset ?? 0)?.orderedStops.first(where: { $0.coordinateIsValid })?.coordinate
            ?? trip.stays.first?.coordinate
        do {
            results = try await search.search(query: text, near: center, kind: .any)
            if results.isEmpty {
                errorText = String(localized: "search.empty")
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func apply(_ result: PlaceSearchResult) {
        name = result.name
        nameSecondary = result.nameSecondary
        address = result.address
        hours = result.hoursText
        coordinate = result.coordinate
        results = []
        query = result.name
    }

    private func reverseIfNeeded() async {
        guard let coordinate, address.isEmpty else { return }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            address = [placemark.name, placemark.thoroughfare, placemark.locality, placemark.country]
                .compactMap { $0 }
                .uniqued()
                .joined(separator: "，")
        }
    }

    private func save() {
        guard let coordinate = resolvedCoordinate else { return }
        let place = Place(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            nameSecondary: nameSecondary.trimmingCharacters(in: .whitespacesAndNewlines),
            address: address.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        place.hoursText = hours
        place.note = note
        place.bookingRef = bookingRef
        context.insert(place)
        place.trip = trip
        trip.places.append(place)
        if assignToDay, let dayPlan {
            DayAssembly.addPlace(place, to: dayPlan)
        }
        try? context.save()
        onFinished()
        dismiss()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
