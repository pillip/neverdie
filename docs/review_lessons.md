# Review Lessons

Preventable patterns identified during code reviews. Each entry describes a pattern that could have been caught earlier in the development process.

---

## [RL-001] Reactive UI not wired to new state properties

- **Category**: Architecture
- **Pattern**: When a new observable state property is added to the ViewModel (e.g., `isPausedDueToClamshell`), all UI consumers that should react to it must be updated. StatusBarController was updated to *read* the new property in its existing methods but was not wired to *reactively call* those methods when the property changes via non-user-initiated events (IOKit callbacks).
- **Prevention**: During implementation kickoff, enumerate all UI touch points that display or announce state. For each new state property, verify that every consumer has both (a) rendering logic for the new value and (b) a trigger mechanism to re-render when it changes.
- **Frequency**: 2
- **Observed-In**: ISSUE-024, ISSUE-027

## [RL-002] Snapshot-based SwiftUI views in imperative hosts

- **Category**: Architecture
- **Pattern**: When SwiftUI views are hosted inside imperative code (NSPopover via NSHostingController), passing state as constructor parameters creates snapshot semantics -- the view does not update when the source state changes. This is fine for transient views but becomes a bug if the view is expected to be long-lived or if state changes can occur while the view is visible.
- **Prevention**: Document in architecture decisions whether popover content uses snapshot or reactive binding. For reactive needs, pass an `@Observable` object or use `@Binding`.
- **Frequency**: 2
- **Observed-In**: ISSUE-024, ISSUE-027

## [RL-003] TOCTOU in system API buffer allocation patterns

- **Category**: Security
- **Pattern**: When using two-call buffer allocation patterns (first call gets count, second call fills buffer), the count can change between calls. This applies to `proc_listallpids`, `sysctl`, and similar Darwin/POSIX APIs. The standard mitigation is to allocate with a small margin or retry on truncation.
- **Prevention**: During implementation, identify any two-call allocation pattern and document whether truncation is acceptable (e.g., "missed process for one poll cycle is fine") or requires retry logic.
- **Frequency**: 1
- **Observed-In**: ISSUE-027

## [RL-004] Implicit state machine transitions across activation sources

- **Category**: Code Quality
- **Pattern**: When multiple activation sources (manual, auto) share the same deactivation logic, flags set by one source can be triggered by another. For example, `claudeProcessesEverDetected` set during auto-monitoring can cause auto-OFF even after a manual toggle-ON, because the flag persists across activation sources.
- **Prevention**: During kickoff, draw the full state machine including transitions between manual and auto activation. Identify cross-source interactions and document whether they are intended or need guards.
- **Frequency**: 1
- **Observed-In**: ISSUE-027

## [RL-005] @ObservationIgnored applied to computed properties (no-op)

- **Category**: Code Quality
- **Pattern**: When annotating an `@Observable` class with `@ObservationIgnored`, only stored properties need the attribute. Computed properties are not tracked by the `@Observable` macro and the attribute is silently ignored. Applying it to computed properties adds misleading noise that suggests the property would otherwise be tracked.
- **Prevention**: During implementation, review which properties are stored vs computed before applying `@ObservationIgnored`. The macro only synthesizes observation for stored `var` properties.
- **Frequency**: 1
- **Observed-In**: ISSUE-029
