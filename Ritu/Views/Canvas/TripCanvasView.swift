
import SwiftUI
import SwiftData
import MapKit

struct TripCanvasView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedOffset = 0
    @State private var showUnscheduled = false
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedStop: DayStop?
    @State private var selectedPlace: Place?
    @State private var sheetDetent: PanelDetent = .medium
    @State private var showAddPlace = false
    @State private var showAddStay = false
    @State private var showAddTransfer = false
    @State private var showPaste = false
    @State private var showTripEdit = false
    @State private var longPressCoordinate: CLLocationCoordinate2D?
    @State private var showAddMenu = false
    @State private var toast: String?
    @State private var editingStay: Stay?
    @State private var editingTransfer: Transfer?
    @State private var isRefreshing = false
    var body: some View {
        ZStack(alignment: .top) {
            TripMapView(
                trip: trip,
                selectedOffset: selectedOffset,
                showUnscheduled: showUnscheduled,
                selectedStopID: selectedStop?.id,
                selectedPlaceID: selectedPlace?.id,
                position: $position,
                onSelectStop: { stop in
                    selectedStop = stop
                    selectedPlace = stop.place
                    if sheetDetent == .compact {
                        sheetDetent = .medium
                    }
                },
                onSelectPlace: { place in
                    selectedPlace = place
                    selectedStop = nil
                },
                onLongPress: { coordinate in
                    longPressCoordinate = coordinate
                    showAddPlace = true
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                topChrome
                Spacer()
            }
            .padding(.top, 8)

            ResizableBottomPanel(detent: $sheetDetent) { _ in
                itinerarySheet
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await setup() }
        .onChange(of: selectedOffset) { _, _ in
            selectedStop = nil
            Task { await refreshTimes() }
        }
        .sheet(isPresented: $showAddPlace) {
            AddPlaceView(
                trip: trip,
                dayPlan: trip.dayPlan(forOffset: selectedOffset),
                initialCoordinate: longPressCoordinate
            ) {
                longPressCoordinate = nil
                Task { await refreshTimes() }
            }
        }
        .sheet(isPresented: $showAddStay) {
            StayEditorView(trip: trip, stay: nil)
        }
        .sheet(item: $editingStay) { stay in
            StayEditorView(trip: trip, stay: stay)
        }
        .sheet(isPresented: $showAddTransfer) {
            TransferEditorView(trip: trip, transfer: nil)
        }
        .sheet(item: $editingTransfer) { transfer in
            TransferEditorView(trip: trip, transfer: transfer)
        }
        .sheet(isPresented: $showPaste) {
            AddFromPasteView(trip: trip, dayPlan: trip.dayPlan(forOffset: selectedOffset))
        }
        .sheet(item: $selectedPlace) { place in
            PlaceCardView(
                trip: trip,
                place: place,
                currentDay: trip.dayPlan(forOffset: selectedOffset)
            ) {
                Task { await refreshTimes() }
            }
        }
        .sheet(isPresented: $showTripEdit) {
            CreateTripView(existing: trip)
        }
        .confirmationDialog(String(localized: "action.add"), isPresented: $showAddMenu, titleVisibility: .hidden) {
            Button(String(localized: "add.place")) { showAddPlace = true }
            Button(String(localized: "add.stay")) { showAddStay = true }
            Button(String(localized: "add.transfer")) { showAddTransfer = true }
            Button(String(localized: "add.paste")) { showPaste = true }
            Button(String(localized: "action.cancel"), role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 64)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: showAddStay) { _, presented in
            if !presented { Task { await refreshTimes() } }
        }
        .onChange(of: showAddTransfer) { _, presented in
            if !presented { Task { await refreshTimes() } }
        }
        .onChange(of: showPaste) { _, presented in
            if !presented { Task { await refreshTimes() } }
        }
        .onChange(of: editingStay) { _, value in
            if value == nil { Task { await refreshTimes() } }
        }
        .onChange(of: editingTransfer) { _, value in
            if value == nil { Task { await refreshTimes() } }
        }
    }

    private var topChrome: some View {
        HStack(spacing: 10) {
            chromeButton(systemName: "chevron.left", label: String(localized: "action.back")) {
                dismiss()
            }
            VStack(spacing: 1) {
                Text(trip.name)
                    .font(.headline)
                    .lineLimit(1)
                if !trip.citiesText.isEmpty {
                    Text(trip.citiesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            Button {
                showUnscheduled.toggle()
            } label: {
                Image(systemName: showUnscheduled ? "circle.dashed.inset.filled" : "circle.dashed")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(String(localized: "layer.unscheduled"))
            .accessibilityAddTraits(showUnscheduled ? .isSelected : [])
            Menu {
                Button(String(localized: "action.add"), systemImage: "plus") { showAddMenu = true }
                Button(String(localized: "trip.edit"), systemImage: "pencil") { showTripEdit = true }
            } label: {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .accessibilityLabel(String(localized: "action.add"))
            }
        }
        .padding(.horizontal, 12)
    }

    private func chromeButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private var itinerarySheet: some View {
        let plan = trip.dayPlan(forOffset: selectedOffset) ?? makePlan()
        return ItinerarySheetView(
            trip: trip,
            plan: plan,
            selectedOffset: $selectedOffset,
            compact: sheetDetent == .compact,
            selectedStopID: selectedStop?.id,
            onSelectStop: { stop in
                selectedStop = stop
                if stop.role == .sight, let place = stop.place {
                    selectedPlace = place
                } else if stop.role.isStay, let stay = stop.stay {
                    editingStay = stay
                } else if stop.role.isTransferEndpoint, let transfer = stop.transfer {
                    editingTransfer = transfer
                }
            },
            onEditStop: { stop in
                if stop.role == .sight, let place = stop.place {
                    selectedPlace = place
                } else if stop.role.isStay, let stay = stop.stay {
                    editingStay = stay
                } else if stop.role.isTransferEndpoint, let transfer = stop.transfer {
                    editingTransfer = transfer
                }
            },
            onGatherNearby: {
                let count = DayAssembly.gatherNearby(into: plan, trip: trip)
                toast = String(format: String(localized: "day.gather.result %lld"), count)
                Task {
                    await refreshTimes()
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    toast = nil
                }
            },
            onAdd: { showAddMenu = true },
            onRefreshTimes: { Task { await refreshTimes() } }
        )
        .background(.regularMaterial)
    }

    private func makePlan() -> DayPlan {
        DayAssembly.ensureDayPlans(for: trip, in: context)
        return trip.dayPlan(forOffset: selectedOffset) ?? DayPlan(dayOffset: selectedOffset)
    }

    @MainActor
    private func setup() async {
        DayAssembly.ensureDayPlans(for: trip, in: context)
        if let today = trip.dayOffset(for: Date()) {
            selectedOffset = today
        } else {
            selectedOffset = 0
        }
        await refreshTimes()
    }

    @MainActor
    private func refreshTimes() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let plan = trip.dayPlan(forOffset: selectedOffset) {
            DayAssembly.seedDefaultModes(in: plan)
            await TravelTimeService.refreshDay(plan, defaultMode: trip.defaultLocalMode)
            try? context.save()
        }
    }
}

