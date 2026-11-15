
import SwiftUI
import SwiftData
import PhotosUI

struct CreateTripView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: Trip?

    @State private var name = ""
    @State private var cities = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(5 * 24 * 60 * 60)
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var photoItem: PhotosPickerItem?
    @State private var coverData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "trip.field.name"), text: $name)
                    TextField(String(localized: "trip.field.cities"), text: $cities, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section {
                    DatePicker(String(localized: "trip.field.start"), selection: $startDate, displayedComponents: .date)
                    DatePicker(String(localized: "trip.field.end"), selection: $endDate, in: startDate..., displayedComponents: .date)
                    Picker(String(localized: "trip.field.timezone"), selection: $timeZoneIdentifier) {
                        ForEach(suggestedTimeZones, id: \.self) { identifier in
                            Text(timeZoneLabel(identifier)).tag(identifier)
                        }
                    }
                } footer: {
                    Text(String(localized: "trip.field.timezone.footer"))
                }
                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        HStack {
                            Text(String(localized: "trip.field.cover"))
                            Spacer()
                            if coverData != nil {
                                Text(String(localized: "trip.field.cover.set"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if coverData != nil {
                        Button(String(localized: "trip.field.cover.remove"), role: .destructive) {
                            coverData = nil
                            photoItem = nil
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? String(localized: "trip.new") : String(localized: "trip.edit"))
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
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
            .onChange(of: startDate) { _, newValue in
                if endDate < newValue { endDate = newValue }
            }
        }
    }

    private var suggestedTimeZones: [String] {
        var identifiers = [
            TimeZone.current.identifier,
            "Asia/Shanghai",
            "Asia/Hong_Kong",
            "Asia/Tokyo",
            "Europe/Madrid",
            "Europe/Lisbon",
            "Europe/Paris",
            "Europe/London",
            "America/New_York",
            "America/Los_Angeles"
        ]
        if !identifiers.contains(timeZoneIdentifier) {
            identifiers.insert(timeZoneIdentifier, at: 0)
        }
        return Array(NSOrderedSet(array: identifiers)) as? [String] ?? identifiers
    }

    private func timeZoneLabel(_ identifier: String) -> String {
        let known: [String: String] = [
            "Asia/Shanghai": "中国（上海 / 北京）",
            "Asia/Hong_Kong": "香港",
            "Asia/Tokyo": "东京",
            "Europe/Madrid": "马德里",
            "Europe/Lisbon": "里斯本",
            "Europe/Paris": "巴黎",
            "Europe/London": "伦敦",
            "America/New_York": "纽约",
            "America/Los_Angeles": "洛杉矶"
        ]
        if let label = known[identifier] { return "\(label) · \(identifier)" }
        return identifier
    }

    private func hydrate() {
        guard let existing else { return }
        name = existing.name
        cities = existing.citiesText
        startDate = existing.startDate
        endDate = existing.endDate
        timeZoneIdentifier = existing.timeZoneIdentifier
        coverData = existing.coverImageData
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing {
            existing.name = trimmed
            existing.citiesText = cities.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.startDate = startDate
            existing.endDate = endDate
            existing.timeZoneIdentifier = timeZoneIdentifier
            existing.coverImageData = coverData
            DayAssembly.ensureDayPlans(for: existing, in: context)
        } else {
            let trip = Trip(
                name: trimmed,
                startDate: startDate,
                endDate: endDate,
                citiesText: cities.trimmingCharacters(in: .whitespacesAndNewlines),
                timeZoneIdentifier: timeZoneIdentifier
            )
            trip.coverImageData = coverData
            context.insert(trip)
            DayAssembly.ensureDayPlans(for: trip, in: context)
        }
        try? context.save()
        dismiss()
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        #if canImport(UIKit)
        coverData = ImageStorage.jpegData(from: data, maxPixel: 2000) ?? data
        #else
        coverData = data
        #endif
    }
}
