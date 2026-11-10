import SwiftData
import SwiftUI
import WatchCore

/// S17: the watch — connection, info, capabilities, every setting.
struct DeviceView: View {
    @Environment(DeviceController.self) private var device
    @Query(sort: \DeviceRecord.lastSeen, order: .reverse) private var saved: [DeviceRecord]
    @State private var findState: SendState = .idle
    @State private var versionTaps = 0
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            List {
                Section { header }
                if saved.isEmpty && !device.isConnected {
                    Section {
                        NavigationLink { ScanView() } label: { Label(L("Add a watch"), systemImage: "plus.circle.fill") }
                    }
                } else {
                    Section {
                        NavigationLink { MyDevicesView() } label: { Label(L("My watches"), systemImage: "applewatch") }
                    }
                }
                Section(L("Health on the watch")) {
                    NavigationLink { HeartSettingsView() } label: { Label(L("Measurement"), systemImage: "heart") }
                    NavigationLink { RemindersView() } label: { Label(L("Reminders"), systemImage: "bell.badge") }
                    NavigationLink { AlarmsView() } label: { Label(L("Alarms"), systemImage: "alarm") }
                    NavigationLink { DoNotDisturbView() } label: { Label(L("Do Not Disturb"), systemImage: "moon") }
                }
                Section(L("Watch settings")) {
                    NavigationLink { DisplaySettingsView() } label: { Label(L("Display and time"), systemImage: "sun.max") }
                    NavigationLink { NotificationsInfoView() } label: { Label(L("Notifications and calls"), systemImage: "message") }
                    NavigationLink { BlockedFeatureView(title: L("Weather"), reason: L("The weather packet layout is not confirmed yet, so Sawar does not send weather to the watch.")) }
                        label: { Label(L("Weather"), systemImage: "cloud.sun") }
                    NavigationLink { BlockedFeatureView(title: L("Contacts"), reason: L("The contact packet layout is not confirmed yet, so Sawar does not send contacts to the watch.")) }
                        label: { Label(L("Contacts"), systemImage: "person.2") }
                    NavigationLink { BlockedFeatureView(title: L("Language"), reason: L("The watch's language codes are not confirmed yet. Change the language on the watch itself for now.")) }
                        label: { Label(L("Language"), systemImage: "globe") }
                    NavigationLink { CameraRemoteView() } label: { Label(L("Camera remote"), systemImage: "camera") }
                }
                Section(L("Media and apps")) {
                    NavigationLink { FilesView() } label: { Label(L("Files and media"), systemImage: "folder") }
                    NavigationLink { BlockedFeatureView(title: L("Watch apps"), reason: L("Installing apps on the watch needs packages from the original maker's private store. Listing installed apps is not confirmed yet.")) }
                        label: { Label(L("Watch apps"), systemImage: "square.grid.2x2") }
                }
                Section(L("Tools")) {
                    Button { Task { await find() } } label: { Label(L("Find my watch"), systemImage: "dot.radiowaves.left.and.right") }
                        .disabled(!device.isConnected)
                    SendStatusView(state: findState)
                    NavigationLink { BlockedFeatureView(title: L("Find my phone"), reason: L("Ringing the phone from the watch is not available yet: the watch's request packet is not confirmed.")) }
                        label: { Label(L("Find my phone"), systemImage: "iphone.radiowaves.left.and.right") }
                    NavigationLink { FirmwareView() } label: { Label(L("Firmware"), systemImage: "cpu") }
                    NavigationLink { AdvancedView() } label: { Label(L("Reset and erase"), systemImage: "exclamationmark.octagon") }
                }
                Section(L("What this watch supports")) { capabilities }
                Section {
                    Text(L("Version 0.1.0 — protocol not yet confirmed on a real watch"))
                        .font(.footnote).foregroundStyle(Tok.textMuted)
                        .onTapGesture { versionTaps += 1; if versionTaps >= 5 { showDebug = true; versionTaps = 0 } }
                }
            }
            .navigationTitle(L("Watch"))
            .navigationDestination(isPresented: $showDebug) { PacketLogView() }
        }
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: Tok.Space.l) {
            Image(systemName: "applewatch").font(.system(size: 40)).foregroundStyle(Tok.accent).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Tok.Space.xs) {
                Text(verbatim: device.connectedName.isEmpty ? S("No watch") : device.connectedName).font(.headline)
                linkLabel
                if let info = device.info {
                    Text(verbatim: S("Firmware") + " " + info.firmwareVersion).font(.caption).foregroundStyle(Tok.textMuted)
                }
                Text(L("Battery: not available yet")).font(.caption).foregroundStyle(Tok.textMuted)
            }
            Spacer()
        }
        if device.isConnected {
            Button(L("Disconnect")) { device.disconnect() }
        } else if case .failed = device.link {
            Button(L("Try again")) { device.reconnectSaved() }
        }
    }

    @ViewBuilder private var linkLabel: some View {
        switch device.link {
        case .connected: Label(L("Connected"), systemImage: "checkmark.circle.fill").foregroundStyle(Tok.success).font(.subheadline)
        case .connecting: Label(L("Connecting…"), systemImage: "arrow.triangle.2.circlepath").foregroundStyle(Tok.textMuted).font(.subheadline)
        case .scanning: Label(L("Searching…"), systemImage: "magnifyingglass").foregroundStyle(Tok.textMuted).font(.subheadline)
        case .bluetoothOff: Label(L("Bluetooth is off"), systemImage: "bolt.horizontal.circle").foregroundStyle(Tok.warning).font(.subheadline)
        case .bluetoothUnauthorized: Label(L("Bluetooth permission needed in Settings"), systemImage: "lock").foregroundStyle(Tok.warning).font(.subheadline)
        case .idle: Label(L("Not connected"), systemImage: "circle").foregroundStyle(Tok.textMuted).font(.subheadline)
        case let .failed(message): Label(message, systemImage: "xmark.octagon").foregroundStyle(Tok.danger).font(.subheadline)
        }
    }

    @ViewBuilder private var capabilities: some View {
        let caps = device.capabilities
        CapabilityChip(title: L("Heart rate"), availability: caps[.heartRate])
        CapabilityChip(title: L("Blood oxygen"), availability: caps[.bloodOxygen])
        CapabilityChip(title: L("Blood pressure"), availability: caps[.bloodPressure])
        CapabilityChip(title: L("Sleep"), availability: caps[.sleep])
        CapabilityChip(title: L("Weather"), availability: caps[.weather])
        CapabilityChip(title: L("Sedentary reminder"), availability: caps[.sedentaryReminder])
        CapabilityChip(title: L("Firmware update flag"), availability: caps[.firmwareUpdate])
        Text(L("Chip family")).font(.caption).foregroundStyle(Tok.textMuted)
        Text(verbatim: device.family.rawValue).font(.caption.monospaced())
    }

    private func find() async {
        findState = .sending
        do { try await device.send(.findWatch); findState = .sent } catch { findState = .failed(describe(error)) }
    }
}

