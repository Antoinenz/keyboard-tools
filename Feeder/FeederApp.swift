import SwiftUI

@main
struct FeederApp: App {
    @StateObject private var state = AppState()

    private var menuBarSymbol: String {
        if !state.tapRunning { return "exclamationmark.triangle" } // permissions missing
        return state.armed ? "keyboard.fill" : "keyboard"
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView().environmentObject(state)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Feeder Settings", id: "settings") {
            SettingsView().environmentObject(state)
        }
        .windowResizability(.contentSize)
    }
}
