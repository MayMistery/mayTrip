
import SwiftUI
import SwiftData

struct TripsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate, order: .forward) private var trips: [Trip]
    @State private var isCreating = false
    @State private var tripPendingDelete: Trip?

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(String(localized: "trips.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                            .accessibilityLabel(String(localized: "trip.new"))
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
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(trips, id: \.id) { trip in
                    NavigationLink {
                        TripCanvasView(trip: trip)
                    } label: {
                        TripCardView(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            tripPendingDelete = trip
                        } label: {
                            Label(String(localized: "trip.delete"), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(String(localized: "trips.empty.title"))
                .font(RituTheme.titleFont)
                .multilineTextAlignment(.center)
            Text(String(localized: "trips.empty.body"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(String(localized: "trip.new")) {
                isCreating = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Button(String(localized: "trips.sample.load")) {
                _ = SampleTripFactory.makeSpainPortugal(in: context)
                try? context.save()
            }
            .font(.body)
            .padding(.top, 4)
            Text(String(localized: "trips.sample.caption"))
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TripsListView()
        .modelContainer(RituApp.previewContainer(withSample: false))
}
