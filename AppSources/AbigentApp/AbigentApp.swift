import SwiftUI

@main
struct AbigentApplication: App {
    @StateObject private var model = AppModel.make()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
                .frame(width: 390, height: 560)
        } label: {
            Image(systemName: model.menuBarSymbol)
                .task { await model.applicationDidBecomeReady() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 520, height: 560)
        }
    }
}