/// Generic screen for a feature that is known but blocked, with the honest reason.
struct BlockedFeatureView: View {
    let title: LocalizedStringKey
    let reason: LocalizedStringKey
    var body: some View {
        List { Section { UnsupportedNote(reason: reason) } }
            .navigationTitle(title)
    }
}

/// S18: scan with name, identifier and signal.
struct ScanView: View {
    @Environment(DeviceController.self) private var device
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                if device.link == .bluetoothOff {
                    UnsupportedNote(reason: L("Turn on Bluetooth to find your watch."))
                }
                Text(L("Keep the watch close and awake. If it is paired with another phone, unpair it there first."))
                    .font(.footnote).foregroundStyle(Tok.textMuted)
            }
            Section(L("Nearby")) {
                if device.discovered.isEmpty {
                    HStack { ProgressView(); Text(L("Searching…")).foregroundStyle(Tok.textMuted) }
                }
                ForEach(device.discovered.sorted { $0.rssi > $1.rssi }) { watch in
                    Button {
                        device.connect(watch)
                        dismiss()
                    } label: { ScanRow(watch: watch) }
                }
            }
        }
        .navigationTitle(L("Add a watch"))
        .onAppear { device.startScan() }
        .onDisappear { device.stopScan() }
    }
}

struct ScanRow: View {
    let watch: DiscoveredWatch
    private var bars: Int { watch.rssi > -60 ? 3 : watch.rssi > -75 ? 2 : 1 }
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(verbatim: watch.name).font(.headline).foregroundStyle(Tok.text)
                Text(verbatim: String(watch.id.uuidString.prefix(8))).font(.caption.monospaced()).foregroundStyle(Tok.textMuted)
            }
            Spacer()
            Text(verbatim: "\(watch.rssi) dBm").font(.caption).foregroundStyle(Tok.textMuted)
            Image(systemName: "cellularbars", variableValue: Double(bars) / 3).foregroundStyle(Tok.accent)
                .accessibilityLabel(Text(bars == 3 ? L("Strong signal") : bars == 2 ? L("Medium signal") : L("Weak signal")))
        }
    }
}

/// S19: saved watches, switch and forget.
struct MyDevicesView: View {
    @Environment(DeviceController.self) private var device
    @Query(sort: \DeviceRecord.lastSeen, order: .reverse) private var saved: [DeviceRecord]

    var body: some View {
        List {
            ForEach(saved) { record in
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: record.name).font(.headline)
                        Text(verbatim: [record.firmware, record.family.rawValue].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(Tok.textMuted)
                    }
                    Spacer()
                    if record.id == device.connectedID {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Tok.success)
                            .accessibilityLabel(Text(L("Connected")))
                    }
                }
                .swipeActions {
                    Button(L("Forget"), role: .destructive) { device.forget(record) }
                }
            }
            NavigationLink { ScanView() } label: { Label(L("Add a watch"), systemImage: "plus") }
        }
        .navigationTitle(L("My watches"))
    }
}
