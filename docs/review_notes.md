# Review Notes: ISSUE-014 -- TokenMonitor

## Code Review

### Findings
- **Clean**: Graceful degradation at every level (missing dir, malformed JSON, missing fields)
- **Clean**: Injectable FileManager and base path for testability
- **Clean**: JSONDecoder with optional fields (context/input/output all optional with default 0)
- **Clean**: Aggregate readUsage() delegates to readPerSessionUsage() -- single source of truth
- **Low**: Claude Code file format may change -- designed for flexibility with lenient parsing
- **Clean**: No polling timer, reads on-demand only

### Changes Made
None required.

### Follow-ups
- ISSUE-015 will add token usage bar graphs to the popover
- ISSUE-023 will add per-session breakdown UI

## Security Findings

### Severity: None
- Read-only file system access to ~/.claude/ directory
- No network calls, no user input handling
- FileManager permissions respected (graceful failure on denied access)
