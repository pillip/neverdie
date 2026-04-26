# Review Notes: ISSUE-030 -- Fix Launch at Login silently failing and not reflecting external state changes

**PR**: #58 (`issue/ISSUE-030-fix-launch-at-login` vs `main`)
**Reviewer**: Claude Code (automated)
**Date**: 2026-04-27
**Files changed**: 4 (PopoverView.swift, Protocols.swift, LaunchAtLoginTests.swift, project.pbxproj)
**Confidence**: High

---

## Code Review

### Summary

This PR fixes two bugs in the "Launch at Login" functionality:
1. **Silent failure**: The catch block in `toggleLaunchAtLogin()` was empty (`// silently fail`), violating FR-004 which requires error feedback to the user. Now logs via `os.Logger` at `.error` level and presents an NSAlert.
2. **Stale state**: `@State launchAtLogin` was only evaluated once at view initialization, never reflecting external state changes. Now `.onAppear` re-syncs from `SMAppService.mainApp.status` on every popover open.

Additionally introduces `LoginItemManaging` protocol and `SystemLoginItemManager` for dependency injection, enabling unit testing of the toggle logic.

### Findings

| # | Severity | Finding | Resolution |
|---|----------|---------|------------|
| F-001 | Medium | `os.Logger` string interpolation redacts non-public arguments by default. `error.localizedDescription` would be invisible in production Console.app logs. | Fixed: added `privacy: .public` to the interpolation. |
| F-002 | Low | `@State private var launchAtLogin: Bool = false` initializes to `false` instead of querying status. Brief flash possible before `.onAppear` fires. | Accepted: View is created fresh each popover open; `.onAppear` fires immediately. Flash is imperceptible. Tradeoff is necessary for protocol-based testability. |
| F-003 | Info | `alert.runModal()` is a blocking call. In a popover context, acceptable since the popover pauses interaction during the modal. Called from SwiftUI's main-thread event handler, so thread safety is satisfied. | No action needed. |
| F-004 | Info | `LoginItemManaging` protocol and `onLoginItemError` callback pattern enable proper testability without needing to present a real NSAlert in tests. Good design. | No action needed. |

### Changes Applied During Review
1. Added `privacy: .public` to `os.Logger` error interpolation (F-001).

### Architecture Conformance
- Follows existing protocol-based DI pattern (same as `SleepManaging`, `ProcessMonitoring`, etc.)
- `LoginItemStatus` enum mirrors only the relevant `SMAppService.Status` cases
- `SystemLoginItemManager` is a simple wrapper with no state -- appropriate for a struct
- `onLoginItemError` callback is optional, defaulting to NSAlert -- backward compatible

### Test Coverage Assessment
**New tests**: 12 in `LaunchAtLoginTests.swift`
- Register success sets status to .enabled
- Unregister success sets status to .notRegistered
- Register failure preserves .notRegistered status
- Error callback invoked with correct error
- Unregister not called when status is notRegistered
- Unregister failure preserves .enabled status
- onAppear syncs enabled state correctly
- onAppear syncs notRegistered state correctly
- requiresApproval treated as not-enabled
- Full toggle cycle (OFF -> ON -> OFF)
- ControlPopoverView error callback receives error
- SystemLoginItemManager returns valid status

**AC coverage**:
- AC-1 (register success): Covered by testRegister_succeeds_statusBecomesEnabled, testFullToggleCycle
- AC-2 (register failure + NSAlert): Covered by testRegister_throws_statusRemainsNotRegistered, testToggle_registerThrows_errorCallbackInvoked
- AC-3 (unregister success): Covered by testUnregister_succeeds_statusBecomesNotRegistered, testFullToggleCycle
- AC-4 (onAppear re-sync): Covered by testOnAppear_syncWithCurrentStatus_enabled, testOnAppear_syncWithCurrentStatus_notRegistered, testOnAppear_requiresApproval_treatedAsNotEnabled
- AC-5 (Logger error): Covered implicitly -- the Logger call is in the production code path that is exercised by the error tests. Direct Logger output verification requires os_log capture which is not practical in unit tests.

---

## Security Findings

### [S-001] No new attack surface (Info)
No new IPC, network calls, file I/O, or user input handling. All strings use `NSLocalizedString`.

### [S-002] No secrets or credentials (Info)
No API keys, tokens, or passwords in the changeset.

---

## UI Review

- `.onAppear` correctly re-syncs on every popover open (addresses the stale-state bug)
- NSAlert uses `.warning` style -- appropriate for non-destructive operation failure
- `NSLocalizedString` used for both alert title and button
- `.requiresApproval` documented in code comment as specified
- No VoiceOver regression -- the popover structure is unchanged

---

## Overall Assessment

**Verdict**: Approve

The PR addresses both bugs cleanly: silent failure and stale state. The protocol extraction is a net positive for testability and follows the established DI patterns in the codebase. All 12 new tests pass. No regressions in existing tests. The only review fix was adding `privacy: .public` to the Logger interpolation.
