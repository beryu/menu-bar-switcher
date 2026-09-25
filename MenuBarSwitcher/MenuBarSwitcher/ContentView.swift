import AppKit
import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isLoading {
                ProgressView("項目を探しています…")
            } else if !store.hasAccessibilityAccess {
                Text("ほかのアプリの項目を見つけて操作するために、アクセシビリティへのアクセスが必要です。")
                HStack {
                    Button("アクセスを要求") { store.send(.accessTapped) }
                    Button("システム設定を開く") { store.send(.settingsTapped) }
                }
                Text("システム設定 → プライバシーとセキュリティ → アクセシビリティで許可します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !store.hasScreenCaptureAccess {
                Text("メニューバーの実際のアイコンを表示するために、画面収録へのアクセスが必要です。撮影するのは検出した項目の小さな領域だけです。")
                HStack {
                    Button("アクセスを要求") { store.send(.screenCaptureAccessTapped) }
                    Button("システム設定を開く") { store.send(.screenCaptureSettingsTapped) }
                }
                Text("システム設定 → プライバシーとセキュリティ → 画面収録とシステムオーディオ録音で許可します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if store.entries.isEmpty {
                Text("操作できる項目が見つかりません。")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(store.entries) { entry in
                            Button {
                                store.send(.entryTapped(entry.id))
                            } label: {
                                Group {
                                    if let icon = entry.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .scaledToFit()
                                    } else {
                                        Image(systemName: "questionmark.square.dashed")
                                            .resizable()
                                            .scaledToFit()
                                    }
                                }
                                .frame(width: min(max(entry.icon?.size.width ?? 24, 24), 80), height: 26)
                                .frame(width: min(max(entry.icon?.size.width ?? 32, 32), 80), height: 28)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help("\(entry.applicationName): \(entry.title)")
                            .accessibilityLabel("\(entry.applicationName)、\(entry.title)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let message = store.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }

            if store.showsQuitAction {
                Divider()
                Toggle("Open at Login", isOn: Binding(
                    get: { store.openAtLoginStatus?.isRegistered ?? false },
                    set: { store.send(.openAtLoginToggled($0)) }
                ))
                .toggleStyle(.checkbox)
                .disabled(store.openAtLoginStatus == nil || store.openAtLoginStatus == .unavailable || store.isUpdatingOpenAtLogin)
                if store.openAtLoginStatus == .requiresApproval {
                    Text("システム設定の「ログイン項目と機能拡張」で許可してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if store.openAtLoginStatus == .unavailable {
                    Text("ログイン項目の状態を取得できませんでした。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("MenuBarSwitcher を終了") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(8)
        .frame(width: popupWidth)
        .onAppear {
            store.send(.appeared(optionPressed: NSEvent.modifierFlags.contains(.option)))
        }
    }

    private var popupWidth: CGFloat {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        let screenWidth = screen?.frame.width ?? 420

        guard store.hasAccessibilityAccess, store.hasScreenCaptureAccess, !store.entries.isEmpty else {
            return min(420, screenWidth)
        }
        let iconWidth = store.entries.reduce(CGFloat.zero) { width, entry in
            width + min(max(entry.icon?.size.width ?? 32, 32), 80)
        }
        let spacing = CGFloat(store.entries.count - 1) * 8
        return min(iconWidth + spacing + 16, screenWidth)
    }
}
