import Foundation
import SwiftUI

enum TransportMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case walk
    case transit
    case taxi
    case drive
    case flight
    case train
    case bus

    var id: String { rawValue }

    /// Modes the traveller can pick between two nearby stops.
    static var localModes: [TransportMode] { [.walk, .transit, .taxi, .drive] }

    /// Modes that typically represent an inter-city transfer.
    var isScheduledTransfer: Bool {
        switch self {
        case .flight, .train, .bus: true
        default: false
        }
    }

    var localizedName: LocalizedStringResource {
        switch self {
        case .walk: "mode.walk"
        case .transit: "mode.transit"
        case .taxi: "mode.taxi"
        case .drive: "mode.drive"
        case .flight: "mode.flight"
        case .train: "mode.train"
        case .bus: "mode.bus"
        }
    }

    var symbolName: String {
        switch self {
        case .walk: "figure.walk"
        case .transit: "tram.fill"
        case .taxi: "car.side.fill"
        case .drive: "car.fill"
        case .flight: "airplane"
        case .train: "train.side.front.car"
        case .bus: "bus.fill"
        }
    }

    var appleMapsDirFlag: String {
        switch self {
        case .walk: "w"
        case .transit: "r"
        case .taxi, .drive: "d"
        default: "d"
        }
    }

    /// 高德 path `t` parameter: 0 drive, 1 transit, 2 walk, 3 ride.
    var amapPathType: Int {
        switch self {
        case .drive, .taxi: 0
        case .transit, .train, .bus: 1
        case .walk: 2
        case .flight: 0
        }
    }
}

enum TransferKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case train
    case bus
    case drive

    var id: String { rawValue }

    var transportMode: TransportMode {
        switch self {
        case .flight: .flight
        case .train: .train
        case .bus: .bus
        case .drive: .drive
        }
    }

    var localizedName: LocalizedStringResource {
        switch self {
        case .flight: "transfer.flight"
        case .train: "transfer.train"
        case .bus: "transfer.bus"
        case .drive: "transfer.drive"
        }
    }

    var symbolName: String { transportMode.symbolName }
}

/// What a day stop represents on the path.
enum StopRole: String, Codable, Sendable {
    case sight
    case stayMorning
    case stayEvening
    case transferDeparture
    case transferArrival
    case custom

    var isStay: Bool { self == .stayMorning || self == .stayEvening }
    var isTransferEndpoint: Bool { self == .transferDeparture || self == .transferArrival }
}

enum PlaceOpenState: String, Codable, Sendable {
    case unknown
    case open
    case closed
}
