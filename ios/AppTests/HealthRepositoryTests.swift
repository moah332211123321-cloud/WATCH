import SwiftData
import WatchCore
import XCTest
@testable import Sawar

@MainActor
final class HealthRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() async throws {
        container = try ModelContainer(for: Schema(AppSchema.models),
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testResyncDoesNotDuplicateSamples() throws {
        let repo = HealthRepository(context: container.mainContext)
        let id = UUID()
        let event = WatchEvent.sample(Sample(kind: .heartRate, date: Date(timeIntervalSince1970: 1_000), value: 72, isLive: false))
        repo.store(event, deviceID: id)
        repo.store(event, deviceID: id)
        let all = try container.mainContext.fetch(FetchDescriptor<HealthSampleRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.source, .device)
    }

    func testLiveValuesAreNotStored() throws {
        let repo = HealthRepository(context: container.mainContext)
        repo.store(.sample(Sample(kind: .heartRate, date: Date(), value: 80, isLive: true)), deviceID: UUID())
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<HealthSampleRecord>()), 0)
    }

    func testManualEntriesAreMarkedManual() throws {
        let repo = HealthRepository(context: container.mainContext)
        repo.addManual(.bloodPressure, date: Date(), value: 120, value2: 80)
        let all = try container.mainContext.fetch(FetchDescriptor<HealthSampleRecord>())
        XCTAssertEqual(all.first?.source, .manual)
        XCTAssertNil(all.first?.deviceID)
    }

    func testDaySummaryIsUpdatedNotDuplicated() throws {
        let repo = HealthRepository(context: container.mainContext)
        let id = UUID()
        func summary(_ steps: Int) -> WatchEvent {
            .daySummary(DaySummary(steps: steps, kilocalories: 0, lightSleepMinutes: 0, deepSleepMinutes: 0,
                                   awakeCount: 0, sportSeconds: nil, sportCount: nil))
        }
        repo.store(summary(100), deviceID: id)
        repo.store(summary(250), deviceID: id)
        let all = try container.mainContext.fetch(FetchDescriptor<DaySummaryRecord>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.steps, 250)
    }

    func testWeekdayTextEveryDay() {
        XCTAssertEqual(weekdayText(.all), S("Every day"))
    }
}
