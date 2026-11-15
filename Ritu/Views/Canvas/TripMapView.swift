
import SwiftUI
import MapKit

struct TripMapView: View {
    var trip: Trip
    var selectedOffset: Int
    var showUnscheduled: Bool
    var selectedStopID: UUID?
    var selectedPlaceID: UUID?
    @Binding var position: MapCameraPosition
    var onSelectStop: (DayStop) -> Void
    var onSelectPlace: (Place) -> Void
    var onLongPress: (CLLocationCoordinate2D) -> Void

    var body: some View {
        MapReader { proxy in
            Map(position: $position, interactionModes: .all) {
                otherDayLayers
                selectedDayLayers
                if showUnscheduled {
                    unscheduledLayer
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapUserLocationButton()
            }
            .simultaneousGesture(longPress(proxy: proxy))
        }
        .onChange(of: selectedOffset) { _, _ in
            fitSelectedDay()
        }
        .onAppear {
            fitSelectedDay()
        }
    }

    @MapContentBuilder
    private var selectedDayLayers: some MapContent {
        let plan = trip.dayPlan(forOffset: selectedOffset)
        let stops = plan?.orderedStops ?? []
        let color = DayPalette.color(forDayOffset: selectedOffset)
        let crowded = plan?.feelsFull ?? false

        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
            if let next = stops[safe: index + 1] {
                let path = path(from: stop, to: next)
                if path.count >= 2 {
                    MapPolyline(coordinates: path)
                        .stroke(color, style: StrokeStyle(lineWidth: TravelTimeService.isTransferHop(from: stop, to: next) ? 2.0 : 3.0, lineCap: .round, lineJoin: .round, dash: TravelTimeService.isTransferHop(from: stop, to: next) ? [6, 7] : []))
                }
            }
        }

        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
            if stop.coordinateIsValid {
                Annotation(stop.title, coordinate: stop.coordinate, anchor: .center) {
                    Button {
                        onSelectStop(stop)
                    } label: {
                        StopAnnotationView(
                            number: index + 1,
                            role: stop.role,
                            color: color,
                            isSelected: selectedStopID == stop.id,
                            isReceded: false,
                            isCrowded: crowded
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(index + 1). \(stop.title)")
                }
            }
        }
    }

    @MapContentBuilder
    private var otherDayLayers: some MapContent {
        ForEach(trip.dayPlans.filter { $0.dayOffset != selectedOffset }, id: \.id) { plan in
            let color = DayPalette.color(forDayOffset: plan.dayOffset)
            let stops = plan.orderedStops
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                if let next = stops[safe: index + 1] {
                    let path = path(from: stop, to: next)
                    if path.count >= 2 {
                        MapPolyline(coordinates: path)
                            .stroke(color.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            ForEach(stops, id: \.id) { stop in
                if stop.coordinateIsValid {
                    Annotation(stop.title, coordinate: stop.coordinate, anchor: .center) {
                        StopAnnotationView(
                            number: nil,
                            role: stop.role,
                            color: color,
                            isSelected: false,
                            isReceded: true,
                            isCrowded: true
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    @MapContentBuilder
    private var unscheduledLayer: some MapContent {
        ForEach(trip.unscheduledPlaces, id: \.id) { place in
            if place.coordinate.isValidCoordinate {
                Annotation(place.displayName, coordinate: place.coordinate, anchor: .center) {
                    Button {
                        onSelectPlace(place)
                    } label: {
                        UnscheduledAnnotationView(isSelected: selectedPlaceID == place.id)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(place.displayName)
                }
            }
        }
    }

    private func path(from stop: DayStop, to next: DayStop) -> [CLLocationCoordinate2D] {
        if stop.pathToNext.count >= 2 {
            return stop.pathToNext
        }
        guard stop.coordinateIsValid, next.coordinateIsValid else { return [] }
        if TravelTimeService.isTransferHop(from: stop, to: next) {
            return TravelTimeService.geodesicPath(from: stop.coordinate, to: next.coordinate)
        }
        return [stop.coordinate, next.coordinate]
    }

    private func longPress(proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.55)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard case .second(true, let drag) = value, let location = drag?.location else { return }
                if let coordinate = proxy.convert(location, from: .local) {
                    onLongPress(coordinate)
                }
            }
    }

    private func fitSelectedDay() {
        let stops = trip.dayPlan(forOffset: selectedOffset)?.orderedStops.filter(\.coordinateIsValid) ?? []
        var coordinates = stops.map(\.coordinate)
        if showUnscheduled {
            coordinates.append(contentsOf: trip.unscheduledPlaces.map(\.coordinate).filter(\.isValidCoordinate))
        }
        guard let region = MKCoordinateRegion.fitting(coordinates) else { return }
        withAnimation(.easeInOut(duration: 0.45)) {
            position = .region(region)
        }
    }
}

extension MKCoordinateRegion {
    static func fitting(_ coordinates: [CLLocationCoordinate2D], padding: CLLocationDegrees = 1.8) -> MKCoordinateRegion? {
        let valid = coordinates.filter(\.isValidCoordinate)
        guard let first = valid.first else { return nil }
        if valid.count == 1 {
            return MKCoordinateRegion(center: first, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
        }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for coordinate in valid.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let latDelta = max((maxLat - minLat) * padding, 0.05)
        let lonDelta = max((maxLon - minLon) * padding, 0.05)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
