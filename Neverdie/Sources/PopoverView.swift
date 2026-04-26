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
    var onLoginItemError: ((Error) -> Void)?

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
            launchAtLogin = loginItemManager.status == .enabled
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
        do {
            if loginItemManager.status == .enabled {
                try loginItemManager.unregister()
                launchAtLogin = false
            } else {
                // Note: LoginItemStatus.requiresApproval means macOS is waiting
                // for the user to approve in System Settings > Login Items.
                // This state should not be treated as an error.
                try loginItemManager.register()
                launchAtLogin = true
            }
        } catch {
            Logger.lifecycle.error("SMAppService failed: \(error.localizedDescription)")
            if let handler = onLoginItemError {
                handler(error)
            } else {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString(
                    "Could not enable Launch at Login",
                    comment: "Alert title when SMAppService registration fails"
                )
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert dismiss button"))
                alert.runModal()
            }
        }
    }
}
