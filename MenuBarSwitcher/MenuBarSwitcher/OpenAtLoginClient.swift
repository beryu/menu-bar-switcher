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

extension OpenAtLoginClient {
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

private extension SMAppService {
    var openAtLoginStatus: OpenAtLoginStatus {
        switch status {
        case .notRegistered: .disabled
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        // A service that has never been registered can report .notFound.
        // Registration is still possible from this state.
        case .notFound: .disabled
        @unknown default: .unavailable
        }
    }
}
