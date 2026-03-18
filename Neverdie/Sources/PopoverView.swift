import SwiftUI

/// SwiftUI view displayed inside the click-based popover.
///
/// Shows a simple ON/OFF toggle for Neverdie mode with status text.
struct ControlPopoverView: View {
    let isActive: Bool
    let hasError: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Status text
            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(statusColor)

            // Toggle button
            Button(action: onToggle) {
                Text(isActive ? "Turn OFF" : "Turn ON")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(isActive ? .red : .green)
            .accessibilityLabel(isActive ? "Turn off sleep prevention" : "Turn on sleep prevention")
        }
        .padding(16)
        .frame(width: 200)
    }

    private var statusText: String {
        if hasError {
            return "Neverdie: Error"
        } else if isActive {
            return "Neverdie: ON"
        } else {
            return "Neverdie: OFF"
        }
    }

    private var statusColor: Color {
        if hasError {
            return .red
        } else if isActive {
            return .green
        } else {
            return .secondary
        }
    }
}
