import SwiftData
import SwiftUI

@main
struct SawarApp: App {
    let container: ModelContainer
    @State private var device: DeviceController

    init() {
        do {
            container = try ModelContainer(for: Schema(AppSchema.models))
        } catch {
            fatalError("Could not open the local database: \(error)")
        }
        let controller = DeviceController()
        controller.context = container.mainContext // before Bluetooth powers on and auto-reconnects
        _device = State(initialValue: controller)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(device)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        if onboarded {
            TabView {
                TodayView().tabItem { Label(L("Today"), systemImage: "heart.text.square") }
                WorkoutsView().tabItem { Label(L("Workouts"), systemImage: "figure.run") }
                FacesView().tabItem { Label(L("Faces"), systemImage: "applewatch") }
                DeviceView().tabItem { Label(L("Watch"), systemImage: "gearshape") }
            }
            .tint(Tok.accent)
        } else {
            OnboardingView { onboarded = true }
        }
    }
}
