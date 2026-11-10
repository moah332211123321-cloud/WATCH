import SwiftData
import SwiftUI
import WatchCore

/// Sends a command when a setting changes and shows the result. Settings are kept locally because
/// reading them back from the watch is not confirmed.
@MainActor
private func push(_ device: DeviceController, _ command: Command, into state: Binding<SendState>) {
    state.wrappedValue = .sending
    Task {
        do { try await device.send(command); state.wrappedValue = .sent }
        catch { state.wrappedValue = .failed(describe(error)) }
    }
}

private extension TimeWindow {
    init(_ start: Date, _ end: Date) {
        let cal = Calendar.current
        self.init(startHour: cal.component(.hour, from: start), startMinute: cal.component(.minute, from: start),
                  endHour: cal.component(.hour, from: end), endMinute: cal.component(.minute, from: end))
    }
}

private func todayAt(_ hour: Int, _ minute: Int = 0) -> Date {
    Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
}

/// Stores a Date in AppStorage as seconds since 1970.
private extension Binding where Value == Double {
    var date: Binding<Date> {
        Binding<Date>(get: { Date(timeIntervalSince1970: wrappedValue) }, set: { wrappedValue = $0.timeIntervalSince1970 })
    }
}

// MARK: S22 reminders

struct RemindersView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("sedentaryOn") private var sedentaryOn = false
    @AppStorage("sedentaryStart") private var sedentaryStart = todayAt(9).timeIntervalSince1970
    @AppStorage("sedentaryEnd") private var sedentaryEnd = todayAt(18).timeIntervalSince1970
    @AppStorage("sedentaryInterval") private var sedentaryInterval = 60
    @AppStorage("waterOn") private var waterOn = false
    @AppStorage("waterStart") private var waterStart = todayAt(9).timeIntervalSince1970
    @AppStorage("waterEnd") private var waterEnd = todayAt(21).timeIntervalSince1970
    @AppStorage("waterInterval") private var waterInterval = 90
    @State private var state: SendState = .idle

    var body: some View {
        Form {
            Section(L("Move reminder")) {
                Toggle(L("Remind me to move"), isOn: $sedentaryOn)
                DatePicker(L("From"), selection: $sedentaryStart.date, displayedComponents: .hourAndMinute)
                DatePicker(L("To"), selection: $sedentaryEnd.date, displayedComponents: .hourAndMinute)
                Stepper(value: $sedentaryInterval, in: 30...180, step: 15) {
                    Text(L("Every")) + Text(verbatim: " \(sedentaryInterval) ") + Text(L("min"))
                }
            }
            Section(L("Drink water")) {
                Toggle(L("Remind me to drink"), isOn: $waterOn)
                DatePicker(L("From"), selection: $waterStart.date, displayedComponents: .hourAndMinute)
                DatePicker(L("To"), selection: $waterEnd.date, displayedComponents: .hourAndMinute)
                Stepper(value: $waterInterval, in: 30...240, step: 15) {
                    Text(L("Every")) + Text(verbatim: " \(waterInterval) ") + Text(L("min"))
                }
            }
            Section {
                Button(L("Send to watch")) { send() }.disabled(!device.isConnected)
                SendStatusView(state: state)
                Text(L("Other reminders (medicine, reading, hand washing) are not confirmed yet.")).font(.footnote).foregroundStyle(Tok.textMuted)
            }
        }
        .navigationTitle(L("Reminders"))
    }

    private func send() {
        state = .sending
        Task {
            do {
                try await device.send(.sedentaryReminder(on: sedentaryOn, window: TimeWindow($sedentaryStart.date.wrappedValue, $sedentaryEnd.date.wrappedValue), intervalMinutes: sedentaryInterval))
                try await device.send(.drinkWaterReminder(on: waterOn, window: TimeWindow($waterStart.date.wrappedValue, $waterEnd.date.wrappedValue), intervalMinutes: waterInterval))
                state = .sent
            } catch { state = .failed(describe(error)) }
        }
    }
}

// MARK: S23 do not disturb

