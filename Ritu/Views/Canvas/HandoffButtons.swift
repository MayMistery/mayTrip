
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
            Text(String(localized: "nav.directions"))
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .accessibilityLabel(String(localized: "nav.directions"))
    }
}
