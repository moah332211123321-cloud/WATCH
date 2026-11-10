import CoreBluetooth
import Foundation
import WatchCore

/// A watch seen during scanning.
struct DiscoveredWatch: Identifiable, Equatable {
    let id: UUID          // CoreBluetooth identifier (iOS does not expose the MAC address)
    var name: String
    var rssi: Int
    var advertisedServices: [String]
    var lastSeen: Date
}

enum BLEEvent {
    case powerChanged(CBManagerState)
    case discovered(DiscoveredWatch)
    case connected(UUID)
    case ready(UUID, services: [String])
    case disconnected(UUID, Error?)
    case failed(UUID, Error?)
    case data(Data, Channel)
}

/// CoreBluetooth central + `WatchTransport`. All CoreBluetooth work runs on the main queue.
/// The app never talks to CoreBluetooth anywhere else (views and drivers go through this).
final class BLECentral: NSObject, WatchTransport, @unchecked Sendable {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChars: [Channel: CBCharacteristic] = [:]
    private var pendingWrite: CheckedContinuation<Void, Error>?
    var onEvent: (@MainActor (BLEEvent) -> Void)?

    static let restoreID = "app.sawar.central"

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey: Self.restoreID])
    }

    var state: CBManagerState { central.state }

    func startScan() {
        guard central.state == .poweredOn else { return }
        // Watches do not always advertise the command service, so scan without a filter.
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func stopScan() { central.stopScan() }

    func connect(_ id: UUID) {
        guard let p = central.retrievePeripherals(withIdentifiers: [id]).first else {
            emit(.failed(id, nil)); return
        }
        peripheral = p
        p.delegate = self
        central.connect(p, options: nil)
    }

    func disconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
    }

    // MARK: WatchTransport

    var maximumWriteLength: Int {
        peripheral?.maximumWriteValueLength(for: .withoutResponse) ?? 20
    }

    /// Writes are serialised: one in flight at a time, in order.
    func write(_ data: Data, channel: Channel) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                self.queue.append((data, channel, cont))
                self.pump()
            }
        }
    }

    private var queue: [(Data, Channel, CheckedContinuation<Void, Error>)] = []

    private func pump() {
        while pendingWrite == nil, let item = queue.first {
            let (data, channel, cont) = item
            guard let p = peripheral, p.state == .connected, let char = writeChars[channel] else {
                queue.removeFirst()
                cont.resume(throwing: WatchError.notConnected)
                continue
            }
            // Like Android's default (used by the reference app): write-without-response when the
            // characteristic offers it — far faster for picture transfers.
            if char.properties.contains(.writeWithoutResponse) {
                guard p.canSendWriteWithoutResponse else { return } // resumes in peripheralIsReady(...)
                queue.removeFirst()
                p.writeValue(data, for: char, type: .withoutResponse)
                cont.resume()
            } else {
                queue.removeFirst()
                pendingWrite = cont
                p.writeValue(data, for: char, type: .withResponse)
            }
        }
    }

    private func emit(_ event: BLEEvent) {
        MainActor.assumeIsolated { onEvent?(event) }
    }
}

extension BLECentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emit(.powerChanged(central.state))
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let restored = (dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral])?.first {
            peripheral = restored
            restored.delegate = self
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard !name.isEmpty else { return }
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID])?.map(\.uuidString) ?? []
        emit(.discovered(DiscoveredWatch(id: peripheral.identifier, name: name, rssi: RSSI.intValue,
                                         advertisedServices: services, lastSeen: Date())))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        emit(.connected(peripheral.identifier))
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        emit(.failed(peripheral.identifier, error))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        writeChars.removeAll()
        pendingWrite?.resume(throwing: WatchError.notConnected)
        pendingWrite = nil
        queue.forEach { $0.2.resume(throwing: WatchError.notConnected) }
        queue.removeAll()
        emit(.disconnected(peripheral.identifier, error))
    }
}

extension BLECentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for char in service.characteristics ?? [] {
            switch char.uuid.uuidString.uppercased() {
            case GATT.commandWrite: writeChars[.command] = char
            case GATT.fileWrite: writeChars[.file] = char
            case GATT.commandNotify, GATT.fileNotify: peripheral.setNotifyValue(true, for: char)
            default: break
            }
        }
        let allDiscovered = (peripheral.services ?? []).allSatisfy { $0.characteristics != nil }
        if allDiscovered, writeChars[.command] != nil {
            emit(.ready(peripheral.identifier, services: (peripheral.services ?? []).map(\.uuid.uuidString)))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        let channel: Channel = characteristic.uuid.uuidString.uppercased() == GATT.fileNotify ? .file : .command
        emit(.data(value, channel))
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        pump()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let cont = pendingWrite else { return }
        pendingWrite = nil
        if let error { cont.resume(throwing: error) } else { cont.resume() }
        pump()
    }
}
