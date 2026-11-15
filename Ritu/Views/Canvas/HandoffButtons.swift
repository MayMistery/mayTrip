
import SwiftUI
import CoreLocation

struct HandoffButtons: View {
    var origin: CLLocationCoordinate2D?
    var destination: CLLocationCoordinate2D
    var destinationName: String
    var mode: TransportMode

    var body: some View {
        Menu {
            Button {
                NavigationHandoff.openAppleMaps(
                    from: origin,
                    to: destination,
                    destinationName: destinationName,
                    mode: mode
                )
            } label: {
                Label(String(localized: "nav.appleMaps"), systemImage: "map")
            }
            Button {
                NavigationHandoff.openAmap(
                    from: origin,
                    to: destination,
                    destinationName: destinationName,
                    mode: mode
                )
            } label: {
                Label(String(localized: "nav.amap"), systemImage: "location.north.line")
            }
        } label: {
            Image(systemName: "arrow.triangle.turn.up.right.circle")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .accessibilityLabel(String(localized: "nav.directions"))
        }
        .accessibilityLabel(String(localized: "nav.directions"))
    }
}
