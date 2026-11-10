import Foundation

/// Features the app can offer. Availability comes from the watch's own bytes, never from a server.
public enum Feature: String, CaseIterable, Codable, Sendable {
    case steps, heartRate, bloodOxygen, bloodPressure, temperature, sleep, stress
    case findWatch, alarms, sedentaryReminder, drinkWaterReminder, doNotDisturb, raiseToWake
    case twelveHourClock, temperatureUnit, hourlyMeasurement, shakeToTakePhoto
    case weather, contacts, notifications, musicControl, cameraRemote, findPhone
    case watchFaces, fileTransfer, watchApps, firmwareUpdate, menstrual, license
    case factoryReset, clearData
}

public enum Availability: String, Codable, Sendable {
    /// The watch says it has it.
    case supported
    /// The watch says it does not have it.
    case unsupported
    /// No flag found for it; the app may try and show the watch's answer (or the timeout).
    case unknown
}

/// Capability set decoded from the device-info bytes (research/devices.md §3).
///
/// Bit positions for byte 15 and byte 17 are inferred from field order in the reference app and are
/// unconfirmed, so those flags only ever upgrade a feature from `.unknown` to `.supported`; they never
/// hide a feature.
public struct Capabilities: Equatable, Sendable {
    public private(set) var flags: [Feature: Availability] = [:]

    public init(flags: [Feature: Availability] = [:]) { self.flags = flags }

    public subscript(feature: Feature) -> Availability { flags[feature] ?? .unknown }

    public init(deviceInfoBytes b: [Int: UInt8]) {
        // Commands present in every model of this protocol family (all builders share the AB set).
        for f in [Feature.steps, .findWatch, .alarms, .doNotDisturb, .raiseToWake, .factoryReset, .clearData] {
            flags[f] = .supported
        }
        if let b11 = b[11] {
            flags[.license] = (b11 >> 1) & 1 == 1 ? .supported : .unsupported      // D
            flags[.firmwareUpdate] = (b11 >> 2) & 1 == 1 ? .supported : .unsupported // D (flag only; flashing stays gated)
        }
        if let b15 = b[15] {                                                  // I: bit order
            if b15 & (1 << 1) != 0 { flags[.sleep] = .supported }
            if b15 & (1 << 2) != 0 { flags[.twelveHourClock] = .supported }
            if b15 & (1 << 7) != 0 { flags[.menstrual] = .supported }
        }
        if let b17 = b[17] {                                                  // I: bit order
            if b17 & (1 << 2) != 0 { flags[.sedentaryReminder] = .supported }
            if b17 & (1 << 6) != 0 { flags[.weather] = .supported }
        }
        // Not decoded yet: byte 16 (a value table for BP / SpO2 / ECG / continuous HR) and byte 18
        // (screen table). Those features stay `.unknown` and are probed.
    }

    public mutating func set(_ feature: Feature, _ availability: Availability) {
        flags[feature] = availability
    }
}
