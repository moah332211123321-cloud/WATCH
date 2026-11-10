import Foundation
import SwiftData
import WatchCore

/// Where a value came from. Kept on every sample so device data, manual entries, Apple Health
/// data and estimates are never mixed up (REQUIREMENTS §5).
enum SampleSource: String, Codable, CaseIterable {
    case device, manual, healthKit, estimate
}

/// App-level metric list: watch kinds plus manual-only ones.
enum Metric: String, Codable, CaseIterable, Identifiable {
    case steps, heartRate, bloodOxygen, bloodPressure, temperature, stress, sleep, weight, glucose
    var id: String { rawValue }
}

@Model final class DeviceRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var familyRaw: String
    var firmware: String?
    var bandVersionCode: Int?
    var lastSeen: Date
    var isPrimary: Bool

    init(id: UUID, name: String, family: DeviceFamily) {
        self.id = id; self.name = name; self.familyRaw = family.rawValue
        self.lastSeen = Date(); self.isPrimary = true
    }

    var family: DeviceFamily { DeviceFamily(rawValue: familyRaw) ?? .generic }
}

@Model final class HealthSampleRecord {
    /// deviceOrSource + metric + timestamp: re-syncing the same record does not duplicate it.
    @Attribute(.unique) var key: String
    var metricRaw: String
    var date: Date
    var value: Double
    var value2: Double?
    var sourceRaw: String
    var deviceID: UUID?
    var exportedToHealth: Bool = false

    init(metric: Metric, date: Date, value: Double, value2: Double? = nil, source: SampleSource, deviceID: UUID?) {
        self.metricRaw = metric.rawValue; self.date = date; self.value = value; self.value2 = value2
        self.sourceRaw = source.rawValue; self.deviceID = deviceID
        self.key = "\(deviceID?.uuidString ?? source.rawValue)|\(metric.rawValue)|\(Int(date.timeIntervalSince1970))"
    }

    var metric: Metric { Metric(rawValue: metricRaw) ?? .heartRate }
    var source: SampleSource { SampleSource(rawValue: sourceRaw) ?? .device }
}

@Model final class DaySummaryRecord {
    @Attribute(.unique) var key: String
    var day: Date
    var steps: Int
    var kilocalories: Int
    var lightSleepMinutes: Int
    var deepSleepMinutes: Int
    var awakeCount: Int
    var deviceID: UUID?

    init(day: Date, deviceID: UUID?, summary: DaySummary) {
        self.day = day; self.deviceID = deviceID
        self.key = "\(deviceID?.uuidString ?? "-")|\(Int(day.timeIntervalSince1970))"
        self.steps = summary.steps; self.kilocalories = summary.kilocalories
        self.lightSleepMinutes = summary.lightSleepMinutes; self.deepSleepMinutes = summary.deepSleepMinutes
        self.awakeCount = summary.awakeCount
    }
}

@Model final class SleepSegmentRecord {
    @Attribute(.unique) var key: String
    var start: Date
    var minutes: Int
    var stageCode: Int
    var deviceID: UUID?

    init(segment: SleepSegment, deviceID: UUID?) {
        self.start = segment.start; self.minutes = segment.minutes; self.stageCode = Int(segment.stageCode)
        self.deviceID = deviceID
        self.key = "\(deviceID?.uuidString ?? "-")|\(Int(segment.start.timeIntervalSince1970))"
    }
}

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case walking, running, cycling, hiking, indoorRun, swimming, yoga, other
    var id: String { rawValue }
}

@Model final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var start: Date
    var end: Date
    var distanceMeters: Double
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Route points encoded as JSON `[[lat, lon, t]]`.
    var routeData: Data
    var sourceRaw: String

    init(type: WorkoutType, start: Date, end: Date, distanceMeters: Double, route: [RoutePoint],
         averageHeartRate: Double?, maxHeartRate: Double?) {
        self.id = UUID(); self.typeRaw = type.rawValue; self.start = start; self.end = end
        self.distanceMeters = distanceMeters; self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate; self.sourceRaw = SampleSource.device.rawValue
        self.routeData = (try? JSONEncoder().encode(route)) ?? Data()
    }

    var type: WorkoutType { WorkoutType(rawValue: typeRaw) ?? .other }
    var route: [RoutePoint] { (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? [] }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct RoutePoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var time: Date
}

@Model final class AlarmRecord {
    @Attribute(.unique) var index: Int
    var hour: Int
    var minute: Int
    var repeatsRaw: Int
    var enabled: Bool
    var label: String

    init(index: Int, hour: Int, minute: Int, repeats: Weekdays, enabled: Bool = true, label: String = "") {
        self.index = index; self.hour = hour; self.minute = minute
        self.repeatsRaw = Int(repeats.rawValue); self.enabled = enabled; self.label = label
    }

    var repeats: Weekdays {
        get { Weekdays(rawValue: UInt8(clamping: repeatsRaw)) }
        set { repeatsRaw = Int(newValue.rawValue) }
    }
}

@Model final class WatchFaceRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.externalStorage) var imageData: Data
    var backgroundHex: Int
    var textHex: Int
    var showDate: Bool
    var isFavorite: Bool
    var createdAt: Date

    init(name: String, imageData: Data, backgroundHex: Int = 0x000000, textHex: Int = 0xFFFFFF) {
        self.id = UUID(); self.name = name; self.imageData = imageData
        self.backgroundHex = backgroundHex; self.textHex = textHex
        self.showDate = true; self.isFavorite = false; self.createdAt = Date()
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        DeviceRecord.self, HealthSampleRecord.self, DaySummaryRecord.self, SleepSegmentRecord.self,
        WorkoutRecord.self, AlarmRecord.self, WatchFaceRecord.self,
    ]
}
