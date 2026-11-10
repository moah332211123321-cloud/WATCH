import SwiftUI
import WatchCore

/// Presentation data per metric (titles are localized keys).
extension Metric {
    var title: LocalizedStringKey {
        switch self {
        case .steps: return L("Steps")
        case .heartRate: return L("Heart rate")
        case .bloodOxygen: return L("Blood oxygen")
        case .bloodPressure: return L("Blood pressure")
        case .temperature: return L("Body temperature")
        case .stress: return L("Stress")
        case .sleep: return L("Sleep")
        case .weight: return L("Weight")
        case .glucose: return L("Blood glucose")
        }
    }

    var unit: LocalizedStringKey {
        switch self {
        case .steps: return L("steps")
        case .heartRate: return L("bpm")
        case .bloodOxygen: return L("percent")
        case .bloodPressure: return L("mmHg")
        case .temperature: return L("°C")
        case .stress: return L("score")
        case .sleep: return L("min")
        case .weight: return L("kg")
        case .glucose: return L("mmol/L")
        }
    }

    var color: Color {
        switch self {
        case .steps: return Tok.steps
        case .heartRate: return Tok.heart
        case .bloodOxygen: return Tok.oxygen
        case .bloodPressure: return Tok.heart
        case .temperature: return Tok.temp
        case .stress: return Tok.stress
        case .sleep: return Tok.sleep
        case .weight, .glucose: return Tok.accent
        }
    }

    var icon: String {
        switch self {
        case .steps: return "figure.walk"
        case .heartRate: return "heart.fill"
        case .bloodOxygen: return "lungs.fill"
        case .bloodPressure: return "waveform.path.ecg"
        case .temperature: return "thermometer.medium"
        case .stress: return "brain.head.profile"
        case .sleep: return "bed.double.fill"
        case .weight: return "scalemass.fill"
        case .glucose: return "drop.fill"
        }
    }

    /// Watch measurement that produces this metric, if any.
    var measureKind: MeasureKind? {
        switch self {
        case .heartRate: return .heartRate
        case .bloodOxygen: return .bloodOxygen
        case .bloodPressure: return .bloodPressure
        case .temperature: return .temperature
        default: return nil
        }
    }

    var capability: Feature? {
        switch self {
        case .heartRate: return .heartRate
        case .bloodOxygen: return .bloodOxygen
        case .bloodPressure: return .bloodPressure
        case .temperature: return .temperature
        case .stress: return .stress
        case .sleep: return .sleep
        case .steps: return .steps
        case .weight, .glucose: return nil
        }
    }

    /// Manual entry is offered where people commonly measure with another device.
    var allowsManualEntry: Bool { [.bloodPressure, .temperature, .weight, .glucose].contains(self) }

    func format(_ value: Double, _ value2: Double? = nil) -> String {
        switch self {
        case .temperature, .glucose, .weight: return value.formatted(.number.precision(.fractionLength(1)))
        case .bloodPressure: return "\(Int(value))/\(Int(value2 ?? 0))"
        default: return Int(value).formatted()
        }
    }
}

extension SampleSource {
    var label: LocalizedStringKey {
        switch self {
        case .device: return L("Watch")
        case .manual: return L("Entered by you")
        case .healthKit: return L("Apple Health")
        case .estimate: return L("Estimated")
        }
    }
}
