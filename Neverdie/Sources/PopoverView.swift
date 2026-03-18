import ServiceManagement
import SwiftUI

/// SwiftUI view displayed inside the status bar popover.
///
/// Apple-style minimal design with toggle, launch at login, and quit.
struct ControlPopoverView: View {
    let isActive: Bool
    let hasError: Bool
    let onToggle: () -> Void
    let onQuit: () -> Void

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
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
                Text(isActive ? "ON" : "OFF")
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

    private var statusDotColor: Color {
        if hasError { return .red }
        return isActive ? .green : .secondary.opacity(0.5)
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
            } else {
                try SMAppService.mainApp.register()
                launchAtLogin = true
            }
        } catch {
            // silently fail
        }
    }
}
