# Architecture

## Overview

**Architecture style**: Single-process SwiftUI macOS menu bar app (monolith).

**Justification**: Neverdie is a self-contained macOS menu bar utility with no network communication, no backend, and no multi-user concerns. A single-process native app is the only sensible architecture. There is nothing to distribute across services. The entire app fits in one Xcode project with clear module boundaries enforced by Swift's type system and access control.

**Key constraints driving the decision**:
- macOS-only, menu bar-only (LSUIElement)
- No network calls, no server, no database
- Must be lightweight: <=50MB memory, <1% CPU
- Universal Binary (arm64 + x86_64)
- All data is local (IOKit assertions, process table, local files)

**Architecture pattern**: MVVM (Model-View-ViewModel). SwiftUI naturally encourages this. A single `@Observable` (or `@ObservableObject`) AppState acts as the central ViewModel, observed by SwiftUI views. Services are plain Swift classes injected into the AppState.

```
┌─────────────────────────────────────────────────┐
│                  NeverdieApp                     │
│  (App entry point, MenuBarExtra)                │
├─────────────────────────────────────────────────┤
│              AppState (ViewModel)                │
│  - isActive: Bool                               │
│  - activationSource: .manual | .auto            │
│  - processCount: Int                            │
│  - tokenUsage: TokenUsage?                      │
├──────────┬──────────┬───────────┬───────────────┤
│ SleepMgr │ ProcMon  │ TokenMon  │ AnimationMgr  │
│ (IOKit)  │ (sysctl) │ (file IO) │ (NSImage[])   │
└──────────┴──────────┴───────────┴───────────────┘
```

---

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Language | Swift 5.9+ | Required for macOS native, SwiftUI, IOKit interop |
| UI Framework | SwiftUI + AppKit (MenuBarExtra) | macOS 14+ MenuBarExtra API for menu bar apps. AppKit interop for NSStatusItem customization where needed |
| Build system | Xcode 15+ / Swift Package Manager | Standard for macOS app development. SPM for any dependencies |
| Min deployment | macOS 14.0 (Sonoma) | Per NFR-001 |
| Sleep prevention | IOKit (IOPMAssertion C API) | The only correct API for this purpose. Bridged to Swift |
| Process detection | libproc / sysctl | proc_listpids() + proc_name() for lightweight process enumeration without spawning subprocesses |
| Token data | FileManager + JSONDecoder | Local file parsing from ~/.claude/ directory |
| Animation | NSImage array + Timer | Frame-based swap at 4-8fps. Minimal CPU overhead |
| Login item | SMAppService (ServiceManagement) | macOS 13+ API for login items, replaces deprecated SMLoginItemSetEnabled |
| Distribution | Xcode Archive -> .dmg (Homebrew Cask) + App Store | Code signed with Developer ID |

**External dependencies**: None planned. The app uses only Apple system frameworks (SwiftUI, AppKit, IOKit, ServiceManagement). Zero third-party dependencies keeps the binary small and eliminates supply chain risk.

**Version pinning**: Xcode version is pinned via `.xcode-version` file. Swift version is determined by Xcode. No external packages to pin.

---

## Modules

### Module: NeverdieApp (Entry Point)

- **Responsibility**: App lifecycle, MenuBarExtra setup, scene configuration.
- **Dependencies**: AppState, all View modules.
- **Key interfaces**:
  - `@main struct NeverdieApp: App` with `MenuBarExtra` scene.
  - Creates and owns `AppState` as `@State` or `@StateObject`.
  - Registers `applicationWillTerminate` cleanup via `NSApplication.delegate` or `.onDisappear`.

### Module: AppState (ViewModel)

