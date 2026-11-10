import Foundation
import SwiftData
import WatchCore

/// Turns watch events into stored records. Upserts by unique key so a re-sync never duplicates.
@MainActor
struct HealthRepository {
    let context: ModelContext

    func store(_ event: WatchEvent, deviceID: UUID?, calendar: Calendar = .current) {
        switch event {
        case let .sample(s):
            guard let metric = Metric(sample: s.kind) else { return }
            // Live stream values are shown, not stored, unless they are single measurements.
            if s.isLive { return }
            insert(HealthSampleRecord(metric: metric, date: s.date, value: s.value, value2: s.value2,
                                      source: .device, deviceID: deviceID))
        case let .daySummary(summary):
            let day = calendar.startOfDay(for: Date())
            let record = DaySummaryRecord(day: day, deviceID: deviceID, summary: summary)
            let key = record.key
            let existing = try? context.fetch(FetchDescriptor<DaySummaryRecord>(predicate: #Predicate { $0.key == key }))
            if let old = existing?.first {
                old.steps = summary.steps; old.kilocalories = summary.kilocalories
                old.lightSleepMinutes = summary.lightSleepMinutes; old.deepSleepMinutes = summary.deepSleepMinutes
                old.awakeCount = summary.awakeCount
            } else {
                context.insert(record)
            }
        case let .sleep(segment):
            let record = SleepSegmentRecord(segment: segment, deviceID: deviceID)
            let key = record.key
            if (try? context.fetchCount(FetchDescriptor<SleepSegmentRecord>(predicate: #Predicate { $0.key == key }))) ?? 0 == 0 {
                context.insert(record)
            }
        case let .sport(r):
            // Watch sport codes are not mapped to our types yet, so they are stored as "other".
            let start = r.start
            let exists = (try? context.fetchCount(FetchDescriptor<WorkoutRecord>(predicate: #Predicate { $0.start == start }))) ?? 0 > 0
            if !exists, r.durationSeconds > 0 {
                context.insert(WorkoutRecord(type: .other, start: r.start,
                                             end: r.start.addingTimeInterval(TimeInterval(r.durationSeconds)),
                                             distanceMeters: Double(r.distanceMeters), route: [],
                                             averageHeartRate: r.averageHeartRate > 0 ? Double(r.averageHeartRate) : nil,
                                             maxHeartRate: nil))
            }
        case .deviceInfo, .heartbeat, .unknown, .platform, .screen, .faceAck, .raw:
            break
        }
        try? context.save()
    }

    func addManual(_ metric: Metric, date: Date, value: Double, value2: Double? = nil) {
        insert(HealthSampleRecord(metric: metric, date: date, value: value, value2: value2,
                                  source: .manual, deviceID: nil))
        try? context.save()
    }

    private func insert(_ record: HealthSampleRecord) {
        let key = record.key
        let count = (try? context.fetchCount(FetchDescriptor<HealthSampleRecord>(predicate: #Predicate { $0.key == key }))) ?? 0
        if count == 0 { context.insert(record) }
    }
}

extension Metric {
    init?(sample kind: SampleKind) {
        switch kind {
        case .heartRate: self = .heartRate
        case .bloodOxygen: self = .bloodOxygen
        case .bloodPressure: self = .bloodPressure
        case .temperature: self = .temperature
        case .stress: self = .stress
        case .steps: self = .steps
        case .sleep: self = .sleep
        case .kilocalories: return nil
        }
    }
}
