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
    @Environment(DeviceController.self) private var device

    var body: some View {
        if onboarded {
            TabView {
                TodayView().tabItem { Label(L("Today"), systemImage: "heart.text.square") }
                WorkoutsView().tabItem { Label(L("Workouts"), systemImage: "figure.run") }
                FacesView().tabItem { Label(L("Faces"), systemImage: "applewatch") }
                DeviceView().tabItem { Label(L("Watch"), systemImage: "gearshape") }
            }
            .tint(Tok.accent)
            .alert(L("Your watch is looking for this phone"),
                   isPresented: Binding(get: { device.isFindingPhone }, set: { if !$0 { device.stopRinging() } })) {
                Button(L("Stop")) { device.stopRinging() }
            }
        } else {
            OnboardingView { onboarded = true }
        }
    }
}
