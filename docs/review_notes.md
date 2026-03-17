# Review Notes: ISSUE-012 -- Auto-OFF Wiring

## Code Review

### Findings
- **Clean**: ProcessMonitor properly injected into AppState via AppDelegate
- **Clean**: Auto-OFF state machine logic already in AppState (from ISSUE-002) -- this issue wires the real ProcessMonitor
- **Clean**: Weak self in polling callback prevents retain cycles
- **Clean**: Deactivation resets all tracking state

### Changes Made
None required.

### Follow-ups
- Phase 3 (Intelligence) is now complete

## Security Findings

### Severity: None
- Process enumeration is read-only
- No privilege escalation or network calls
