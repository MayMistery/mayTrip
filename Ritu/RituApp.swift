
import SwiftUI
import SwiftData

@main
struct RituApp: App {
    var body: some Scene {
        WindowGroup {
            TripsRootView()
                .tint(RituTheme.ink)
        }
        .modelContainer(Self.container)
    }

    static var schema: Schema {
        Schema([
            Trip.self,
            Place.self,
            Stay.self,
            Transfer.self,
            TransferLeg.self,
            DayPlan.self,
            DayStop.self
        ])
    }

    static var container: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("无法创建本地行程存储：\(error)")
        }
    }()

    @MainActor
    static func previewContainer(withSample: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        if withSample {
            _ = SampleTripFactory.makeSpainPortugal(in: container.mainContext)
        }
        return container
    }
}
