import ComposableArchitecture
import ServiceManagement

enum OpenAtLoginStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isRegistered: Bool {
        self == .enabled || self == .requiresApproval
    }
}

struct OpenAtLoginClient {
    var status: @MainActor () -> OpenAtLoginStatus
    var setEnabled: @MainActor (Bool) throws -> OpenAtLoginStatus
}

extension OpenAtLoginClient: DependencyKey {
    static let liveValue = Self(
        status: { SMAppService.mainApp.openAtLoginStatus },
        setEnabled: { enabled in
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return service.openAtLoginStatus
        }
    )
}

extension DependencyValues {
    var openAtLoginClient: OpenAtLoginClient {
        get { self[OpenAtLoginClient.self] }
        set { self[OpenAtLoginClient.self] = newValue }
    }
}

private extension SMAppService {
    var openAtLoginStatus: OpenAtLoginStatus {
        switch status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .unavailable
        @unknown default: .unavailable
        }
    }
}
