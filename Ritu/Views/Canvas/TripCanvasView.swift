import SwiftUI
import SwiftData
import MapKit

struct TripCanvasView: View {
    @Bindable var trip: Trip
    var hidesSystemBackButton: Bool
    var onShowAllTrips: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
    @State private var didPrepare = false

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldGuide.current(in: proxy)
            let layout = StageLayout.resolve(
                size: proxy.size,
                horizontalSizeClass: horizontalSizeClass,
                fold: fold
            )
            stage(layout, in: proxy)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .navigationTitle(trip.name)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(!layout.isPhone || hidesSystemBackButton)
                .toolbar(layout.isPhone ? .visible : .hidden, for: .navigationBar)
                .toolbar {
                    if layout.isPhone && hidesSystemBackButton {
                        ToolbarItem(placement: .topBarLeading) {
                            backButton
                        }
                    }
                    if layout.isPhone {
                        ToolbarItem(placement: .topBarTrailing) {
                            unscheduledButton(iconOnly: false)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            addMenu(iconOnly: false)
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showTripEdit = true
                            } label: {
                                Label(String(localized: "trip.edit"), systemImage: "pencil")
                            }
                        }
                    }
                }
        }
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
                    .rituGlass(cornerRadius: 18)
                    .padding(.top, 8)
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

    @ViewBuilder
    private func stage(_ layout: StageLayout, in proxy: GeometryProxy) -> some View {
        switch layout {
        case .phone:
            phoneStage(in: proxy)
        case .columns(let leading, let separator, let trailing):
            HStack(spacing: 0) {
                itineraryColumn
                    .frame(width: leading)
                foldGap(separator, hairline: true)
                map
                    .frame(width: trailing)
            }
            .background(Color(.systemBackground))
        case .stacked(let top, let separator, let bottom):
            VStack(spacing: 0) {
                map
                    .frame(height: top)
                foldGap(separator, hairline: false)
                itineraryColumn
                    .frame(height: bottom)
            }
            .background(Color(.systemBackground))
        }
    }

    /// A wide gap is the hinge: leave it empty. A one-point gap is just the seam between panes.
    private func foldGap(_ length: CGFloat, hairline: Bool) -> some View {
        Group {
            if hairline && length <= 2 {
                Rectangle().fill(Color.primary.opacity(0.10))
            } else {
                Color.clear
            }
        }
        .frame(width: hairline ? length : nil, height: hairline ? nil : length)
    }

    private func phoneStage(in proxy: GeometryProxy) -> some View {
        let panelHeight = PanelDetent.height(sheetDetent, in: proxy.size.height)
        return map
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: panelHeight)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .bottom) {
                ResizableBottomPanel(detent: $sheetDetent, containerHeight: proxy.size.height) {
                    itinerary(showsGrabber: true)
                }
            }
    }

    private var itineraryColumn: some View {
        VStack(spacing: 0) {
            columnHeader
            itinerary(showsGrabber: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }

    private var columnHeader: some View {
        HStack(spacing: 8) {
            Button(action: onShowAllTrips) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(String(localized: "trips.all"))
            VStack(alignment: .leading, spacing: 1) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            unscheduledButton(iconOnly: true)
            addMenu(iconOnly: true)
            Button {
                showTripEdit = true
            } label: {
                Image(systemName: "pencil")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(String(localized: "trip.edit"))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var backButton: some View {
        Button(action: onShowAllTrips) {
            Label(String(localized: "trips.all"), systemImage: "chevron.left")
        }
    }

    private func unscheduledButton(iconOnly: Bool) -> some View {
        Button {
            showUnscheduled.toggle()
        } label: {
            if iconOnly {
                Image(systemName: showUnscheduled ? "circle.dashed.inset.filled" : "circle.dashed")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(String(localized: "layer.unscheduled"))
            } else {
                Label(
                    String(localized: "layer.unscheduled"),
                    systemImage: showUnscheduled ? "circle.dashed.inset.filled" : "circle.dashed"
                )
            }
        }
        .accessibilityAddTraits(showUnscheduled ? .isSelected : [])
    }

    private func addMenu(iconOnly: Bool) -> some View {
        Menu {
            Button(String(localized: "add.place"), systemImage: "mappin.and.ellipse") { showAddPlace = true }
            Button(String(localized: "add.stay"), systemImage: "bed.double") { showAddStay = true }
            Button(String(localized: "add.transfer"), systemImage: "airplane") { showAddTransfer = true }
            Button(String(localized: "add.paste"), systemImage: "doc.on.clipboard") { showPaste = true }
        } label: {
            if iconOnly {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(String(localized: "action.add"))
            } else {
                Label(String(localized: "action.add"), systemImage: "plus")
            }
        }
    }

    private var map: some View {
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
    }

    private func itinerary(showsGrabber: Bool) -> some View {
        let plan = trip.dayPlan(forOffset: selectedOffset) ?? makePlan()
        return ItinerarySheetView(
            trip: trip,
            plan: plan,
            selectedOffset: $selectedOffset,
            compact: showsGrabber && sheetDetent == .compact,
            showsGrabber: showsGrabber,
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
    }

    private func makePlan() -> DayPlan {
        DayAssembly.ensureDayPlans(for: trip, in: context)
        return trip.dayPlan(forOffset: selectedOffset) ?? DayPlan(dayOffset: selectedOffset)
    }

    @MainActor
    private func setup() async {
        DayAssembly.ensureDayPlans(for: trip, in: context)
        if !didPrepare {
            didPrepare = true
            if let today = trip.dayOffset(for: Date()) {
                selectedOffset = today
            } else {
                selectedOffset = 0
            }
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