- **Responsibility**: Central state management. Coordinates all services. Single source of truth for UI state.
- **Dependencies**: SleepManager, ProcessMonitor, TokenMonitor, AnimationManager.
- **Key interfaces**:
  ```swift
  @Observable
  final class AppState {
      private(set) var isActive: Bool = false          // Neverdie mode ON/OFF
      private(set) var activationSource: ActivationSource = .manual
      private(set) var processCount: Int = 0
      private(set) var tokenUsage: TokenUsage? = nil
      private(set) var claudeProcessesEverDetected: Bool = false

      func toggle()                    // FR-002: toggle Neverdie mode
      func startMonitoring()           // Begin process + token polling
      func stopMonitoring()            // Stop all polling
      func cleanup()                   // FR-008/FR-009: release assertion, stop timers
  }

  enum ActivationSource { case manual, auto }
  ```
- **State machine for auto-OFF logic (FR-014)**:
  - When `isActive == true` and `processCount > 0`, set `claudeProcessesEverDetected = true`.
  - When `isActive == true` and `claudeProcessesEverDetected == true` and `processCount == 0`, auto-deactivate.
  - When activation was manual and no Claude process was ever detected, do NOT auto-OFF.

### Module: SleepManager

- **Responsibility**: Create and release IOPMAssertions. Wraps IOKit C API in a Swift-friendly interface.
- **Dependencies**: None (IOKit framework only).
- **Key interfaces**:
  ```swift
  final class SleepManager {
      private var assertionID: IOPMAssertionID = kIOPMNullAssertionID

      func preventSleep() -> Bool      // FR-005: create assertion, returns success
      func allowSleep()                // FR-007: release assertion
      var isAssertionHeld: Bool { get } // Check if assertion is currently active
  }
  ```
- **Failure mode**: If `IOPMAssertionCreateWithName` fails (returns non-success), `preventSleep()` returns `false`. AppState should reflect this -- mode stays OFF and logs an error. This is a non-recoverable error (likely a system issue).
- **Cleanup guarantee (FR-008)**: `deinit` calls `allowSleep()`. Additionally, signal handlers (SIGTERM, SIGINT) invoke cleanup. Even if the process is force-killed, IOKit reclaims assertions automatically.

### Module: ProcessMonitor

- **Responsibility**: Periodically poll for running Claude Code processes. Report count.
- **Dependencies**: None (libproc / Darwin APIs only).
- **Key interfaces**:
  ```swift
  final class ProcessMonitor {
      let pollInterval: TimeInterval = 30.0  // FR-013: default 30s

      func startPolling(onUpdate: @escaping (Int) -> Void)
      func stopPolling()
      func pollOnce() -> Int            // Returns count of matching processes
  }
  ```
- **Implementation strategy**:
  1. Use `proc_listallpids()` to get all PIDs.
  2. For each PID, use `proc_name()` to get the process name.
  3. Match against known Claude Code process names: `"claude"`, `"claude-code"`.
  4. Configurable match list to handle risk of process name changes.
- **Why not NSRunningApplication**: `NSRunningApplication.runningApplications` only returns GUI apps (those with a bundle). Claude Code is a CLI process -- it will not appear. `proc_listpids` is the correct API.
- **Why not shell commands**: Spawning `pgrep` or `ps` every 30 seconds creates subprocess overhead and violates FR-013's requirement to avoid shell commands.
- **Polling mechanism**: `Timer.scheduledTimer` on the main run loop. At 30-second intervals, the overhead is negligible (NFR-004).
- **Failure mode**: If proc_listallpids fails, return 0 and log. No crash. Process count shows 0.

### Module: TokenMonitor

- **Responsibility**: Read Claude Code token usage data from local files.
- **Dependencies**: None (FileManager only).
- **Key interfaces**:
  ```swift
  struct TokenUsage {
      let context: Int
      let input: Int
      let output: Int
  }

  struct SessionTokenUsage: Identifiable {
      let id: String          // PID or session identifier
      let label: String       // Working directory or PID
      let usage: TokenUsage
  }

  final class TokenMonitor {
      func readUsage() -> TokenUsage?                   // FR-016: aggregate
      func readPerSessionUsage() -> [SessionTokenUsage] // FR-018: per-session
  }
  ```
