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
                                HStack(spacing: 6) {
                                    Group {
                                        if let icon = entry.applicationIcon {
                                            Image(nsImage: icon)
                                                .resizable()
                                        } else {
                                            Image(systemName: "app")
                                                .resizable()
                                        }
                                    }
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(entry.title)
                                            .font(.caption)
                                            .lineLimit(1)
                                        Text(entry.applicationName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 6)
                                .frame(width: 150, height: 38)
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

        guard store.hasAccessibilityAccess, !store.entries.isEmpty else {
            return min(420, screenWidth)
        }
        let iconWidth = CGFloat(store.entries.count) * 150
        let spacing = CGFloat(store.entries.count - 1) * 8
        return min(iconWidth + spacing + 16, screenWidth)
    }
}
