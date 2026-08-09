//
//  LaunchAtLoginManager.swift
//  ClipboardHistory
//

import Observation
import ServiceManagement

@Observable
@MainActor
final class LaunchAtLoginManager {

    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?

    @ObservationIgnored
    private let service = SMAppService.mainApp

    init() {
        status = SMAppService.mainApp.status
    }

    var isRequested: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    func setEnabled(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try service.register()
            } else {
                try service.unregister()
            }

            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    func refresh() {
        status = service.status
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func clearError() {
        errorMessage = nil
    }
}
