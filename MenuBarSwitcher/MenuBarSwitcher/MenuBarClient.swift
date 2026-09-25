import AppKit
import ApplicationServices
import ComposableArchitecture

struct MenuBarEntry: Equatable, Identifiable {
    let id: UUID
    let applicationName: String
    let title: String
}

struct MenuBarClient {
    var isTrusted: @MainActor () -> Bool
    var requestAccess: @MainActor () -> Void
    var openAccessibilitySettings: @MainActor () -> Bool
    var scan: @MainActor () -> [MenuBarEntry]
    var press: @MainActor (UUID) -> Bool
}

extension MenuBarClient: DependencyKey {
    static let liveValue = Self(
        isTrusted: { AXIsProcessTrusted() },
        requestAccess: {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        },
        openAccessibilitySettings: {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return false }
            return NSWorkspace.shared.open(url)
        },
        scan: { MenuBarAccessibility.shared.scan() },
        press: { MenuBarAccessibility.shared.press($0) }
    )
}

extension DependencyValues {
    var menuBarClient: MenuBarClient {
        get { self[MenuBarClient.self] }
        set { self[MenuBarClient.self] = newValue }
    }
}

@MainActor
private final class MenuBarAccessibility {
    static let shared = MenuBarAccessibility()
    private var elements: [UUID: AXUIElement] = [:]

    func scan() -> [MenuBarEntry] {
        elements.removeAll()
        guard AXIsProcessTrusted() else { return [] }

        var entries: [MenuBarEntry] = []
        for application in NSWorkspace.shared.runningApplications where application.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.25)
            guard let bar = elementAttribute(kAXExtrasMenuBarAttribute as CFString, of: appElement) else { continue }
            let appName = application.localizedName ?? "Unknown application"
            for (index, child) in children(of: bar).enumerated() {
                let actions = actionNames(of: child)
                guard actions.contains(kAXPressAction as String) else { continue }
                let title = stringAttribute(kAXTitleAttribute as CFString, of: child)
                    ?? stringAttribute(kAXDescriptionAttribute as CFString, of: child)
                    ?? "Item \(index + 1)"
                let id = UUID()
                elements[id] = child
                entries.append(MenuBarEntry(id: id, applicationName: appName, title: title))
            }
        }
        return entries.sorted {
            ($0.applicationName, $0.title) < ($1.applicationName, $1.title)
        }
    }

    func press(_ id: UUID) -> Bool {
        guard let element = elements[id], AXIsProcessTrusted() else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    private func elementAttribute(_ attribute: CFString, of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let values = value as? [Any] else { return [] }
        return values.compactMap { value in
            guard CFGetTypeID(value as CFTypeRef) == AXUIElementGetTypeID() else { return nil }
            let element = value as! AXUIElement
            return element
        }
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? String
    }

    private func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }
}
