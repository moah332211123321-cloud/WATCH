import CoreLocation
import Foundation
import Observation
import WatchCore

/// A workout led by the phone: GPS route + distance from CoreLocation, live heart rate from the watch
/// when it streams it. Nothing is estimated silently. Created and used on the main thread, so
/// CoreLocation calls its delegate on the main thread too.
@Observable
final class WorkoutSession: NSObject, CLLocationManagerDelegate {
    var type: WorkoutType = .running
    var start: Date?
    var distanceMeters: Double = 0
    var route: [RoutePoint] = []
    var heartRates: [Double] = []
    var locationDenied = false
    var isRunning: Bool { start != nil }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var last: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func begin(_ type: WorkoutType) {
        self.type = type
        start = Date(); distanceMeters = 0; route = []; heartRates = []; last = nil
        if type != .indoorRun && type != .yoga && type != .swimming {
            manager.requestWhenInUseAuthorization()
            manager.startUpdatingLocation()
        }
    }

    func addHeartRate(_ bpm: Int?) {
        if let bpm, bpm > 0, isRunning { heartRates.append(Double(bpm)) }
    }

    /// Ends the session and returns the record to save (nil if it lasted under 10 s).
    func finish() -> WorkoutRecord? {
        manager.stopUpdatingLocation()
        defer { start = nil }
        guard let start, Date().timeIntervalSince(start) >= 10 else { return nil }
        let avg = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        return WorkoutRecord(type: type, start: start, end: Date(), distanceMeters: distanceMeters, route: route,
                             averageHeartRate: avg, maxHeartRate: heartRates.max())
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 30 {
            if let last { distanceMeters += loc.distance(from: last) }
            last = loc
            route.append(RoutePoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                                    time: loc.timestamp))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        locationDenied = status == .denied || status == .restricted
    }
}

extension WorkoutType {
    var title: String {
        switch self {
        case .walking: return S("Walking")
        case .running: return S("Running")
        case .cycling: return S("Cycling")
        case .hiking: return S("Hiking")
        case .indoorRun: return S("Indoor run")
        case .swimming: return S("Swimming")
        case .yoga: return S("Yoga")
        case .other: return S("Other")
        }
    }

    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        case .indoorRun: return "figure.run.treadmill"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .other: return "figure.mixed.cardio"
        }
    }
}
