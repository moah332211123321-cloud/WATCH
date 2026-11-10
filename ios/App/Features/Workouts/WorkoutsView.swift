import Charts
import MapKit
import SwiftData
import SwiftUI
import WatchCore

/// S09: history + totals; S10: start a workout; S11: detail.
struct WorkoutsView: View {
    @Query(sort: \WorkoutRecord.start, order: .reverse) private var workouts: [WorkoutRecord]
    @State private var showStart = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showStart = true } label: {
                        Label(L("Start a workout"), systemImage: "play.circle.fill").font(.headline)
                    }
                    UnsupportedNote(reason: L("Workouts recorded on the watch itself are not synced yet: their data format is not confirmed."))
                }
                if workouts.isEmpty {
                    ContentUnavailableView(L("No workouts yet"), systemImage: "figure.run",
                                           description: Text(L("Start one from your phone to record route and heart rate.")))
                } else {
                    Section(L("This week")) { weekSummary }
                    Section(L("History")) {
                        ForEach(workouts) { w in
                            NavigationLink { WorkoutDetailView(workout: w) } label: { WorkoutRow(workout: w) }
                        }
                    }
                }
            }
            .navigationTitle(L("Workouts"))
            .fullScreenCover(isPresented: $showStart) { LiveWorkoutView() }
        }
    }

    private var weekSummary: some View {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recent = workouts.filter { $0.start >= weekAgo }
        let km = recent.reduce(0) { $0 + $1.distanceMeters } / 1000
        let minutes = Int(recent.reduce(0) { $0 + $1.duration } / 60)
        return HStack {
            VStack(alignment: .leading) {
                Text(L("Distance")).font(.caption).foregroundStyle(Tok.textMuted)
                Text(verbatim: km.formatted(.number.precision(.fractionLength(1)))).font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .leading) {
                Text(L("Minutes")).font(.caption).foregroundStyle(Tok.textMuted)
                Text(verbatim: minutes.formatted()).font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .leading) {
                Text(L("Workouts")).font(.caption).foregroundStyle(Tok.textMuted)
                Text(verbatim: recent.count.formatted()).font(.title2.bold())
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: WorkoutRecord
    var body: some View {
        HStack {
            Image(systemName: workout.type.icon).foregroundStyle(Tok.accent).frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(verbatim: workout.type.title).font(.headline)
                Text(workout.start, format: .dateTime.day().month().hour().minute())
                    .font(.caption).foregroundStyle(Tok.textMuted)
            }
            Spacer()
            Text(verbatim: Measurement(value: workout.distanceMeters / 1000, unit: UnitLength.kilometers)
                .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(2)))))
        }
    }
}

/// S10: live screen while the phone records.
struct LiveWorkoutView: View {
    @Environment(DeviceController.self) private var device
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var session = WorkoutSession()
    @State private var type: WorkoutType = .running

    var body: some View {
        NavigationStack {
            VStack(spacing: Tok.Space.xl) {
                if session.isRunning {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(verbatim: Duration.seconds(Date().timeIntervalSince(session.start ?? Date()))
                            .formatted(.time(pattern: .hourMinuteSecond)))
                            .font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    HStack(spacing: Tok.Space.xxl) {
                        stat(L("km"), (session.distanceMeters / 1000).formatted(.number.precision(.fractionLength(2))))
                        stat(L("bpm"), device.liveHeartRate.map { "\($0)" } ?? "–")
                    }
                    if session.locationDenied {
                        UnsupportedNote(reason: L("Location is off, so distance and route are not recorded."))
                    }
                    if !device.isConnected {
                        UnsupportedNote(reason: L("No watch connected: heart rate is not recorded."))
                    }
                    Button(role: .destructive) { Task { await stop() } } label: {
                        Text(L("End workout")).frame(maxWidth: .infinity).padding(.vertical, Tok.Space.m)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Picker(L("Type"), selection: $type) {
                        ForEach(WorkoutType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    Button { Task { await begin() } } label: {
                        Text(L("Start")).frame(maxWidth: .infinity).padding(.vertical, Tok.Space.m)
                    }
                    .buttonStyle(.borderedProminent).tint(Tok.accent)
                }
            }
            .padding(Tok.Space.xl)
            .navigationTitle(Text(verbatim: type.title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !session.isRunning { Button(L("Close")) { dismiss() } }
                }
            }
            .onChange(of: device.liveHeartRate) { _, bpm in session.addHeartRate(bpm) }
        }
    }

    private func stat(_ unit: LocalizedStringKey, _ value: String) -> some View {
        VStack {
            Text(verbatim: value).font(.title.bold()).monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(Tok.textMuted)
        }
    }

    private func begin() async {
        session.begin(type)
        // Real-time heart rate from the watch (command unconfirmed; failures are shown as "no HR").
        try? await device.send(.measure(.heartRate, on: true))
    }

    private func stop() async {
        try? await device.send(.measure(.heartRate, on: false))
        if let record = session.finish() {
            context.insert(record)
            try? context.save()
        }
        dismiss()
    }
}

/// S11: route, stats, heart rate.
struct WorkoutDetailView: View {
    let workout: WorkoutRecord

    var body: some View {
        List {
            if workout.route.count > 1 {
                Map {
                    MapPolyline(coordinates: workout.route.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(Tok.accent, lineWidth: 4)
                }
                .frame(height: 260)
                .listRowInsets(EdgeInsets())
            }
            Section {
                LabeledContent { Text(verbatim: Duration.seconds(workout.duration).formatted(.time(pattern: .hourMinuteSecond))) }
                    label: { Text(L("Duration")) }
                LabeledContent { Text(verbatim: (workout.distanceMeters / 1000).formatted(.number.precision(.fractionLength(2)))) }
                    label: { Text(L("Distance (km)")) }
                if let avg = workout.averageHeartRate {
                    LabeledContent { Text(verbatim: Int(avg).formatted()) } label: { Text(L("Average heart rate")) }
                }
                if let max = workout.maxHeartRate {
                    LabeledContent { Text(verbatim: Int(max).formatted()) } label: { Text(L("Maximum heart rate")) }
                }
                if workout.averageHeartRate == nil {
                    Text(L("No heart rate was recorded for this workout.")).foregroundStyle(Tok.textMuted)
                }
            }
        }
        .navigationTitle(Text(verbatim: workout.type.title))
    }
}
