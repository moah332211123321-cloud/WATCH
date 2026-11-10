import SwiftUI
import WatchCore

/// Concentric goal rings (replica/design/components.md: MetricRing).
struct MetricRing: View {
    struct Ring: Identifiable { let id = UUID(); let progress: Double; let color: Color }
    let rings: [Ring]
    var lineWidth: CGFloat = 16

    var body: some View {
        ZStack {
            ForEach(Array(rings.enumerated()), id: \.element.id) { index, ring in
                let inset = CGFloat(index) * (lineWidth + 4)
                Circle().stroke(ring.color.opacity(0.2), lineWidth: lineWidth).padding(inset)
                Circle()
                    .trim(from: 0, to: min(ring.progress, 1))
                    .stroke(ring.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(inset)
                    .animation(Tok.ringAnimation, value: ring.progress)
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

/// Rounded surface card with a coloured title (MetricCard).
struct Card<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tok.Space.s) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tok.Space.l)
        .background(Tok.surface, in: RoundedRectangle(cornerRadius: Tok.Radius.l, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Big number with unit, e.g. "72 bpm".
struct MetricValue: View {
    let value: String
    let unit: LocalizedStringKey
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tok.Space.xs) {
            Text(verbatim: value).font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(Tok.text)
            Text(unit).font(.subheadline).foregroundStyle(Tok.textMuted)
        }
    }
}

/// Explains why something is not available instead of hiding it or faking it (UnsupportedState).
struct UnsupportedNote: View {
    let reason: LocalizedStringKey
    var body: some View {
        Label(reason, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Tok.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Availability chip for a capability.
struct CapabilityChip: View {
    let title: LocalizedStringKey
    let availability: Availability
    var body: some View {
        HStack {
            Text(title).foregroundStyle(Tok.text)
            Spacer()
            switch availability {
            case .supported: Label(L("Supported"), systemImage: "checkmark.circle.fill").foregroundStyle(Tok.success)
            case .unsupported: Label(L("Not on this watch"), systemImage: "xmark.circle").foregroundStyle(Tok.textMuted)
            case .unknown: Label(L("Unknown"), systemImage: "questionmark.circle").foregroundStyle(Tok.textMuted)
            }
        }
        .font(.subheadline)
        .labelStyle(.titleAndIcon)
    }
}

/// Shows the result of a command sent to the watch: waiting, saved (only after the call returned), failed.
enum SendState: Equatable {
    case idle, sending, sent, failed(String)
}

struct SendStatusView: View {
    let state: SendState
    var body: some View {
        switch state {
        case .idle: EmptyView()
        case .sending: ProgressView().accessibilityLabel(Text(L("Sending to watch")))
        case .sent: Label(L("Sent to watch"), systemImage: "checkmark").foregroundStyle(Tok.success).font(.footnote)
        case let .failed(message): Label(message, systemImage: "xmark.octagon").foregroundStyle(Tok.danger).font(.footnote)
        }
    }
}

/// Typed-confirmation sheet for destructive actions (DestructiveConfirmSheet).
struct ConfirmPhraseSheet: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let phrase: String
    let onConfirm: (UserConsent) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(message).foregroundStyle(Tok.textMuted) }
                Section {
                    Text(L("Type this word to confirm:"))
                    Text(verbatim: phrase).font(.headline.monospaced())
                    TextField(L("Confirmation"), text: $typed)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Section {
                    Button(role: .destructive) {
                        onConfirm(UserConsent(confirmedPhrase: typed))
                        dismiss()
                    } label: { Text(title) }
                    .disabled(typed != phrase)
                }
            }
            .navigationTitle(title)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
        }
    }
}

extension WatchError {
    /// User-facing explanation, in the app's voice (replica/brand.md).
    var message: String {
        switch self {
        case .notConnected: return S("Your watch is not connected.")
        case .timeout: return S("Your watch didn't answer. Try again?")
        case .unsupportedByWatch: return S("Not supported on this watch.")
        case .protocolUnconfirmed: return S("Not available yet: this needs to be confirmed on a real watch first.")
        case .needsVendorServer: return S("Not available: this needs the original maker's private service.")
        case .consentRequired: return S("Please confirm first.")
        }
    }
}

func describe(_ error: Error) -> String {
    (error as? WatchError)?.message ?? error.localizedDescription
}
