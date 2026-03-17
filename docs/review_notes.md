# Review Notes: ISSUE-011 -- ProcessMonitor

## Code Review

### Findings
- **Clean**: Uses libproc APIs (proc_listallpids, proc_name) directly without spawning subprocesses
- **Clean**: Weak self capture in timer closure prevents retain cycles
- **Clean**: deinit calls stopPolling for cleanup
- **Clean**: Timer tolerance set at 10% for energy efficiency
- **Low**: MAXCOMLEN buffer size is correct for proc_name
- **Clean**: Case-insensitive matching with both prefix and contains check

### Changes Made
None required.

### Follow-ups
- ISSUE-012 will wire ProcessMonitor to AppState for auto-OFF

## Security Findings

### Severity: None
- proc_listallpids/proc_name are read-only APIs, no privilege escalation
- No network calls, no file writes
