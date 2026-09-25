import Foundation
import ComposableArchitecture

struct MenuBarFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var hasAccessibilityAccess = false
        var isLoading = false
        var entries: [MenuBarEntry] = []
        var message: String?
    }

    enum Action {
        case appeared
        case refreshTapped
        case accessTapped
        case settingsTapped
        case settingsOpened(Bool)
        case entryTapped(UUID)
        case loaded(hasAccess: Bool, entries: [MenuBarEntry])
        case pressFinished(Bool)
    }

    @Dependency(\.menuBarClient) var menuBarClient

    var body: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            switch action {
            case .appeared, .refreshTapped:
                state.isLoading = true
                state.message = nil
                let client = menuBarClient
                return .run { send in
                    let hasAccess = await client.isTrusted()
                    let entries = hasAccess ? await client.scan() : []
                    await send(.loaded(hasAccess: hasAccess, entries: entries))
                }

            case let .loaded(hasAccess, entries):
                state.isLoading = false
                state.hasAccessibilityAccess = hasAccess
                state.entries = entries
                return .none

            case .accessTapped:
                state.message = "システム設定でアクセシビリティを許可した後、更新してください。"
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
                    state.message = "システム設定を開けませんでした。手動でプライバシーとセキュリティ → アクセシビリティを開いてください。"
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
