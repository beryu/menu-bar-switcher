import Foundation
import ComposableArchitecture

struct MenuBarFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var hasAccessibilityAccess = false
        var hasScreenCaptureAccess = false
        var isLoading = false
        var entries: [MenuBarEntry] = []
        var message: String?
        var openAtLoginStatus: OpenAtLoginStatus?
        var isUpdatingOpenAtLogin = false
    }

    enum Action {
        case appeared
        case openAtLoginStatusLoaded(OpenAtLoginStatus)
        case openAtLoginToggled(Bool)
        case openAtLoginUpdateFinished(OpenAtLoginStatus, String?)
        case accessTapped
        case screenCaptureAccessTapped
        case settingsTapped
        case screenCaptureSettingsTapped
        case settingsOpened(Bool)
        case entryTapped(UUID)
        case loaded(hasAccess: Bool, hasScreenCaptureAccess: Bool, entries: [MenuBarEntry])
        case pressFinished(Bool)
    }

    @Dependency(\.menuBarClient) var menuBarClient
    @Dependency(\.openAtLoginClient) var openAtLoginClient

    var body: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            switch action {
            case .appeared:
                state.isLoading = true
                let client = menuBarClient
                return .run { send in
                    let hasAccess = await client.isTrusted()
                    let hasScreenCaptureAccess = await client.hasScreenCaptureAccess()
                    let entries = hasAccess && hasScreenCaptureAccess ? await client.scan() : []
                    await send(.loaded(hasAccess: hasAccess, hasScreenCaptureAccess: hasScreenCaptureAccess, entries: entries))
                }

            case let .openAtLoginStatusLoaded(status):
                state.openAtLoginStatus = status
                return .none

            case let .openAtLoginToggled(enabled):
                guard state.openAtLoginStatus != nil,
                      state.openAtLoginStatus != .unavailable, !state.isUpdatingOpenAtLogin else { return .none }
                state.isUpdatingOpenAtLogin = true
                state.message = nil
                let client = openAtLoginClient
                return .run { send in
                    do {
                        let status = try await client.setEnabled(enabled)
                        await send(.openAtLoginUpdateFinished(status, nil))
                    } catch {
                        let status = await client.status()
                        await send(.openAtLoginUpdateFinished(status, error.localizedDescription))
                    }
                }

            case let .openAtLoginUpdateFinished(status, error):
                state.isUpdatingOpenAtLogin = false
                state.openAtLoginStatus = status
                state.message = error.map { "ログイン時に開く設定を変更できませんでした: \($0)" }
                return .none

            case let .loaded(hasAccess, hasScreenCaptureAccess, entries):
                state.isLoading = false
                state.hasAccessibilityAccess = hasAccess
                state.hasScreenCaptureAccess = hasScreenCaptureAccess
                state.entries = entries
                return .none

            case .accessTapped:
                state.message = "システム設定でアクセシビリティを許可した後、⋯を開き直してください。"
                let client = menuBarClient
                return .run { _ in await client.requestAccess() }

            case .screenCaptureAccessTapped:
                state.message = "画面収録を許可した後、⋯を開き直してください。"
                let client = menuBarClient
                return .run { _ in await client.requestScreenCaptureAccess() }

            case .settingsTapped:
                let client = menuBarClient
                return .run { send in
                    let opened = await client.openAccessibilitySettings()
                    await send(.settingsOpened(opened))
                }

            case .screenCaptureSettingsTapped:
                let client = menuBarClient
                return .run { send in
                    let opened = await client.openScreenCaptureSettings()
                    await send(.settingsOpened(opened))
                }

            case let .settingsOpened(opened):
                if !opened {
                    state.message = "システム設定を開けませんでした。手動でプライバシーとセキュリティを開いてください。"
                }
                return .none

            case let .entryTapped(id):
                guard state.entries.contains(where: { $0.id == id }) else { return .none }
                let client = menuBarClient
                return .run { send in
                    let succeeded = await client.press(id)
                    await send(.pressFinished(succeeded))
                }

            case let .pressFinished(succeeded):
                state.message = succeeded ? nil : "この項目を操作できませんでした。元のメニューバーから操作してください。"
                return .none
            }
        }
    }
}
