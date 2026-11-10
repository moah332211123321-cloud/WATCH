import SwiftUI

/// S32: profile, goals, Apple Health, about.
struct SettingsView: View {
    @Environment(DeviceController.self) private var device
    @AppStorage("stepGoal") private var stepGoal = 8000
    @AppStorage("kcalGoal") private var kcalGoal = 400
    @AppStorage("heightCm") private var heightCm = 170
    @AppStorage("weightKg") private var weightKg = 70
    @AppStorage("exportToHealth") private var exportToHealth = false
    @State private var healthError: String?

    var body: some View {
        Form {
            Section(L("Goals")) {
                Stepper(value: $stepGoal, in: 1000...50000, step: 500) {
                    LabeledContent { Text(verbatim: stepGoal.formatted()) } label: { Text(L("Daily steps")) }
                }
                Stepper(value: $kcalGoal, in: 100...3000, step: 50) {
                    LabeledContent { Text(verbatim: kcalGoal.formatted()) } label: { Text(L("Active energy (kcal)")) }
                }
            }
            Section {
                Stepper(value: $heightCm, in: 100...230) {
                    LabeledContent { Text(verbatim: "\(heightCm)") } label: { Text(L("Height (cm)")) }
                }
                Stepper(value: $weightKg, in: 30...250) {
                    LabeledContent { Text(verbatim: "\(weightKg)") } label: { Text(L("Weight (kg)")) }
                }
            } header: { Text(L("Profile")) } footer: {
                Text(L("Kept on this iPhone. Sending the profile to the watch is not confirmed yet."))
            }
            Section {
                Toggle(L("Save watch measurements to Apple Health"), isOn: $exportToHealth)
                    .onChange(of: exportToHealth) { _, on in
                        guard on else { return }
                        Task {
                            do { try await device.health.requestAuthorization(); await device.exportPending() }
                            catch { healthError = error.localizedDescription; exportToHealth = false }
                        }
                    }
                if let healthError { Text(healthError).font(.footnote).foregroundStyle(Tok.danger) }
            } header: { Text(L("Apple Health")) } footer: {
                Text(L("Only values measured by the watch are saved. Your manual entries stay in Sawar."))
            }
            Section(L("About")) {
                Text(L("Sawar is an independent app. It is not made by or affiliated with the maker of your watch or its original app."))
                Text(L("Every watch command in this version was learned by studying the original Android app and still needs confirming on a real watch."))
                    .foregroundStyle(Tok.textMuted)
            }
        }
        .navigationTitle(L("Settings"))
    }
}
