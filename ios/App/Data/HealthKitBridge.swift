import Foundation
import HealthKit

/// Writes watch measurements to Apple Health with the user's permission. Only device samples are
/// exported (never manual entries or estimates as if measured). Steps are not exported because the
/// watch reports a running day total; writing it would double-count with the iPhone's own steps.
final class HealthKitBridge {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var writeTypes: Set<HKSampleType> {
        [HKQuantityType(.heartRate), HKQuantityType(.oxygenSaturation), HKQuantityType(.bodyTemperature),
         HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic),
         HKCategoryType(.sleepAnalysis)]
    }

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: Set(writeTypes.map { $0 as HKObjectType }))
    }

    /// Exports one stored sample; returns true if Apple Health accepted it.
    func export(metric: Metric, date: Date, value: Double, value2: Double?) async -> Bool {
        guard isAvailable else { return false }
        let object: HKObject?
        switch metric {
        case .heartRate:
            object = HKQuantitySample(type: HKQuantityType(.heartRate),
                                      quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: value),
                                      start: date, end: date)
        case .bloodOxygen:
            object = HKQuantitySample(type: HKQuantityType(.oxygenSaturation),
                                      quantity: HKQuantity(unit: .percent(), doubleValue: value / 100), start: date, end: date)
        case .temperature:
            object = HKQuantitySample(type: HKQuantityType(.bodyTemperature),
                                      quantity: HKQuantity(unit: .degreeCelsius(), doubleValue: value), start: date, end: date)
        case .bloodPressure:
            guard let dia = value2 else { return false }
            let mmHg = HKUnit.millimeterOfMercury()
            let sys = HKQuantitySample(type: HKQuantityType(.bloodPressureSystolic),
                                       quantity: HKQuantity(unit: mmHg, doubleValue: value), start: date, end: date)
            let di = HKQuantitySample(type: HKQuantityType(.bloodPressureDiastolic),
                                      quantity: HKQuantity(unit: mmHg, doubleValue: dia), start: date, end: date)
            object = HKCorrelation(type: HKCorrelationType(.bloodPressure), start: date, end: date, objects: [sys, di])
        default:
            object = nil
        }
        guard let object else { return false }
        do { try await store.save(object); return true } catch { return false }
    }

    /// Sleep stage codes are not mapped yet, so segments are written as "asleep (unspecified)".
    func exportSleep(start: Date, minutes: Int) async -> Bool {
        guard isAvailable, minutes > 0 else { return false }
        let sample = HKCategorySample(type: HKCategoryType(.sleepAnalysis),
                                      value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                                      start: start, end: start.addingTimeInterval(TimeInterval(minutes * 60)))
        do { try await store.save(sample); return true } catch { return false }
    }
}
