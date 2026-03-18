# UI Review Notes -- ISSUE-015 Token Usage Bar Graphs

## State Coverage
- **Data available**: Three bar graphs with labels (Context, Input, Output) and abbreviated values
- **Data unavailable**: "Token data unavailable" fallback text
- **Zero values**: Bars render with zero width, labels show "0"
- **Large values**: Number formatting handles K and M suffixes

## Copy Compliance
- Labels: "Context", "Input", "Output" match architecture spec
- Fallback: "Token data unavailable" matches AC
- Number formatting: "45.2K", "1.2M" format as specified
- Session text preserved from ISSUE-013: "No active sessions" / "N active sessions"

## Accessibility
- Each bar has accessibilityElement(children: .ignore) to prevent VoiceOver reading subviews
- accessibilityLabel on each bar includes label and formatted value with "tokens" suffix
- Fallback text has accessibilityLabel

## Interaction Fidelity
- Token data refreshed before popover content is created (ensures fresh data)
- Bar proportions relative to max value (all bars visible, largest is full width)
- Accent color for fill adapts to system theme

## Findings
- No Critical or High severity findings