struct DoNotDisturbView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("dndOn") private var on = false
    @AppStorage("dndStart") private var start = todayAt(22).timeIntervalSince1970
    @AppStorage("dndEnd") private var end = todayAt(7).timeIntervalSince1970
    @State private var state: SendState = .idle

    var body: some View {
        Form {
            Toggle(L("Do Not Disturb"), isOn: $on)
            DatePicker(L("From"), selection: $start.date, displayedComponents: .hourAndMinute)
            DatePicker(L("To"), selection: $end.date, displayedComponents: .hourAndMinute)
            Button(L("Send to watch")) {
                push(device, .doNotDisturb(on: on, window: TimeWindow($start.date.wrappedValue, $end.date.wrappedValue)), into: $state)
            }
            .disabled(!device.isConnected)
            SendStatusView(state: state)
        }
        .navigationTitle(L("Do Not Disturb"))
    }
}

// MARK: S24/S25 display and time

struct DisplaySettingsView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("raiseToWake") private var raiseToWake = true
    @AppStorage("twelveHour") private var twelveHour = false
    @AppStorage("fahrenheit") private var fahrenheit = false
    @State private var state: SendState = .idle

    var body: some View {
        Form {
            Toggle(L("Raise to wake"), isOn: $raiseToWake)
                .onChange(of: raiseToWake) { _, v in push(device, .raiseToWake(on: v), into: $state) }
            Toggle(L("12-hour clock"), isOn: $twelveHour)
                .onChange(of: twelveHour) { _, v in push(device, .twelveHourClock(v), into: $state) }
            Toggle(L("Temperature in °F"), isOn: $fahrenheit)
                .onChange(of: fahrenheit) { _, v in push(device, .temperatureUnitFahrenheit(v), into: $state) }
            Button(L("Sync time now")) { push(device, .setTime(Date(), .current), into: $state) }
            SendStatusView(state: state)
            Section {
                UnsupportedNote(reason: L("Brightness, screen timeout and vibration strength are not confirmed yet."))
            }
        }
        .disabled(!device.isConnected)
        .navigationTitle(L("Display and time"))
    }
}

// MARK: measurement settings

struct HeartSettingsView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("hourlyMeasure") private var hourly = false
    @State private var state: SendState = .idle

    var body: some View {
        Form {
            Toggle(L("Measure automatically every hour"), isOn: $hourly)
                .onChange(of: hourly) { _, v in push(device, .hourlyMeasurement(on: v), into: $state) }
            SendStatusView(state: state)
            Section { UnsupportedNote(reason: L("High heart rate alerts are not confirmed yet.")) }
        }
        .disabled(!device.isConnected)
        .navigationTitle(L("Measurement"))
    }
}

// MARK: S21 alarms

struct AlarmsView: View {
    @Environment(\.modelContext) private var context
    @Environment(DeviceController.self) private var device
    @Query(sort: \AlarmRecord.index) private var alarms: [AlarmRecord]
    @State private var state: SendState = .idle
    private let maxAlarms = 5 // shortcut: real limit per watch is unknown; 5 is a safe guess for the UI only

    var body: some View {
        List {
            ForEach(alarms) { alarm in
                NavigationLink { AlarmEditView(alarm: alarm) } label: {
                    HStack {
                        Text(todayAt(alarm.hour, alarm.minute), format: .dateTime.hour().minute()).font(.title2)
                        Spacer()
                        Text(verbatim: weekdayText(alarm.repeats)).font(.caption).foregroundStyle(Tok.textMuted)
                    }
                }
            }
            .onDelete { offsets in offsets.forEach { context.delete(alarms[$0]) }; try? context.save() }
            Section {
                Button(L("Send all to watch")) { sendAll() }.disabled(!device.isConnected || alarms.isEmpty)
                SendStatusView(state: state)
                Text(L("The order of alarm fields is inferred and not yet confirmed on a real watch.")).font(.footnote).foregroundStyle(Tok.textMuted)
            }
        }
        .navigationTitle(L("Alarms"))
        .toolbar {
            Button { add() } label: { Image(systemName: "plus") }
                .disabled(alarms.count >= maxAlarms)
                .accessibilityLabel(Text(L("Add alarm")))
        }
    }

