# MenuBarSwitcher

MenuBarSwitcher is a macOS prototype that adds a “⋯” item to the menu bar. It lists menu bar items from other apps that are exposed through the Accessibility API and lets you select them. The app manages its state and actions with The Composable Architecture (TCA).

## What it currently does

- Clicking “⋯” shows detected items in a horizontal row, excluding Control Center. Items with an Accessibility position are ordered from left to right, matching their positions in the menu bar; items without a position follow in discovery order. The app captures each original icon from the corresponding status item window. Items that are not visible on screen are also candidates for capture. The window expands to fit the items, up to the width of the active display. It aligns with the right edge of that display and scrolls horizontally if the items do not fit. Hover over an item to see its name and app, or use VoiceOver to hear them.
- The popover follows the menu bar item's appearance when it opens, so white menu bar icons remain visible over a dark popover even when the system uses Light mode.
- Selecting an item sends `AXPress` to that item's Accessibility element. If the item supports the action, its app opens the menu at the item's original position.
- If Accessibility or Screen Recording permission is missing, the app explains why it needs access and how to enable it. Open “⋯” again after granting access to rescan. If no permission dialog appears, use the button that opens System Settings to go directly to the relevant settings.
- Buttons support Tab and Space or Return. VoiceOver labels include the app and item names.
- Option-clicking “⋯” shows a native macOS menu with “Open at Login” and “Quit MenuBarSwitcher” instead of the item list.
- “Open at Login” toggles automatic launch at login. If macOS is waiting for approval, allow the app in System Settings → General → Login Items & Extensions.

## Limitations

Public APIs cannot physically move another app's status item into “⋯” or hide it from the original menu bar. This version therefore does not reduce the space used by menu bar items. It does not recreate their menus; it sends actions to the original items.

An item may be absent from the list or fail to respond if it is missing from the Accessibility hierarchy, does not expose `AXPress`, or its app is unresponsive. In those cases, use the original item directly. Whether an item hidden by the notch remains in the Accessibility hierarchy depends on the app and macOS state. With an automatically hidden menu bar, an external display, or multiple displays, the app still shows only items returned by the public APIs.

When `AXPress` times out, macOS cannot confirm whether the menu opened. The app does not show a failure message for that ambiguous result; if no menu appears, use the original item directly.

The left-to-right order is based on reported screen coordinates. When multiple displays have menu bars, items from different displays can be interleaved by their global horizontal positions; there is no single native order across displays. Items without a reported position cannot be placed exactly.

Public APIs do not expose the `NSImage` another app assigns to a status item. To capture images from hidden windows, the app looks up `CGWindowListCreateImageFromArray` at runtime, even though Apple deprecated it in macOS 15. On a physical Mac running macOS 26.6.2, it captured icons for all 15 visible and 14 hidden items tested. If a future macOS release removes the function, or an individual capture fails, the app tries ScreenCaptureKit. If that also fails, it shows the item's Accessibility name instead of substituting the app icon. If the item has no exposed name, it shows a number within that app's items.

The reported order after this change, selecting items through the app, VoiceOver, guidance after denying permission, and interaction across display configurations have not yet been verified on a physical Mac.

## Run

Open `MenuBarSwitcher/MenuBarSwitcher.xcodeproj` in Xcode and run the macOS target. Request access from “⋯”, then grant the app permission in System Settings → Privacy & Security → Accessibility and Screen & System Audio Recording. If no dialog appears, use the button that opens System Settings. After granting access, restart the app and open “⋯” again. If an earlier build is running, quit it before rebuilding and launching the updated app. The in-app permission prompts are currently in Japanese.

App Sandbox is disabled because the app accesses Accessibility elements belonging to other apps. This configuration is not suitable for Mac App Store distribution.

API references: [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem), [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h), [kAXPositionAttribute](https://developer.apple.com/documentation/applicationservices/kaxpositionattribute), [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions), [CGWindowListCreateImageFromArray](https://developer.apple.com/documentation/coregraphics/1454852-cgwindowlistcreateimagefromarray), [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent), and [SCScreenshotManager](https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager).

The approach to capturing images of hidden items was informed by the public implementation in [Lloyd](https://github.com/benwbooth/lloyd) (MIT License).
