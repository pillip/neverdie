import SwiftUI

/// SwiftUI view displayed inside the hover popover.
///
/// Shows process count and token usage bar graphs.
/// When token data is unavailable, displays "Token data unavailable".
struct PopoverView: View {
    let processCount: Int
    let tokenUsage: TokenUsage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sessionText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .accessibilityLabel(sessionText)

            Divider()

            if let usage = tokenUsage {
                TokenBarsSection(usage: usage)
            } else {
                Text("Token data unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Token data unavailable")
            }
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

/// Section displaying three token usage bar graphs.
struct TokenBarsSection: View {
    let usage: TokenUsage

    /// Maximum value for bar proportion calculation.
    /// Uses the largest of the three values, or a minimum of 1 to avoid division by zero.
    private var maxValue: Int {
        max(max(usage.context, max(usage.input, usage.output)), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TokenBarView(label: "Context", value: usage.context, maxValue: maxValue)
            TokenBarView(label: "Input", value: usage.input, maxValue: maxValue)
            TokenBarView(label: "Output", value: usage.output, maxValue: maxValue)
        }
    }
}

/// A single horizontal bar graph showing a token usage metric.
struct TokenBarView: View {
    let label: String
    let value: Int
    let maxValue: Int

    /// Proportion of bar fill (0.0 to 1.0).
    private var fillProportion: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(TokenFormatter.format(value))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 4)

                    // Fill bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: max(geometry.size.width * fillProportion, 0), height: 4)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(TokenFormatter.format(value)) tokens")
    }
}

/// Formats token counts into abbreviated strings.
///
/// - Less than 1000: exact number (e.g., "999")
/// - 1000 to 999999: "X.XK" format (e.g., "45.2K")
/// - 1000000+: "X.XM" format (e.g., "1.2M")
enum TokenFormatter {
    /// Format a token count into an abbreviated string.
    /// - Parameter value: The token count to format.
    /// - Returns: A formatted string (e.g., "45.2K", "1.2M", "999").
    static func format(_ value: Int) -> String {
        if value < 1000 {
            return "\(value)"
        } else if value < 1_000_000 {
            let k = Double(value) / 1000.0
            if k >= 100 {
                return "\(Int(k))K"
            }
            let formatted = String(format: "%.1f", k)
            // Remove trailing .0
            if formatted.hasSuffix(".0") {
                return "\(Int(k))K"
            }
            return "\(formatted)K"
        } else {
            let m = Double(value) / 1_000_000.0
            let formatted = String(format: "%.1f", m)
            if formatted.hasSuffix(".0") {
                return "\(Int(m))M"
            }
            return "\(formatted)M"
        }
    }
}
