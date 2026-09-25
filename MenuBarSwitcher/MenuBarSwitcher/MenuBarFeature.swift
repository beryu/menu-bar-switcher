import Foundation
import ComposableArchitecture

struct MenuBarFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var hasAccessibilityAccess = false
        var isLoading = false
        var entries: [MenuBarEntry] = []
        var message: String?
        var showsQuitAction = false
        var openAtLoginStatus: OpenAtLoginStatus?
        var isUpdatingOpenAtLogin = false
    }

    enum Action {
        case appeared(optionPressed: Bool)
        case openAtLoginStatusLoaded(OpenAtLoginStatus)
        case openAtLoginToggled(Bool)
        case openAtLoginUpdateFinished(OpenAtLoginStatus, String?)
        case accessTapped
        case settingsTapped
        case settingsOpened(Bool)
        case entryTapped(UUID)
        case loaded(hasAccess: Bool, entries: [MenuBarEntry])
        case pressFinished(Bool)
    }

    @Dependency(\.menuBarClient) var menuBarClient
    @Dependency(\.openAtLoginClient) var openAtLoginClient

    var body: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            switch action {
            case let .appeared(optionPressed):
                state.showsQuitAction = optionPressed
                state.openAtLoginStatus = nil
                state.isLoading = true
                state.message = nil
                let client = menuBarClient
                let scan = Effect<Action>.run { send in
                    let hasAccess = await client.isTrusted()
                    let entries = hasAccess ? await client.scan() : []
                    await send(.loaded(hasAccess: hasAccess, entries: entries))
                }
                guard optionPressed else { return scan }
                let loginClient = openAtLoginClient
                return .merge(scan, .run { send in
                    await send(.openAtLoginStatusLoaded(await loginClient.status()))
                })

            case let .openAtLoginStatusLoaded(status):
                if state.showsQuitAction {
                    state.openAtLoginStatus = status
                }
                return .none

            case let .openAtLoginToggled(enabled):
                guard state.showsQuitAction, state.openAtLoginStatus != nil,
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
                if let error {
                    state.message = "ログイン時に開く設定を変更できませんでした: \(error)"
                }
                return .none

            case let .loaded(hasAccess, entries):
                state.isLoading = false
                state.hasAccessibilityAccess = hasAccess
                state.entries = entries
                return .none

            case .accessTapped:
                state.message = "システム設定でアクセシビリティを許可した後、⋯を開き直してください。"
                let client = menuBarClient
                return .run { _ in await client.requestAccess() }

            case .settingsTapped:
                let client = menuBarClient
                return .run { send in
                    let opened = await client.openAccessibilitySettings()
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