    private func add() {
        let index = (0..<maxAlarms).first { i in !alarms.contains { $0.index == i } } ?? alarms.count
        context.insert(AlarmRecord(index: index, hour: 7, minute: 0, repeats: Weekdays.all))
        try? context.save()
    }

    private func sendAll() {
        state = .sending
        let commands = alarms.map {
            Command.alarm(index: UInt8($0.index), enabled: $0.enabled, hour: $0.hour, minute: $0.minute, repeats: $0.repeats, flags: 0)
        }
        Task {
            do { for c in commands { try await device.send(c) }; state = .sent }
            catch { state = .failed(describe(error)) }
        }
    }
}

/// Weekday flag and its index in `Calendar.weekdaySymbols` (Sunday = 0).
struct WeekdayItem: Identifiable {
    let day: Weekdays
    let symbolIndex: Int
    var id: Int { symbolIndex }
}

let weekdayOrder: [WeekdayItem] = [
    WeekdayItem(day: .monday, symbolIndex: 1), WeekdayItem(day: .tuesday, symbolIndex: 2),
    WeekdayItem(day: .wednesday, symbolIndex: 3), WeekdayItem(day: .thursday, symbolIndex: 4),
    WeekdayItem(day: .friday, symbolIndex: 5), WeekdayItem(day: .saturday, symbolIndex: 6),
    WeekdayItem(day: .sunday, symbolIndex: 0),
]

func weekdayText(_ days: Weekdays) -> String {
    if days == .all { return S("Every day") }
    let symbols = Calendar.current.shortWeekdaySymbols // Sunday first
    let names = weekdayOrder.filter { days.contains($0.day) }.map { symbols[$0.symbolIndex] }
    return names.isEmpty ? S("Once") : names.joined(separator: " ")
}

struct AlarmEditView: View {
    @Bindable var alarm: AlarmRecord
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            DatePicker(L("Time"), selection: Binding(get: { todayAt(alarm.hour, alarm.minute) }, set: {
                alarm.hour = Calendar.current.component(.hour, from: $0)
                alarm.minute = Calendar.current.component(.minute, from: $0)
            }), displayedComponents: .hourAndMinute)
            Toggle(L("On"), isOn: $alarm.enabled)
            TextField(L("Label (kept on the phone)"), text: $alarm.label)
            Section(L("Repeat")) {
                ForEach(weekdayOrder) { item in
                    Toggle(isOn: Binding(get: { alarm.repeats.contains(item.day) }, set: { on in
                        var r = alarm.repeats
                        if on { r.insert(item.day) } else { r.remove(item.day) }
                        alarm.repeats = r
                    })) { Text(verbatim: Calendar.current.weekdaySymbols[item.symbolIndex]) }
                }
            }
        }
        .navigationTitle(L("Alarm"))
        .onDisappear { try? context.save() }
    }
}

// MARK: S20 notifications

struct NotificationsInfoView: View {
    var body: some View {
        List {
            Section {
                Text(L("On iPhone, apps cannot read other apps' notifications, SMS or call history. Once your watch is paired, it may show iPhone notifications by itself through Apple's notification service (ANCS)."))
            }
            Section {
                UnsupportedNote(reason: L("Whether your watch supports ANCS is not confirmed yet."))
                UnsupportedNote(reason: L("Per-app notification switches on the watch are not confirmed yet."))
                UnsupportedNote(reason: L("Bluetooth calling is paired in iPhone Settings > Bluetooth, not in this app."))
            }
        }
        .navigationTitle(L("Notifications and calls"))
    }
}

// MARK: S28 camera remote

