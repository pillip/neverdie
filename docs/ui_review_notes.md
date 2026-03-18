# UI Review Notes: ISSUE-017 -- Error State Handling

## State Coverage
- **No error**: Normal icon display (ON/OFF states unchanged)
- **Error active**: Red dot overlay on icon, error text in menu
- **Error + toggle success**: Error clears, icon returns to normal
- **Error pulse**: 2 pulses (alpha toggle 0.7/1.0) then solid at 1.0

## Copy Compliance
- Menu error text: "Neverdie: Error -- could not prevent sleep" matches AC exactly
- VoiceOver label: "Neverdie error" matches AC
- VoiceOver announcement: "Neverdie error: could not prevent sleep"
- Normal state text preserved: "Neverdie: ON/OFF"

## Accessibility
- Error state announced via VoiceOver when icon focused
- Error state reflected in accessibility label
- Pulse animation respects VoiceOver context (alpha changes don't affect screen reader)
- Menu error status is a disabled NSMenuItem (read-only, appropriate for status display)

## Interaction Fidelity
- Red dot 4pt size visible at both resolutions
- NSColor.systemRed adapts to light/dark mode
- Pulse timing (0.3s intervals) is perceptible but not jarring

## Findings
- No Critical or High severity findings
