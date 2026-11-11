import SwiftUI

@main
struct FeederApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environmentObject(state)
        } label: {
            Image(systemName: state.armed ? "keyboard.fill" : "keyboard")
        }
        .menuBarExtraStyle(.window)

        Window("Feeder Settings", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)
    }
}
