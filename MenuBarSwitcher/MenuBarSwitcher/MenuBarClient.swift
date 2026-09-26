import AppKit
import ApplicationServices
import ComposableArchitecture
import Darwin
import ScreenCaptureKit

struct MenuBarEntry: Equatable, Identifiable {
    let id: UUID
    let applicationName: String
    let title: String
    let icon: NSImage?

    var displayWidth: CGFloat {
        min(max(icon?.size.width ?? 100, 32), 160)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.applicationName == rhs.applicationName && lhs.title == rhs.title
    }
}

struct MenuBarClient {
    enum PressResult {
        case succeeded
        case unconfirmed
        case failed
    }

    var isTrusted: @MainActor () -> Bool
    var requestAccess: @MainActor () -> Void
    var openAccessibilitySettings: @MainActor () -> Bool
    var hasScreenCaptureAccess: @MainActor () -> Bool
    var requestScreenCaptureAccess: @MainActor () -> Void
    var openScreenCaptureSettings: @MainActor () -> Bool
    var scan: @MainActor () async -> [MenuBarEntry]
    var press: @MainActor (UUID) -> PressResult
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
        hasScreenCaptureAccess: { CGPreflightScreenCaptureAccess() },
        requestScreenCaptureAccess: { _ = CGRequestScreenCaptureAccess() },
        openScreenCaptureSettings: {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return false }
            return NSWorkspace.shared.open(url)
        },
        scan: { await MenuBarAccessibility.shared.scan() },
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

    // This Core Graphics function was obsoleted in macOS 15, but still captures
    // status-item windows that ScreenCaptureKit reports as offscreen on macOS 26.
    // Resolve it at runtime so its removal leaves the supported capture path intact.
    private typealias LegacyCapture = @convention(c) (CGRect, CFArray, UInt32) -> Unmanaged<CGImage>?
    private static let legacyCapture: LegacyCapture? = {
        guard let framework = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let symbol = dlsym(framework, "CGWindowListCreateImageFromArray") else { return nil }
        return unsafeBitCast(symbol, to: LegacyCapture.self)
    }()

    func scan() async -> [MenuBarEntry] {
        elements.removeAll()
        guard AXIsProcessTrusted() else { return [] }
        let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false
        )
        let statusWindowLevel = Int(CGWindowLevelForKey(.statusWindow))
        let statusWindows = content?.windows.filter { $0.windowLayer == statusWindowLevel } ?? []

        var entries: [(entry: MenuBarEntry, x: CGFloat?)] = []
        for application in NSWorkspace.shared.runningApplications
        where application.processIdentifier != ProcessInfo.processInfo.processIdentifier
            && application.bundleIdentifier != "com.apple.controlcenter" {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement, 0.25)
            guard let bar = elementAttribute(kAXExtrasMenuBarAttribute as CFString, of: appElement) else { continue }
            let appName = application.localizedName ?? "Unknown application"
            for (index, child) in children(of: bar).enumerated() {
                let actions = actionNames(of: child)
                guard actions.contains(kAXPressAction as String) else { continue }
                let title = nonemptyStringAttribute(kAXTitleAttribute as CFString, of: child)
                    ?? nonemptyStringAttribute(kAXDescriptionAttribute as CFString, of: child)
                    ?? "項目 \(index + 1)"
                let id = UUID()
                elements[id] = child
                let frame = frame(of: child)
                let positionX = frame?.minX
                let window = frame.flatMap { frame in
                    statusWindows.first { window in
                        abs(window.frame.midX - frame.midX) < 4
                            && abs(window.frame.midY - frame.midY) < 4
                            && abs(window.frame.width - frame.width) < 17
                    }
                }
                let icon: NSImage? = if let window { await captureIcon(of: window) } else { nil }
                entries.append((
                    entry: MenuBarEntry(
                        id: id,
                        applicationName: appName,
                        title: title,
                        icon: icon
                    ),
                    x: positionX?.isFinite == true ? positionX : nil
                ))
            }
        }
        // AX positions use global screen coordinates. Preserve discovery order
        // when an item has no position or two items report the same x coordinate.
        return entries.enumerated().sorted { lhs, rhs in
            switch (lhs.element.x, rhs.element.x) {
            case let (left?, right?) where left != right:
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.offset < rhs.offset
            }
        }.map { $0.element.entry }
    }

    func press(_ id: UUID) -> MenuBarClient.PressResult {
        guard let element = elements[id], AXIsProcessTrusted() else { return .failed }
        switch AXUIElementPerformAction(element, kAXPressAction as CFString) {
        case .success:
            return .succeeded
        case .cannotComplete:
            // Opening a menu can block the target app's AX reply until the menu closes.
            // The press may already have worked, so do not report it as a failure.
            return .unconfirmed
        default:
            return .failed
        }
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

    private func nonemptyStringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        guard let value = stringAttribute(attribute, of: element)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size),
              size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: position, size: size)
    }

    private func captureIcon(of window: SCWindow) async -> NSImage? {
        if let image = legacyImage(of: window.windowID) {
            return NSImage(cgImage: image, size: window.frame.size)
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCScreenshotConfiguration()
        configuration.width = Int(window.frame.width * 2)
        configuration.height = Int(window.frame.height * 2)
        do {
            let output: SCScreenshotOutput = try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureScreenshot(contentFilter: filter, configuration: configuration) { output, error in
                    if let output {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "ScreenCaptureKit", code: -1))
                    }
                }
            }
            guard let image = output.sdrImage else { return nil }
            return NSImage(cgImage: image, size: window.frame.size)
        } catch {
            return nil
        }
    }

    private func legacyImage(of windowID: CGWindowID) -> CGImage? {
        guard let capture = Self.legacyCapture else { return nil }
        var windowPointer = UnsafeRawPointer(bitPattern: UInt(windowID))
        guard let windows = withUnsafeMutablePointer(to: &windowPointer, {
            CFArrayCreate(kCFAllocatorDefault, $0, 1, nil)
        }) else { return nil }
        let options = CGWindowImageOption.boundsIgnoreFraming.rawValue
            | CGWindowImageOption.bestResolution.rawValue
        return capture(.null, windows, options)?.takeRetainedValue()
    }
}
