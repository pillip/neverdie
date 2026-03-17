# UI Review Notes -- ISSUE-006 Dropdown Menu

## State Coverage
- **ON state**: Menu shows "Neverdie: ON" -- correct
- **OFF state**: Menu shows "Neverdie: OFF" -- correct
- **Error state**: Not applicable (ISSUE-017 scope)
- **Empty state**: N/A -- menu always has content
- **Loading state**: N/A -- menu builds synchronously

## Copy Compliance
- "Neverdie: ON/OFF" status line matches UX spec
- "Quit Neverdie" label is clear and standard macOS convention
- Keyboard shortcut "q" (Cmd+Q) follows macOS conventions

## Accessibility
- Menu items use native NSMenu which is fully accessible by default
- Status item is disabled (isEnabled=false) so VoiceOver correctly identifies it as informational
- Quit item has proper target-action wiring

## Interaction Fidelity
- Left-click: toggles mode (no regression from ISSUE-005)
- Right-click: shows context menu with status and Quit
- Menu cleared after display to restore left-click behavior
- No popover interaction (not in scope)

## Findings
- **Severity: Low** -- The `statusItem.button?.performClick(nil)` approach for showing menu is a known AppKit pattern but can occasionally cause visual glitch if the menu dismisses too quickly. Acceptable for MVP.
- No Critical or High severity findings.
