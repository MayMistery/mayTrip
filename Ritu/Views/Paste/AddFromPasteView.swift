
import SwiftUI
import SwiftData
import UIKit

struct AddFromPasteView: View {
    var trip: Trip
    var dayPlan: DayPlan?

    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var draft = ConfirmationParser.Draft()
    @State private var showTransferEditor = false
    @State private var showStayEditor = false
    @State private var showPlaceEditor = false
    @State private var didPasteFromClipboard = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 160)
                        .font(.body)
                        .onChange(of: text) { _, newValue in
                            draft = ConfirmationParser.parse(newValue)
                        }
                    Button(String(localized: "paste.fromClipboard")) {
                        if let string = UIPasteboard.general.string, !string.isEmpty {
                            text = string
                            draft = ConfirmationParser.parse(string)
                            didPasteFromClipboard = true
                        }
                    }
                } footer: {
                    Text(String(localized: "paste.footer"))
                }

                if draft.kind != .unknown, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        LabeledContent(String(localized: "paste.detected")) {
                            Text(kindLabel)
                        }
                        if !draft.bookingRef.isEmpty {
                            LabeledContent(String(localized: "place.bookingRef")) {
                                Text(draft.bookingRef).monospacedDigit()
                            }
                        }
                        if draft.kind == .transfer {
                            ForEach(Array(draft.legs.enumerated()), id: \.offset) { _, leg in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(legLine(leg))
                                        .font(.body.weight(.medium))
                                    if let departure = leg.departureAt, let arrival = leg.arrivalAt {
                                        Text("\(Formatters.clock(date: departure, timeZone: TimeZone(identifier: leg.originTimeZoneIdentifier) ?? .current)) → \(Formatters.clock(date: arrival, timeZone: TimeZone(identifier: leg.destinationTimeZoneIdentifier) ?? .current))")
                                            .font(RituTheme.compactTimeFont)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if draft.kind == .stay {
                            Text(draft.name.isEmpty ? String(localized: "stay.untitled") : draft.name)
                            if !draft.address.isEmpty {
                                Text(draft.address).foregroundStyle(.secondary)
                            }
                        }
                        if draft.kind == .place {
                            Text(draft.name)
                        }
                        ForEach(draft.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(continueTitle) { continueWithDraft() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle(String(localized: "add.paste"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel")) { dismiss() }
                }
            }
            .sheet(isPresented: $showTransferEditor) {
                TransferEditorView(trip: trip, transfer: nil, prefilled: draft)
            }
            .sheet(isPresented: $showStayEditor) {
                StayEditorView(trip: trip, stay: nil, prefilled: draft)
            }
            .sheet(isPresented: $showPlaceEditor) {
                AddPlaceView(
                    trip: trip,
                    dayPlan: dayPlan,
                    initialQuery: draft.query.isEmpty ? draft.name : draft.query
                ) {
                    dismiss()
                }
            }
            .onChange(of: showTransferEditor) { _, presented in
                if !presented { dismiss() }
            }
            .onChange(of: showStayEditor) { _, presented in
                if !presented { dismiss() }
            }
            .onChange(of: showPlaceEditor) { _, presented in
                if !presented { dismiss() }
            }
        }
    }

    private var kindLabel: String {
        switch draft.kind {
        case .transfer: String(localized: draft.transferKind.localizedName)
        case .stay: String(localized: "add.stay")
        case .place: String(localized: "add.place")
        case .unknown: String(localized: "paste.unknown")
        }
    }

    private var continueTitle: String {
        switch draft.kind {
        case .transfer: String(localized: "paste.continue.transfer")
        case .stay: String(localized: "paste.continue.stay")
        case .place: String(localized: "paste.continue.place")
        case .unknown: String(localized: "action.done")
        }
    }

    private func legLine(_ leg: ConfirmationParser.LegDraft) -> String {
        let service = [leg.airlineOrOperator, leg.serviceNumber].filter { !$0.isEmpty }.joined(separator: " ")
        let route = [leg.originCode, leg.destinationCode].filter { !$0.isEmpty }.joined(separator: " → ")
        return [service, route].filter { !$0.isEmpty }.joined(separator: "  ·  ")
    }

    private func continueWithDraft() {
        switch draft.kind {
        case .transfer:
            showTransferEditor = true
        case .stay:
            showStayEditor = true
        case .place:
            showPlaceEditor = true
        case .unknown:
            break
        }
    }
}

