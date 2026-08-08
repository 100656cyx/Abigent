import SwiftUI

@main
struct AbigentApplication: App {
    @StateObject private var model = AppModel.make()

    var body: some Scene {
        MenuBarExtra("Abigent", systemImage: model.menuBarSymbol) {
            MenuBarContentView()
                .environmentObject(model)
                .frame(width: 390, height: 560)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 480, height: 360)
        }
    }
}