struct CameraRemoteView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("shakePhoto") private var shake = false
    @State private var state: SendState = .idle

    var body: some View {
        Form {
            Toggle(L("Shake the watch to take a photo"), isOn: $shake)
                .onChange(of: shake) { _, v in push(device, .shakeToTakePhoto(on: v), into: $state) }
                .disabled(!device.isConnected)
            SendStatusView(state: state)
            UnsupportedNote(reason: L("The shutter signal from the watch is not confirmed yet, so the in-app camera is not available."))
        }
        .navigationTitle(L("Camera remote"))
    }
}

// MARK: S30 firmware

struct FirmwareView: View {
    @Environment(DeviceController.self) private var device
    var body: some View {
        List {
            Section {
                LabeledContent { Text(verbatim: device.info?.firmwareVersion ?? "–") } label: { Text(L("Firmware version")) }
                LabeledContent { Text(verbatim: device.info.map { "\($0.bandVersionCode)" } ?? "–") } label: { Text(L("Hardware code")) }
                LabeledContent { Text(verbatim: device.family.rawValue) } label: { Text(L("Chip family")) }
            }
            Section {
                UnsupportedNote(reason: L("Firmware updates are turned off. A wrong update can break the watch, the update files come from the original maker's private service, and the update steps are not confirmed."))
            }
        }
        .navigationTitle(L("Firmware"))
    }
}

// MARK: S31 reset and erase

struct AdvancedView: View {
    @Environment(DeviceController.self) private var device
    @State private var confirmReset = false
    @State private var confirmClear = false
    @State private var state: SendState = .idle

    var body: some View {
        List {
            Section {
                Button(L("Erase data on the watch"), role: .destructive) { confirmClear = true }
                Button(L("Factory reset the watch"), role: .destructive) { confirmReset = true }
                SendStatusView(state: state)
            } footer: {
                Text(L("These commands are not confirmed on your watch yet. Use them only if you accept the risk."))
            }
        }
        .disabled(!device.isConnected)
        .navigationTitle(L("Reset and erase"))
        .sheet(isPresented: $confirmClear) {
            ConfirmPhraseSheet(title: L("Erase data on the watch"), message: L("Health data stored on the watch will be deleted."), phrase: "ERASE") { consent in
                run(.clearData, consent)
            }
        }
        .sheet(isPresented: $confirmReset) {
            ConfirmPhraseSheet(title: L("Factory reset the watch"), message: L("All settings and data on the watch will be deleted and it will disconnect."), phrase: "RESET") { consent in
                run(.factoryReset, consent)
            }
        }
    }

    private func run(_ command: Command, _ consent: UserConsent) {
        state = .sending
        Task {
            do { try await device.send(command, consent: consent); state = .sent }
            catch { state = .failed(describe(error)) }
        }
    }
}

// MARK: S15 files and media

struct FilesView: View {
    var body: some View {
        List {
            Section(L("Photos and wallpapers")) {
                UnsupportedNote(reason: L("Image transfer packets are not confirmed yet. Create faces in the Faces tab; installing them will work once confirmed."))
            }
            Section(L("Music")) {
                UnsupportedNote(reason: L("Music transfer format is not confirmed yet."))
            }
            Section(L("E-books and audio notes")) {
                UnsupportedNote(reason: L("These transfers are not confirmed yet."))
            }
        }
        .navigationTitle(L("Files and media"))
    }
}

// MARK: S33 packet log (hidden: tap the version five times)

struct PacketLogView: View {
    @Environment(DeviceController.self) private var device
    var body: some View {
        List(device.packetLog.reversed()) { line in
            VStack(alignment: .leading) {
                Text(line.date, format: .dateTime.hour().minute().second()).font(.caption2).foregroundStyle(Tok.textMuted)
                Text(verbatim: (line.outgoing ? "→ " : "← ") + line.hex).font(.caption.monospaced())
                    .foregroundStyle(line.outgoing ? Tok.accent : Tok.text)
            }
        }
        .navigationTitle(L("Packet log"))
        .toolbar {
            ShareLink(item: device.packetLog.map { "\($0.date.ISO8601Format()) \($0.outgoing ? ">" : "<") \($0.hex)" }.joined(separator: "\n"))
        }
    }
}
