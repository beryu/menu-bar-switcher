import AppKit
import ComposableArchitecture
import SwiftUI

@main
struct MyApp: App {
    @NSApplicationDelegateAdaptor(MenuBarAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class MenuBarAppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store(initialState: MenuBarFeature.State()) {
        MenuBarFeature()
    }
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "MenuBarSwitcher")
        button.image?.isTemplate = true
        button.target = self
        button.action = #selector(statusItemClicked(_:))

        let hostingController = NSHostingController(rootView: ContentView(store: store))
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.behavior = .transient
    }

    @objc private func statusItemClicked(_ button: NSStatusBarButton) {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            popover.performClose(nil)
            showOptionMenu(from: button)
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            store.send(.appeared)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showOptionMenu(from button: NSStatusBarButton) {
        let status = OpenAtLoginClient.liveValue.status()
        store.send(.openAtLoginStatusLoaded(status))

        let menu = NSMenu()
        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = status.isRegistered ? .on : .off
        loginItem.isEnabled = status != .unavailable && !store.isUpdatingOpenAtLogin
        menu.addItem(loginItem)
        if status == .requiresApproval || status == .unavailable {
            let explanation = status == .requiresApproval
                ? "システム設定のログイン項目で許可してください"
                : "ログイン項目の状態を取得できませんでした"
            let explanationItem = NSMenuItem(title: explanation, action: nil, keyEquivalent: "")
            explanationItem.isEnabled = false
            menu.addItem(explanationItem)
        }
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MenuBarSwitcher", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.minX, y: button.bounds.minY), in: button)
    }

    @objc private func toggleOpenAtLogin(_ item: NSMenuItem) {
        store.send(.openAtLoginToggled(item.state != .on))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
