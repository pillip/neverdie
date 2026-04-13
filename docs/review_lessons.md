# Review Lessons

Preventable patterns identified during code reviews. Each entry describes a pattern that could have been caught earlier in the development process.

---

## [RL-001] Reactive UI not wired to new state properties

- **Category**: Architecture
- **Pattern**: When a new observable state property is added to the ViewModel (e.g., `isPausedDueToClamshell`), all UI consumers that should react to it must be updated. StatusBarController was updated to *read* the new property in its existing methods but was not wired to *reactively call* those methods when the property changes via non-user-initiated events (IOKit callbacks).
- **Prevention**: During implementation kickoff, enumerate all UI touch points that display or announce state. For each new state property, verify that every consumer has both (a) rendering logic for the new value and (b) a trigger mechanism to re-render when it changes.
- **Frequency**: 1
- **Observed-In**: ISSUE-024

## [RL-002] Snapshot-based SwiftUI views in imperative hosts

- **Category**: Architecture
- **Pattern**: When SwiftUI views are hosted inside imperative code (NSPopover via NSHostingController), passing state as constructor parameters creates snapshot semantics -- the view does not update when the source state changes. This is fine for transient views but becomes a bug if the view is expected to be long-lived or if state changes can occur while the view is visible.
- **Prevention**: Document in architecture decisions whether popover content uses snapshot or reactive binding. For reactive needs, pass an `@Observable` object or use `@Binding`.
- **Frequency**: 1
- **Observed-In**: ISSUE-024
