import SwiftUI
import SwiftData

struct TripsRootView: View {
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]
    @State private var selectedTripID: UUID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var selectedTrip: Trip? {
        guard let selectedTripID else { return nil }
        return trips.first { $0.id == selectedTripID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            TripsListView(selection: $selectedTripID)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            if let selectedTrip {
                TripCanvasView(
                    trip: selectedTrip,
                    hidesSystemBackButton: columnVisibility == .detailOnly,
                    onShowAllTrips: showAllTrips
                )
                .id(selectedTrip.id)
            } else {
                TripLibraryPlaceholder()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear(perform: syncColumns)
        .onChange(of: horizontalSizeClass) { _, _ in syncColumns() }
        .onChange(of: selectedTripID) { _, _ in syncColumns() }
    }

    private func showAllTrips() {
        withAnimation(.smooth(duration: 0.32)) {
            selectedTripID = nil
            columnVisibility = .automatic
        }
    }

    /// Regular width (Duo inner display, large-phone landscape) gives the open trip
    /// the full canvas so the day list can sit beside the map. Compact keeps the
    /// system stack: the trip list, then the trip.
    private func syncColumns() {
        let next: NavigationSplitViewVisibility = (horizontalSizeClass == .regular && selectedTripID != nil) ? .detailOnly : .automatic
        guard columnVisibility != next else { return }
        withAnimation(.smooth(duration: 0.32)) {
            columnVisibility = next
        }
    }
}

private struct TripLibraryPlaceholder: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            QuietEmptyState(
                systemImage: "map",
                title: String(localized: "trips.placeholder.title"),
                message: String(localized: "trips.placeholder.body")
            )
        }
        .navigationTitle(String(localized: "trips.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    TripsRootView()
        .modelContainer(RituApp.previewContainer())
}
