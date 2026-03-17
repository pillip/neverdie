import SwiftUI

/// SwiftUI view displayed inside the hover popover.
///
/// Shows process count and serves as the container for token usage
/// bars (added in ISSUE-015).
struct PopoverView: View {
    let processCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sessionText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .accessibilityLabel(sessionText)

            Divider()

            Text("Token data will appear here")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 240)
    }

    /// Formatted text for process count display.
    private var sessionText: String {
        switch processCount {
        case 0:
            return "No active sessions"
        case 1:
            return "1 active session"
        default:
            return "\(processCount) active sessions"
        }
    }
}
