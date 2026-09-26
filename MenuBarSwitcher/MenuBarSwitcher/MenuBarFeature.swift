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
        var lastTappedEntry: MenuBarEntry?
    }

    enum Action {
        case appeared
        case accessTapped
        case screenCaptureAccessTapped
        case settingsTapped
        case screenCaptureSettingsTapped
        case settingsOpened(Bool)
        case entryTapped(UUID)
        case loaded(hasAccess: Bool, hasScreenCaptureAccess: Bool, entries: [MenuBarEntry])
        case pressFinished(MenuBarClient.PressResult)
    }

    @Dependency(\.menuBarClient) var menuBarClient

    var body: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
            switch action {
            case .appeared:
                state.isLoading = true
                state.message = nil
                state.lastTappedEntry = nil
                let client = menuBarClient
                return .run { send in
                    let hasAccess = await client.isTrusted()
                    let hasScreenCaptureAccess = await client.hasScreenCaptureAccess()
                    let entries = hasAccess && hasScreenCaptureAccess ? await client.scan() : []
                    await send(.loaded(hasAccess: hasAccess, hasScreenCaptureAccess: hasScreenCaptureAccess, entries: entries))
                }

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
                guard let entry = state.entries.first(where: { $0.id == id }) else { return .none }
                state.lastTappedEntry = entry
                state.message = nil
                let client = menuBarClient
                return .run { send in
                    let result = await client.press(id)
                    await send(.pressFinished(result))
                }

            case let .pressFinished(result):
                switch result {
                case .succeeded, .unconfirmed:
                    state.message = nil
                    state.lastTappedEntry = nil
                case .failed:
                    if let entry = state.lastTappedEntry {
                        state.message = "\(entry.applicationName)の「\(entry.title)」を操作できませんでした。元のメニューバーから操作してください。"
                    }
                }
                return .none
            }
        }
    }
}
