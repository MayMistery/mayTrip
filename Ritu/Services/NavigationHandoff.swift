
import Foundation
import CoreLocation
import UIKit

enum NavigationHandoff {
    static var canOpenAmap: Bool {
        if let url = URL(string: "iosamap://") {
            return UIApplication.shared.canOpenURL(url)
        }
        return false
    }

    static func openAppleMaps(
        from origin: CLLocationCoordinate2D?,
        to destination: CLLocationCoordinate2D,
        destinationName: String,
        mode: TransportMode
    ) {
        var items: [String] = []
        items.append("daddr=\(destination.latitude),\(destination.longitude)")
        if !destinationName.isEmpty {
            items.append("dname=\(destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destinationName)")
        }
        if let origin, origin.isValidCoordinate {
            items.append("saddr=\(origin.latitude),\(origin.longitude)")
        }
        items.append("dirflg=\(mode.appleMapsDirFlag)")
        guard let url = URL(string: "maps://?\(items.joined(separator: "&"))") else { return }
        UIApplication.shared.open(url)
    }

    /// 高德 URI. `dev=1` declares WGS-84, matching how 日图 stores coordinates.
    /// See https://lbs.amap.com/api/amap-mobile/guide/ios/navi
    static func openAmap(
        from origin: CLLocationCoordinate2D?,
        to destination: CLLocationCoordinate2D,
        destinationName: String,
        mode: TransportMode
    ) {
        let name = destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        var items: [String] = [
            "sourceApplication=\(encodedAppName)",
            "dlat=\(destination.latitude)",
            "dlon=\(destination.longitude)",
            "dname=\(name)",
            "dev=1",
            "t=\(mode.amapPathType)"
        ]
        if let origin, origin.isValidCoordinate {
            items.append("slat=\(origin.latitude)")
            items.append("slon=\(origin.longitude)")
        }
        let candidates = [
            "iosamap://path?\(items.joined(separator: "&"))",
            "amapuri://route/plan/?\(items.joined(separator: "&"))"
        ]
        for string in candidates {
            if let url = URL(string: string) {
                UIApplication.shared.open(url)
                return
            }
        }
    }

    private static var encodedAppName: String {
        "日图".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Ritu"
    }
}