- **Data source strategy (highest risk area)**:
  - Primary: Parse files under `~/.claude/` directory. Claude Code stores project data in `~/.claude/projects/` with JSON files containing session information.
  - The exact file format is not guaranteed to be stable. The monitor is designed for graceful degradation.
  - If no data source is found, `readUsage()` returns `nil` and the UI shows "Token data unavailable" (FR-016 acceptance criteria).
- **No polling timer of its own**: Token data is read on-demand when the popover opens, or piggybacks on the ProcessMonitor's 30-second cycle. This avoids unnecessary file I/O.
- **Failure mode**: File not found, parse error, or permission denied all result in `nil` return. Never crashes. Logged at `.info` level (not error -- this is expected in many setups).

### Module: AnimationManager

- **Responsibility**: Manage frame-based animation for the menu bar icon.
- **Dependencies**: None (NSImage / AppKit only).
- **Key interfaces**:
  ```swift
  final class AnimationManager {
      let fps: Double = 6.0             // FR-011: 4-8fps range, 6 is a good middle

      var currentFrame: NSImage { get }
      var staticOffIcon: NSImage { get } // FR-010

      func startAnimation()             // Begin frame cycling
      func stopAnimation()              // Stop, reset to static icon
  }
  ```
- **Implementation**:
  - Animation frames are pre-loaded `NSImage` assets from the asset catalog at app launch.
  - All images are marked as template images (`isTemplate = true`) for automatic light/dark mode support (FR-012).
  - A `Timer` fires at ~6fps (166ms interval), incrementing a frame index.
  - The `NSStatusItem.button?.image` is updated on each tick.
- **Memory**: At 18x18pt @2x, each frame is ~18x18x4x4 = ~5KB. With 8 frames, total is ~40KB. Negligible (NFR-003).
- **Failure mode**: If animation assets are missing (build error), fall back to a system SF Symbol (`"bolt.fill"`).

### Module: PopoverView

