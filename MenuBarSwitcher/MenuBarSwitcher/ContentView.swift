import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<MenuBarFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("メニューバーの項目")
                    .font(.headline)
                Spacer()
                Button("更新", systemImage: "arrow.clockwise") {
                    store.send(.refreshTapped)
                }
                .labelStyle(.iconOnly)
                .help("項目を更新")
            }

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
                                VStack(spacing: 3) {
                                    Text(entry.title).lineLimit(1)
                                    Text(entry.applicationName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(minWidth: 68)
                            }
                            .buttonStyle(.bordered)
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
            Text("項目は元の位置に残ります。押すと元のアプリのメニューが開く場合があります。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 420)
        .onAppear { store.send(.appeared) }
    }
}
