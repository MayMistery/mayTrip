import SwiftUI
import SwiftData

struct TripsListView: View {
    @Binding var selection: UUID?

    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]
    @State private var isCreating = false
    @State private var tripPendingDelete: Trip?

    var body: some View {
        Group {
            if trips.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "trips.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label(String(localized: "trip.new"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            CreateTripView()
        }
        .confirmationDialog(
            String(localized: "trip.delete.title"),
            isPresented: Binding(
                get: { tripPendingDelete != nil },
                set: { if !$0 { tripPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "trip.delete.confirm"), role: .destructive) {
                if let tripPendingDelete {
                    if selection == tripPendingDelete.id {
                        selection = nil
                    }
                    context.delete(tripPendingDelete)
                    try? context.save()
                }
                tripPendingDelete = nil
            }
            Button(String(localized: "action.cancel"), role: .cancel) {
                tripPendingDelete = nil
            }
        } message: {
            Text(String(localized: "trip.delete.message"))
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(trips, id: \.id) { trip in
                TripCardView(trip: trip)
                    .tag(trip.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowBackground(Color.clear)
                    .contextMenu {
                        Button(role: .destructive) {
                            tripPendingDelete = trip
                        } label: {
                            Label(String(localized: "trip.delete"), systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .contentMargins(.bottom, 24, for: .scrollContent)
    }

    private var emptyState: some View {
        QuietEmptyState(
            systemImage: "map",
            title: String(localized: "trips.empty.title"),
            message: String(localized: "trips.empty.body"),
            primaryTitle: String(localized: "trip.new"),
            primaryAction: { isCreating = true },
            secondaryTitle: String(localized: "trips.sample.load"),
            secondaryAction: loadSample,
            footnote: String(localized: "trips.sample.caption")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSample() {
        _ = SampleTripFactory.makeSpainPortugal(in: context)
        try? context.save()
    }
}

#Preview {
    @Previewable @State var selection: UUID?
    NavigationStack {
        TripsListView(selection: $selection)
    }
    .modelContainer(RituApp.previewContainer(withSample: false))
}
