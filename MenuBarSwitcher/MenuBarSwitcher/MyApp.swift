import ComposableArchitecture
import SwiftUI

@main
struct MyApp: App {
    private let store = Store(initialState: MenuBarFeature.State()) {
        MenuBarFeature()
    }

    var body: some Scene {
        MenuBarExtra("MenuBarSwitcher", systemImage: "ellipsis") {
            ContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
