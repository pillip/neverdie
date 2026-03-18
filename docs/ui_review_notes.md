# UI Review Notes: ISSUE-023 -- Per-session token breakdown in popover

## State Coverage
- **No token data (nil)**: "Token data unavailable" text -- PASS
- **1 session**: Single aggregate TokenBarsSection -- PASS
- **2+ sessions**: PerSessionTokenView with DisclosureGroup -- PASS
- **3+ sessions**: ScrollView with maxHeight 400pt -- PASS
- **First session**: Expanded by default (index == 0) -- PASS
- **Other sessions**: Collapsed by default -- PASS

## Copy Compliance
- Session labels show working directory or PID as fallback
- "Token data unavailable" fallback text consistent with existing design
- No new localization strings needed

## Token Usage
- System fonts: 11pt medium for session labels, consistent with existing design
- Dividers between sessions for visual separation
- Padding: 12pt outer, 4pt inner spacing -- consistent

## Accessibility
- DisclosureGroup accessibilityLabel: "Session: {label}"
- Individual bars inherit existing accessibilityElement/accessibilityLabel from TokenBarView
- lineLimit(1) with truncationMode(.middle) for long directory paths -- accessible

## Interaction Fidelity
- DisclosureGroup expand/collapse is read-only (.constant binding)
- ScrollView allows natural scrolling for many sessions
- Popover width fixed at 240pt, consistent with existing design

## Findings
- No Critical or High severity findings.
