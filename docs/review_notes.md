# Review Notes: ISSUE-002 -- AppState ViewModel

## Code Review

### Findings
- **Clean**: @Observable macro used correctly for SwiftUI state management.
- **Clean**: Protocols well-defined with clear separation of concerns.
- **Clean**: Debounce uses Date comparison (simple, correct for 300ms threshold).
- **Clean**: Auto-OFF state machine guards against false triggers with claudeProcessesEverDetected.
- **Clean**: DI via init parameters enables full testability.
- **Low**: TokenMonitoring.readPerSessionUsage() returns array -- could be empty array vs nil. Acceptable as-is.
- **Clean**: cleanup() is idempotent.

### Changes Made
None required.

### Follow-ups
- None

## Security Findings

### Severity: None
- No external input handling, no network calls.
- Protocol-based DI prevents tight coupling to system APIs.
- No hardcoded secrets or credentials.
