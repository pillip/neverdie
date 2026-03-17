# Review Notes: ISSUE-006 -- Dropdown Menu

## Code Review

### Findings
- **Clean**: Right-click/left-click separation via NSApp.currentEvent type check is correct
- **Clean**: Menu cleared after display (statusItem.menu = nil) prevents left-click regression
- **Clean**: buildMenu() is self-contained and easily extensible for ISSUE-016
- **Clean**: Quit handler calls cleanup before terminate in correct order
- **Low**: performClick(nil) approach for showing menu is a known AppKit pattern, acceptable for MVP

### Changes Made
None required.

### Follow-ups
- ISSUE-016 will add "Launch at Login" toggle to buildMenu()
- ISSUE-017 will add error state display to the menu status line

## Security Findings

### Severity: None
- No network calls, no user input, no secrets
- Pure UI menu construction with NSMenu

## UI Review
- State coverage: ON/OFF states correctly reflected in menu status line
- Copy: "Neverdie: ON/OFF" and "Quit Neverdie" follow macOS conventions
- Accessibility: Native NSMenu is fully VoiceOver-accessible
- Keyboard shortcut: Cmd+Q for Quit follows platform convention