- **Responsibility**: Display process count and token usage in a popover.
- **Dependencies**: AppState (read-only observation).
- **Key interfaces**: SwiftUI View displayed in an `NSPopover` anchored to the status item.
- **Hover behavior (Assumption #5 from requirements)**:
  - macOS does not natively support hover on `NSStatusItem`.
  - **Chosen approach**: Use `NSTrackingArea` on the status item button to detect mouse-enter/exit events. On mouse-enter, show an `NSPopover`. On mouse-exit (with delay), dismiss it.
  - **Fallback**: If hover proves unreliable in testing, embed the info directly in the right-click dropdown menu as non-interactive items. This is a lower-risk alternative that satisfies the same user need.
- **Content**:
  - Process count: "{N} active sessions" (FR-015)
  - Token usage: Three horizontal bars with labels (FR-017)
  - Per-session breakdown if multiple sessions (FR-018, Could priority)
- **Accessibility (NFR-007)**: All bar graphs have `accessibilityLabel` and `accessibilityValue`. The popover content is navigable via VoiceOver.

### Module: MenuView

- **Responsibility**: Right-click dropdown menu with Quit and Launch at Login options.
- **Dependencies**: AppState.
- **Key interfaces**: Standard `NSMenu` or SwiftUI `Menu` content.
- **Items**:
  - "Neverdie: ON/OFF" (status display, non-interactive)
  - "Launch at Login" toggle (FR-004)
  - Separator
  - "Quit Neverdie" (FR-003, FR-009)

---

## Data Model

This app has no persistent database. All state is ephemeral (in-memory) or derived from the system.

### Entities

| Entity | Storage | Lifecycle |
|--------|---------|-----------|
| `isActive` (Bool) | In-memory | App runtime only. Defaults to OFF on launch |
| `assertionID` (IOPMAssertionID) | In-memory | Created/released with mode toggle |
| `processCount` (Int) | In-memory | Refreshed every 30 seconds |
| `tokenUsage` (TokenUsage?) | In-memory | Read on-demand from filesystem |
| `launchAtLogin` (Bool) | SMAppService (system-managed) | Persisted by macOS across restarts |

### Persisted State

- **Launch at Login**: Managed by `SMAppService.mainApp.register()` / `unregister()`. The system stores this -- the app queries it at launch.
- **No UserDefaults needed for MVP**: Poll interval is hardcoded. No user preferences UI.

### External Data Sources (read-only)

| Source | Path | Format | Usage |
|--------|------|--------|-------|
| Claude Code session data | `~/.claude/projects/*/` | JSON (schema TBD) | Token usage (FR-016) |
| Process table | Kernel (via libproc) | C API | Process detection (FR-013) |
| IOKit assertions | Kernel (via IOKit) | C API | Sleep prevention (FR-005) |

### Migration Strategy

Not applicable -- no database, no schema. If Claude Code changes its local file format, `TokenMonitor` gracefully degrades. A future version can update the parser without data migration.

---

## API Design

This is a standalone desktop app with no external API. The "APIs" are internal interfaces between modules.

### Internal Interface Contracts

#### AppState Toggle (FR-002)
```
Input:  User click on menu bar icon
Flow:   AppState.toggle()
        -> if activating: SleepManager.preventSleep(), AnimationManager.startAnimation(), ProcessMonitor.startPolling()
        -> if deactivating: SleepManager.allowSleep(), AnimationManager.stopAnimation(), ProcessMonitor.stopPolling()
Output: UI updates via SwiftUI observation
```

#### Process Poll Callback (FR-013, FR-014)
```
Input:  Timer fires every 30 seconds
Flow:   ProcessMonitor.pollOnce() -> count
        -> AppState updates processCount
        -> If count == 0 and claudeProcessesEverDetected: AppState auto-deactivates
Output: processCount published to UI
```

#### Token Data Request (FR-016)
```
Input:  Popover opens (hover or click)
Flow:   TokenMonitor.readUsage() -> TokenUsage?
        -> AppState updates tokenUsage
Output: Popover renders bar graphs or "unavailable" message
```

#### Quit (FR-009)
```
Input:  User selects "Quit Neverdie" from menu
Flow:   AppState.cleanup()
        -> SleepManager.allowSleep()
        -> ProcessMonitor.stopPolling()
        -> AnimationManager.stopAnimation()
        -> NSApplication.shared.terminate(nil)
```

### Interaction Model (FR-002, FR-003)

| Action | Result |
|--------|--------|
| Left-click on icon | Toggle Neverdie mode |
| Right-click on icon | Open dropdown menu |
| Mouse hover on icon | Show popover (process count + token usage) |
| "Quit Neverdie" menu item | Clean shutdown |
| "Launch at Login" toggle | Register/unregister with SMAppService |

---

## Background Jobs

| Job | Trigger | Frequency | Idempotency |
|-----|---------|-----------|-------------|
| Process polling | Timer (when mode is ON) | Every 30 seconds | Yes -- each poll is a fresh snapshot of the process table. No accumulated state |
| Animation frame tick | Timer (when mode is ON) | Every ~166ms (6fps) | Yes -- just sets the next frame index modulo frame count |
| Token data read | On popover open | On-demand | Yes -- reads current file state, no side effects |
| Signal handler cleanup | SIGTERM / SIGINT | Once | Yes -- `allowSleep()` is safe to call multiple times (checks `isAssertionHeld`) |

No persistent background jobs. No cron. No launch agents. All timers stop when mode is OFF.

---

## Observability

### Logging Strategy

- Use Apple's unified logging (`os.Logger`) with subsystem `"com.neverdie.app"`.
- Categories: `sleep`, `process`, `token`, `ui`, `lifecycle`.
- **What to log**:
  - Mode transitions: `"Neverdie mode ON (source: manual)"`, `"Neverdie mode OFF (source: auto, reason: all processes ended)"`
  - Assertion creation/release: `"IOPMAssertion created (ID: %d)"`, `"IOPMAssertion released"`
  - Assertion failure: `"IOPMAssertionCreateWithName failed: %d"` (log level: `.error`)
  - Process poll results: `"Process poll: %d claude processes found"` (log level: `.debug`)
  - Token parse failure: `"Token data unavailable: file not found at %@"` (log level: `.info`)
  - App lifecycle: `"App launched"`, `"App terminating, cleanup complete"`
- **Levels**: `.debug` for routine polling, `.info` for state changes, `.error` for failures.
- Viewable via Console.app with filter `subsystem:com.neverdie.app`.

### Metrics

No telemetry. No analytics. No network calls. The app respects user privacy completely.

For development/debugging, `pmset -g assertions` can verify assertion state externally.

### Alerting

Not applicable -- single-user desktop app. The user is "alerted" by the icon state (animated = ON, static = OFF).

---

## Security

### Auth Scheme

Not applicable -- no server, no user accounts, no network.

### Input Validation

- **Process names**: The app reads process names from the kernel. No user input is involved.
- **Token files**: JSON files from `~/.claude/` are parsed with `JSONDecoder`. Malformed JSON results in `nil` return, not a crash. No user-supplied file paths.
- **No shell commands**: The app never invokes shell commands or spawns subprocesses, eliminating command injection risk.

### Secrets Management

- No API keys, no tokens, no secrets.
- The Developer ID signing certificate is managed via Xcode and Apple Developer Portal (not stored in the repo).

### OWASP Top 10 Mitigations

Most OWASP Top 10 categories are not applicable (no web, no network, no auth). Relevant items:

| Category | Applicability | Mitigation |
|----------|--------------|------------|
| A01 Broken Access Control | N/A | No multi-user, no server |
| A03 Injection | Low risk | No shell commands, no string interpolation into system calls. IOPMAssertion name is a hardcoded string |
| A04 Insecure Design | Low risk | App runs in user space with standard macOS sandbox. IOKit access requires no special entitlements |
| A08 Software and Data Integrity | Medium | Code signed with Developer ID. Homebrew Cask verifies SHA256 hash |
| A09 Security Logging | Covered | Unified logging captures assertion lifecycle events |

### Sandbox and Entitlements

- The app does **not** use App Sandbox for the Homebrew Cask distribution (IOKit access is simpler without sandbox).
- For App Store distribution, sandbox entitlements will be required. IOPMAssertion usage within sandbox needs testing -- this is a known risk (Risk table in requirements).
- Hardened Runtime is enabled for notarization.

---

## Deployment and Rollback

### Build Pipeline

```
1. Xcode Build (Release configuration)
   - Target: macOS 14.0+
   - Architecture: Universal (arm64 + x86_64)
   - Hardened Runtime: ON
   - Code Sign: Developer ID Application

2. Archive + Export
   - Xcode Archive -> Export as Developer ID signed app

3. Notarization
   - xcrun notarytool submit Neverdie.app.zip
   - xcrun stapler staple Neverdie.app

4. Package
   - Create .dmg (drag-to-Applications installer)
   - Compute SHA256 hash

5. Distribution
   - Homebrew Cask: Update formula with new version + SHA256
   - App Store: Upload via Transporter (separate build with sandbox)
```

### CI/CD (GitHub Actions)

```yaml
# Simplified pipeline outline
on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-14
    steps:
      - xcodebuild archive (Universal Binary)
      - xcodebuild -exportArchive
      - notarytool submit + staple
      - create-dmg
      - Upload .dmg as release artifact
      - Update Homebrew tap formula
```

### Rollback Procedure

- **Homebrew Cask**: Users run `brew reinstall --cask neverdie` after the formula is reverted to the previous version. Maintainer reverts the Cask formula commit.
- **App Store**: Use "Remove from Sale" if critical, then submit a fixed version. Apple does not support version rollback on the App Store.
- **Direct download**: Previous .dmg versions are kept as GitHub Release assets. Users can download any prior version.
- **Database migration rollback**: Not applicable -- no database.

### Deployment Target

| Channel | Format | Signing | Sandbox |
|---------|--------|---------|---------|
| Homebrew Cask | .dmg | Developer ID + Notarization | No (Hardened Runtime only) |
| App Store | .app (via Transporter) | App Store Distribution | Yes (required) |

---

## Tradeoffs

| Decision | Chosen | Rejected | Rationale |
|----------|--------|----------|-----------|
| Architecture | Single-process monolith | XPC service for sleep management | No benefit to process separation. IOPMAssertion is a single API call. XPC adds complexity for zero gain. If the main process dies, IOKit reclaims the assertion anyway |
| State management | `@Observable` class (AppState) | Redux/TCA (The Composable Architecture) | TCA is powerful but overkill for an app with ~5 state properties and ~3 user actions. `@Observable` is built into Swift 5.9 and has zero dependency cost. If state complexity grows, TCA can be adopted later |
| Process detection | `proc_listpids()` + `proc_name()` | `NSRunningApplication` / `pgrep` shell command | NSRunningApplication only lists GUI apps -- Claude Code is CLI and would not appear. Shell commands spawn subprocesses on every poll, violating FR-013. libproc is the correct low-level API |
| Hover popover | `NSTrackingArea` + `NSPopover` | Click-only popover / info in dropdown menu | Hover matches the PRD spec (US-005, US-006). NSTrackingArea on NSStatusItem button is feasible but non-standard. If hover proves unreliable, fall back to showing info in the right-click menu -- this is a documented escape hatch |
| Token data access | Local file parsing (`~/.claude/`) | CLI output parsing / Anthropic API | File parsing has no subprocess overhead and no API key requirement. CLI parsing requires spawning a process and parsing stdout. API calls are explicitly out of scope. File format instability is mitigated by graceful degradation |
| Animation | Timer-based NSImage swap | Core Animation / CADisplayLink | Core Animation in NSStatusItem is unreliable and may cause rendering issues. Timer at 6fps is 6 image assignments per second -- trivial CPU cost. This is the approach used by other menu bar apps (e.g., KeepingYouAwake for simple state) |
| External dependencies | Zero (Apple frameworks only) | Sparkle (auto-update), TCA, etc. | Zero dependencies = zero supply chain risk, smaller binary, no version conflicts. Homebrew handles updates. App Store handles updates. Sparkle can be added later if direct-download becomes a primary channel |
| Data persistence | None (in-memory + SMAppService) | UserDefaults for preferences | MVP has no user-configurable settings. Poll interval is hardcoded. Launch at Login is managed by the system. Adding UserDefaults later is trivial if preferences UI is added |
| App Store sandbox | Separate build config for App Store | Single build for both channels | IOPMAssertion behavior inside sandbox needs verification. Keeping Homebrew Cask as unsandboxed ensures the core feature always works. App Store build is a stretch goal |

### What Changes at 10x Scale

This is a single-user desktop app, so "10x scale" means feature growth, not user load.

| Growth scenario | Impact | Adaptation |
|----------------|--------|------------|
| Support more process types (not just Claude Code) | ProcessMonitor needs configurable match rules | Add a config file or preferences UI. ProcessMonitor already takes a match list |
| Rich preferences UI | Need persistent settings | Add UserDefaults + a Settings window. Consider adopting SwiftUI Settings scene |
| Multiple data sources for token usage | TokenMonitor needs plugin architecture | Define a `TokenDataSource` protocol. Each source (file, CLI, API) implements it |
| Complex state transitions | AppState becomes unwieldy | Adopt TCA or a state machine library. The current MVVM is designed to be replaceable |

---

## Confidence Rating: **High**

**Reasoning**: All Must-priority requirements (FR-001 through FR-014) map cleanly to well-understood macOS APIs (IOKit, libproc, SwiftUI MenuBarExtra, NSStatusItem). The architecture is simple -- one process, five modules, zero external dependencies. The two medium-confidence areas from requirements (token data source, hover popover) are explicitly designed with fallback paths:

1. **Token data source**: Graceful degradation to "unavailable" is a first-class design choice, not an afterthought.
2. **Hover popover**: NSTrackingArea approach is documented with a concrete fallback (info in dropdown menu).

The only area that requires implementation-time validation is the App Store sandbox compatibility with IOPMAssertion. This is mitigated by Homebrew Cask as the primary distribution channel.
