import SwiftUI

/// S01: what the app needs and why. Permissions are asked when first used, not all at once.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: Tok.Space.xl) {
            TabView(selection: $page) {
                pageView(icon: "applewatch.radiowaves.left.and.right", title: L("Your watch, your phone"),
                         text: L("Sawar talks to your watch directly over Bluetooth. No account, no cloud."))
                    .tag(0)
                pageView(icon: "heart.text.square", title: L("Your health data stays yours"),
                         text: L("Measurements are stored on this iPhone. You choose what goes to Apple Health."))
                    .tag(1)
                pageView(icon: "checkmark.seal", title: L("Honest about what works"),
                         text: L("If your watch or iPhone can't do something, Sawar tells you why instead of pretending."))
                    .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 2 { withAnimation { page += 1 } } else { onDone() }
            } label: {
                Text(page < 2 ? L("Continue") : L("Get started"))
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, Tok.Space.m)
            }
            .buttonStyle(.borderedProminent)
            .tint(Tok.accent)
            .padding(.horizontal, Tok.Space.xl)
            .padding(.bottom, Tok.Space.xl)
        }
        .background(Tok.bg)
    }

    private func pageView(icon: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        VStack(spacing: Tok.Space.l) {
            Image(systemName: icon).font(.system(size: 72)).foregroundStyle(Tok.accent)
                .accessibilityHidden(true)
            Text(title).font(.title.bold()).multilineTextAlignment(.center).foregroundStyle(Tok.text)
            Text(text).font(.body).multilineTextAlignment(.center).foregroundStyle(Tok.textMuted)
        }
        .padding(Tok.Space.xl)
    }
}
