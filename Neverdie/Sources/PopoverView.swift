import os
import ServiceManagement
import SwiftUI

/// Default `LoginItemManaging` implementation wrapping `SMAppService.mainApp`.
struct SystemLoginItemManager: LoginItemManaging {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        default: return .notRegistered
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

// MARK: - Login Item Toggle Logic

/// Result of a login item toggle attempt.
enum LoginItemToggleResult {
    case registered
    case unregistered
    case failed(wasEnabling: Bool, error: Error)
}

/// Toggle login item registration. Testable pure logic — no UI, no logging.
///
/// - If status is `.enabled`, unregisters. If `.notRegistered` or `.requiresApproval`, registers.
/// - Note: `.requiresApproval` means macOS is waiting for the user to approve
///   in System Settings > Login Items. Calling `register()` in this state is safe
///   and prompts the system to re-check approval.
func performLoginItemToggle(manager: LoginItemManaging) -> LoginItemToggleResult {
    let isCurrentlyEnabled = manager.status == .enabled
    do {
        if isCurrentlyEnabled {
            try manager.unregister()
            return .unregistered
        } else {
            try manager.register()
            return .registered
        }
    } catch {
        return .failed(wasEnabling: !isCurrentlyEnabled, error: error)
    }
}

// MARK: - Login Item Alert

/// Build the NSAlert for a login item toggle failure. Extracted for testability.
/// The caller is responsible for calling `runModal()`.
func makeLoginItemAlert(wasEnabling: Bool, error: Error) -> NSAlert {
    let alert = NSAlert()
    alert.messageText = NSLocalizedString(
        wasEnabling
            ? "Could not enable Launch at Login"
            : "Could not disable Launch at Login",
        comment: "Alert title when SMAppService registration fails"
    )
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert dismiss button"))
    return alert
}

/// SwiftUI view displayed inside the status bar popover.
///
/// Apple-style minimal design with toggle, launch at login, and quit.
struct ControlPopoverView: View {
    let isActive: Bool
    let isPaused: Bool
    let hasError: Bool
    let onToggle: () -> Void
    let onQuit: () -> Void
    var loginItemManager: LoginItemManaging = SystemLoginItemManager()
    var onLoginItemError: ((Bool, Error) -> Void)?

    /// Test hook: called with the synced value when `.onAppear` fires.
    var _testOnSyncLaunchAtLogin: ((Bool) -> Void)?

    @State private var launchAtLogin: Bool = false
    @State private var hoveredRow: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowButton(id: "toggle", action: onToggle) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                Text("Neverdie")
                    .font(.system(size: 13))
                Spacer()
                Text(statusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Divider()
            rowButton(id: "launch", action: toggleLaunchAtLogin) {
                Text("Launch at Login")
                    .font(.system(size: 13))
                Spacer()
                if launchAtLogin {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            rowButton(id: "quit", action: onQuit) {
                Text("Quit Neverdie")
                    .font(.system(size: 13))
                Spacer()
            }
        }
        .frame(width: 220)
        .onAppear {
            let synced = loginItemManager.status == .enabled
            launchAtLogin = synced
            _testOnSyncLaunchAtLogin?(synced)
        }
    }

    private func rowButton<Content: View>(
        id: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack { content() }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(hoveredRow == id ? Color.primary.opacity(0.08) : .clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onHover { isHovered in
                hoveredRow = isHovered ? id : nil
            }
    }

    private var statusLabel: String {
        if isPaused { return "Paused" }
        return isActive ? "ON" : "OFF"
    }

    private var statusDotColor: Color {
        if hasError { return .red }
        if isPaused { return .orange }
        return isActive ? .green : .secondary.opacity(0.5)
    }

    private func toggleLaunchAtLogin() {
        let result = performLoginItemToggle(manager: loginItemManager)
        switch result {
        case .registered:
            launchAtLogin = true
        case .unregistered:
            launchAtLogin = false
        case .failed(let wasEnabling, let error):
            Logger.lifecycle.error("SMAppService failed: \(error.localizedDescription, privacy: .public)")
            if let handler = onLoginItemError {
                handler(wasEnabling, error)
            } else {
                makeLoginItemAlert(wasEnabling: wasEnabling, error: error).runModal()
            }
        }
    }
}
