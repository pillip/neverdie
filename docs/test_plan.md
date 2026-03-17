# Test Plan

## Strategy

### Testing Pyramid

| Level | Ratio | Rationale |
|-------|-------|-----------|
| Unit tests | 60% | Business logic in AppState (state machine, auto-OFF logic), SleepManager (assertion lifecycle), ProcessMonitor (name matching), TokenMonitor (JSON parsing), AnimationManager (frame cycling). These are pure Swift classes with well-defined interfaces that can be tested in isolation with mocked system APIs. |
| Integration tests | 30% | Module interactions: AppState coordinating SleepManager + ProcessMonitor for auto-OFF flow, AppState + TokenMonitor for popover data, cleanup sequence across all modules. Also covers IOKit assertion creation/release on real hardware. |
| E2E / Manual | 10% | Menu bar icon rendering, popover display, dropdown menu interaction, light/dark mode icon visibility. macOS menu bar apps have limited UI automation support; critical visual and interaction flows require manual verification or XCUITest. |

### Test Framework

- **Unit + Integration**: XCTest (built into Xcode, zero dependencies)
- **UI tests**: XCUITest for dropdown menu and basic icon presence
- **Manual**: Smoke checklist for visual/animation verification
- **Performance**: XCTest `measure` blocks for CPU/memory assertions

### CI Integration

- **Every PR**: Unit tests, integration tests (mocked system APIs), SwiftUI preview compilation, `swiftlint` (if adopted)
- **Nightly**: XCUITest suite, performance benchmarks, Universal Binary build verification (arm64 + x86_64)
- **Pre-release**: Manual smoke checklist, `pmset -g assertions` verification on real hardware, App Store sandbox build test

---

## Risk Matrix

| Flow | Likelihood | Impact | Risk | Coverage Level |
|------|-----------|--------|------|----------------|
| Sleep prevention (IOPMAssertion create/release) | Medium | Critical | **High** | Unit + Integration + Manual |
| Auto-OFF when all Claude processes end | Medium | High | **High** | Unit + Integration |
| Assertion cleanup on quit/signal/crash | Low | Critical | **High** | Unit + Integration + Manual |
| Toggle ON/OFF (click interaction) | Low | Critical | **High** | Unit + Integration + E2E |
| Process detection (polling, name matching) | Medium | High | **High** | Unit + Integration |
| Token data parsing (file I/O, graceful degradation) | High | Medium | **High** | Unit |
| Hover popover display | Medium | Medium | **Medium** | Unit + Manual |
| Animated icon (frame cycling, light/dark) | Low | Medium | **Medium** | Unit + Manual |
| Dropdown menu (Quit, Launch at Login) | Low | Medium | **Medium** | Unit + E2E |
| Launch at Login (SMAppService) | Low | Low | **Low** | Integration + Manual |
| Per-session token breakdown (P2) | Medium | Low | **Low** | Unit |

---

## Critical Flows (ordered by risk)

### Flow: Sleep Prevention (IOPMAssertion Lifecycle)

- Risk level: **High**
- Related requirements: FR-005, FR-006, FR-007, FR-008, FR-009, NFR-005
- Rationale: This is the core value proposition. If sleep prevention fails silently, the user's entire reason for using the app is defeated.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-001 | App launched, mode OFF | Call `SleepManager.preventSleep()` | Returns `true`. `isAssertionHeld` is `true`. `pmset -g assertions` shows Neverdie assertion with type `PreventUserIdleSystemSleep` | Integration |
| TC-002 | Assertion held (mode ON) | Call `SleepManager.allowSleep()` | `isAssertionHeld` is `false`. `pmset -g assertions` no longer shows Neverdie assertion | Integration |
| TC-003 | Assertion held (mode ON) | Verify display sleep behavior | Display sleep is NOT prevented (assertion type is `PreventUserIdleSystemSleep`, not `PreventUserIdleDisplaySleep`) | Manual |
| TC-004 | No assertion held | Call `SleepManager.allowSleep()` | No-op, no crash, `isAssertionHeld` remains `false` | Unit |
| TC-005 | Mock IOPMAssertionCreateWithName to return failure code | Call `SleepManager.preventSleep()` | Returns `false`. `isAssertionHeld` remains `false`. Error logged via os.Logger | Unit |
| TC-006 | Assertion held | Call `preventSleep()` again without releasing first | Either returns existing assertion (idempotent) or releases old + creates new. No leaked assertion | Unit |
| TC-007 | Assertion held | SleepManager `deinit` fires | `allowSleep()` called, assertion released | Unit |
| TC-008 | Assertion held | Send SIGTERM to process | Assertion released before exit (verify via signal handler test or `pmset` check post-termination) | Integration |
| TC-009 | Assertion held | Force-kill process (SIGKILL) | IOKit reclaims assertion automatically. `pmset -g assertions` shows no lingering Neverdie assertion | Manual |

---

### Flow: Auto-OFF When All Claude Processes End

- Risk level: **High**
- Related requirements: FR-013, FR-014, US-004
- Rationale: Incorrect auto-OFF logic (false positives or false negatives) either drains battery unnecessarily or disrupts the user's workflow by releasing sleep prevention prematurely.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-010 | Mode ON, `claudeProcessesEverDetected = true`, 2 claude processes running | Poll returns 0 processes | `isActive` becomes `false`, assertion released, icon switches to static OFF, `claudeProcessesEverDetected` reset | Unit |
| TC-011 | Mode ON, `claudeProcessesEverDetected = true`, 2 claude processes running | Poll returns 1 process (one terminated) | `isActive` remains `true`, `processCount` updated to 1 | Unit |
| TC-012 | Mode ON, user manually activated, no claude processes ever detected | Poll returns 0 | `isActive` remains `true` (manual override, auto-OFF must NOT trigger) | Unit |
| TC-013 | Mode ON, `claudeProcessesEverDetected = false` | Poll detects 1 claude process, then next poll detects 0 | First poll: `claudeProcessesEverDetected` becomes `true`. Second poll: auto-OFF triggers, `isActive` becomes `false` | Unit |
| TC-014 | Mode ON, 1 claude process running | Process terminates and new one starts within same 30s poll interval | Poll returns 1 (or more). No auto-OFF. Count never reached zero at poll time | Unit |
| TC-015 | Mode ON, processes detected | Process detection fails (mock `proc_listallpids` error) | Auto-OFF does NOT trigger. `processCount` shows last known value or 0 with error flag. Polling continues | Unit |
| TC-016 | Mode OFF | Poll timer fires | Timer should not be running, or poll result is ignored. No state change | Unit |

---

### Flow: Toggle ON/OFF

- Risk level: **High**
- Related requirements: FR-002, FR-005, FR-007, FR-010, FR-011
- Rationale: Primary user interaction. Must work reliably every time.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-020 | Mode OFF | `AppState.toggle()` | `isActive` becomes `true`, `SleepManager.preventSleep()` called, `AnimationManager.startAnimation()` called, `processCount` polling begins | Unit |
| TC-021 | Mode ON | `AppState.toggle()` | `isActive` becomes `false`, `SleepManager.allowSleep()` called, `AnimationManager.stopAnimation()` called | Unit |
| TC-022 | Mode OFF | Toggle ON when `SleepManager.preventSleep()` returns failure | `isActive` remains `false`. Error state set. Dropdown status shows "Neverdie: Error -- could not prevent sleep" | Unit |
| TC-023 | Mode OFF | Rapid double-click (two toggles within 300ms) | First click activates. Second click ignored (debounce). Mode is ON | Unit |
| TC-024 | Mode ON, claude processes still running | Toggle OFF | Mode turns OFF regardless. No warning. Assertion released. User intent is explicit | Unit |
| TC-025 | Mode ON (via auto or manual) | Toggle OFF then immediately ON | Assertion released then re-created. Both transitions succeed. No leaked assertion | Integration |
| TC-026 | Mode OFF | Toggle ON via keyboard (Space/Enter when icon focused) | Same result as left-click: mode ON, assertion created | E2E |

---

### Flow: Process Detection

- Risk level: **High**
- Related requirements: FR-013, FR-015
- Rationale: Incorrect process name matching is a known risk. False negatives mean auto-OFF never works; false positives could cause premature auto-OFF.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-030 | Mock process list with processes named "claude", "Finder", "Safari" | `ProcessMonitor.pollOnce()` | Returns count 1 (only "claude" matched) | Unit |
| TC-031 | Mock process list with "claude" and "claude-code" | `ProcessMonitor.pollOnce()` | Returns count 2 (both match known names) | Unit |
| TC-032 | Mock process list with no "claude" processes | `ProcessMonitor.pollOnce()` | Returns count 0 | Unit |
| TC-033 | Mock process list with "claudex", "myclaude" | `ProcessMonitor.pollOnce()` | Returns count 0 (partial matches rejected -- exact name match only) | Unit |
| TC-034 | Mock `proc_listallpids` returns error | `ProcessMonitor.pollOnce()` | Returns 0, logs error, does not crash | Unit |
| TC-035 | Real system with Claude Code running | `ProcessMonitor.pollOnce()` | Returns correct count matching `pgrep -x claude` output | Integration |
| TC-036 | Polling started | Wait 30 seconds | Callback fires with updated count. Timer interval is approximately 30s | Integration |
| TC-037 | Polling started | Call `stopPolling()` | Timer invalidated. No further callbacks fire | Unit |
| TC-038 | Large process table (1000+ processes) | `ProcessMonitor.pollOnce()` | Completes within 100ms. CPU spike is negligible | Unit (performance) |

---

### Flow: Token Data Parsing

- Risk level: **High** (likelihood) / **Medium** (impact, due to graceful degradation)
- Related requirements: FR-016, FR-017
- Rationale: Token data source format is unstable and may not exist. This is the highest-likelihood failure point.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-040 | Valid JSON file at expected path with context/input/output fields | `TokenMonitor.readUsage()` | Returns `TokenUsage(context: N, input: N, output: N)` with correct values | Unit |
| TC-041 | `~/.claude/projects/` directory does not exist | `TokenMonitor.readUsage()` | Returns `nil`. No crash. Logged at `.info` level | Unit |
| TC-042 | JSON file exists but is malformed (invalid JSON) | `TokenMonitor.readUsage()` | Returns `nil`. No crash. JSONDecoder error caught | Unit |
| TC-043 | JSON file exists but schema differs (missing expected fields) | `TokenMonitor.readUsage()` | Returns `nil`. No crash. Missing key error caught | Unit |
| TC-044 | JSON file exists but is empty (0 bytes) | `TokenMonitor.readUsage()` | Returns `nil`. No crash | Unit |
| TC-045 | File exists but app lacks read permission | `TokenMonitor.readUsage()` | Returns `nil`. Permission error logged | Unit |
| TC-046 | Multiple project directories under `~/.claude/projects/` | `TokenMonitor.readUsage()` | Aggregates token data across all sessions correctly | Unit |
| TC-047 | Token values are very large (e.g., 999999999) | `TokenMonitor.readUsage()` | Returns correct values. No integer overflow | Unit |
| TC-048 | Token values are zero | `TokenMonitor.readUsage()` | Returns `TokenUsage(context: 0, input: 0, output: 0)` (valid, not nil) | Unit |
| TC-049 | Two valid session directories | `TokenMonitor.readPerSessionUsage()` | Returns array of 2 `SessionTokenUsage` with correct labels and values | Unit |
| TC-050 | File changes between two reads | Read, modify file, read again | Second read returns updated values (no caching) | Unit |

---

### Flow: App Quit and Cleanup

- Risk level: **High**
- Related requirements: FR-008, FR-009, US-007
- Rationale: Failed cleanup leaves a lingering assertion that prevents system sleep indefinitely.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-060 | Mode ON, assertion held, polling active | `AppState.cleanup()` | `SleepManager.allowSleep()` called, `ProcessMonitor.stopPolling()` called, `AnimationManager.stopAnimation()` called. All resources released | Unit |
| TC-061 | Mode OFF, no assertion | `AppState.cleanup()` | No-op on assertion release. No crash. Timers stopped | Unit |
| TC-062 | Mode ON | Select "Quit Neverdie" from dropdown | Cleanup runs, then `NSApplication.shared.terminate` called. Assertion no longer in `pmset -g assertions` | E2E |
| TC-063 | Mode ON | Send SIGINT (Ctrl+C in terminal launch) | Signal handler invokes cleanup. Assertion released before exit | Integration |

---

### Flow: Hover Popover Display

- Risk level: **Medium**
- Related requirements: FR-015, FR-017, US-005, US-006
- Rationale: Non-standard macOS interaction (hover on NSStatusItem). Implementation feasibility is uncertain.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-070 | Mode ON, 3 processes detected | Hover over icon (wait 200ms) | Popover appears showing "3 active sessions" and token bar graphs | Manual |
| TC-071 | Mode ON, 0 processes detected | Hover over icon | Popover shows "No active sessions" | Manual |
| TC-072 | Token data unavailable | Hover over icon | Popover shows "Token data unavailable" in place of bar graphs. Process count still displays | Manual |
| TC-073 | Process detection failed | Hover over icon | Popover shows "Process detection unavailable". Token data displays independently if available | Manual |
| TC-074 | Both token and process data unavailable | Hover over icon | Popover shows both "unavailable" messages. No crash | Unit |
| TC-075 | Popover open | Auto-OFF triggers | Popover updates in-place: count drops to 0, status reflects OFF | Unit |
| TC-076 | Popover open | Mouse exits popover area | Popover dismisses after 100ms grace period | Manual |
| TC-077 | Mouse quickly passes over icon (<200ms) | Move mouse through | No popover appears (200ms delay prevents flicker) | Manual |

---

### Flow: Dropdown Menu

- Risk level: **Medium**
- Related requirements: FR-003, FR-004, US-007, US-008
- Rationale: Standard macOS NSMenu behavior, low risk but contains Quit (critical path).

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-080 | App running, mode OFF | Right-click icon | Dropdown shows "Neverdie: OFF", "Launch at Login" (unchecked), "Quit Neverdie" | E2E |
| TC-081 | App running, mode ON | Right-click icon | Dropdown shows "Neverdie: ON" | E2E |
| TC-082 | Error state (assertion failed) | Right-click icon | Dropdown shows "Neverdie: Error" | Unit |
| TC-083 | Launch at Login disabled | Click "Launch at Login" | Checkmark appears. `SMAppService.mainApp.register()` called | Integration |
| TC-084 | Launch at Login enabled | Click "Launch at Login" | Checkmark removed. `SMAppService.mainApp.unregister()` called | Integration |
| TC-085 | Mock SMAppService.register() failure | Click "Launch at Login" | NSAlert displayed: "Could not enable Launch at Login". Menu item remains unchecked | Unit |
| TC-086 | Popover is open | Right-click icon | Popover dismisses, dropdown appears | Manual |

---

### Flow: Animated Icon

- Risk level: **Medium**
- Related requirements: FR-010, FR-011, FR-012, NFR-008
- Rationale: Visual feedback is core to UX, but failure is non-fatal (app still functions).

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-090 | Mode OFF | Observe icon | Static sleeping zombie icon displayed (single frame) | Manual |
| TC-091 | Mode ON | Observe icon | Animated icon looping at 4-8fps (visually count frames over 1 second) | Manual |
| TC-092 | Mode ON | Toggle OFF | Animation stops. Static icon displayed within 1 frame cycle (~167ms) | Manual |
| TC-093 | `AnimationManager` with 6 frames loaded | Call `startAnimation()`, check `currentFrame` over time | Frame index cycles 0-5 at approximately 6fps | Unit |
| TC-094 | `AnimationManager` | Call `stopAnimation()` | Timer invalidated. `currentFrame` returns `staticOffIcon` | Unit |
| TC-095 | Asset catalog missing animation frames | `AnimationManager` init | Falls back to SF Symbol "bolt.fill". No crash | Unit |
| TC-096 | System in dark mode | Observe icon in both ON and OFF states | Icon is clearly visible (template image rendering: light icon on dark background) | Manual |
| TC-097 | System in light mode | Observe icon in both ON and OFF states | Icon is clearly visible (template image rendering: dark icon on light background) | Manual |
| TC-098 | `accessibilityDisplayShouldReduceMotion` is true | Mode ON | Static "active zombie" frame displayed instead of animation loop | Unit |

---

### Flow: App Launch

- Risk level: **Low**
- Related requirements: FR-001, NFR-001
- Rationale: One-time event, but must work correctly for first impression.

#### Test Cases

| ID | Precondition | Action | Expected Result | Type |
|----|-------------|--------|-----------------|------|
| TC-100 | App not running | Launch app | Icon appears in menu bar within 2 seconds. No Dock icon. Mode is OFF. Static zombie icon displayed | Manual |
| TC-101 | App already running | Launch second instance | Second instance detects first via `NSRunningApplication`, quits immediately | Integration |
| TC-102 | App launched | Check `Info.plist` | `LSUIElement = true` is set | Unit (build validation) |
| TC-103 | App launched | VoiceOver focused on icon | Announces "Neverdie -- sleep prevention OFF" | Manual |
| TC-104 | App launched | Check process polling | Polling starts immediately (to detect already-running Claude Code sessions) | Unit |

---

## E2E Testing Strategy

### Platform Detection

- **Detected platform**: macOS native desktop app (SwiftUI + AppKit)
- **Source**: `docs/architecture.md` -- Single-process SwiftUI macOS menu bar app, zero web/mobile components

### macOS UI Testing (XCUITest)

- **Framework**: XCUITest (built into Xcode, native macOS UI testing)
- **Test location**: `NeverdieTests/UITests/*.swift`
- **Scope**: Limited to verifiable UI elements -- dropdown menu items, icon presence in menu bar. Hover popover testing is unreliable via XCUITest and is designated manual.
- **CI**: Run on every PR (macos-14 runner). Tests mock SleepManager and ProcessMonitor to avoid system-level side effects.

### Why Not Playwright/Maestro

This is a native macOS menu bar app, not a web or mobile app. XCUITest is the only viable automated UI testing framework. Menu bar interactions have limited automation support even in XCUITest -- the dropdown menu is the most automatable surface.

---

## Backend Robustness

This app has no backend, no API, and no network communication. The equivalent "backend" concerns are system API interactions and file I/O.

### System API Contract Tests

| API | Contract Assertion | Test Approach |
|-----|-------------------|---------------|
| `IOPMAssertionCreateWithName` | Returns `kIOReturnSuccess` on valid input. Returns assertion ID > 0 | Integration test on real hardware (CI macos-14 runner) |
| `IOPMAssertionRelease` | Returns `kIOReturnSuccess` for valid assertion ID. No-op/error for invalid ID | Integration test |
| `proc_listallpids` | Returns > 0 (at least the test process itself). Populates buffer with PIDs | Integration test |
| `proc_name` | Returns process name string for valid PID. Returns empty for invalid PID | Integration test |
| `SMAppService.mainApp.register()` | Does not throw on valid app bundle | Integration test (may require entitlement) |
| `FileManager.contentsOfDirectory` | Returns entries for `~/.claude/projects/` if it exists. Throws for non-existent path | Unit test with temp directory |
| `JSONDecoder.decode` | Correctly decodes expected schema. Throws `DecodingError` for invalid input | Unit test |

### Performance Benchmarks

| Operation | Expected Metric | Tool |
|-----------|----------------|------|
| `ProcessMonitor.pollOnce()` | < 100ms wall time, < 1% CPU spike | XCTest `measure` block |
| `TokenMonitor.readUsage()` | < 50ms for 10 session files | XCTest `measure` block |
| `AnimationManager` frame swap | < 1ms per frame, no visible jank | XCTest `measure` block |
| Idle memory (mode OFF) | <= 50 MB resident | `footprint` CLI measurement in CI |
| Idle CPU (mode ON, polling) | < 1% averaged over 60s | Activity Monitor / `top` in CI |

### Dependency Failure Scenarios

| Dependency | Failure Mode | Expected Behavior |
|------------|-------------|-------------------|
| IOKit (IOPMAssertion) | `IOPMAssertionCreateWithName` returns error | `SleepManager.preventSleep()` returns `false`. AppState remains OFF. Error shown in dropdown status. User can retry |
| IOKit (IOPMAssertion) | `IOPMAssertionRelease` returns error | Error logged. Force-set state to OFF. Icon returns to static. Assertion cleaned up on app quit or process death |
| libproc (process table) | `proc_listallpids` fails (permissions) | ProcessMonitor returns 0. Auto-OFF does NOT trigger (fail-safe: keep ON). "Process detection unavailable" in popover |
| File system (`~/.claude/`) | Directory does not exist | `TokenMonitor.readUsage()` returns `nil`. Popover shows "Token data unavailable" |
| File system (`~/.claude/`) | File locked / permission denied | Same as above -- `nil` return, graceful degradation |
| SMAppService | Registration fails | NSAlert shown to user: "Could not enable Launch at Login". Toggle stays unchecked. Non-blocking |
| NSImage assets | Animation frames missing from bundle | AnimationManager falls back to SF Symbol `"bolt.fill"`. App remains functional |

---

## Edge Cases and Boundary Tests

### Empty / Null / Zero States
- App launched with no Claude Code installed at all (no `~/.claude/` directory)
- Zero processes, zero token data -- popover shows minimal state without crash
- Token values of exactly 0 (valid, not nil)
- Empty JSON file, empty directory

### Maximum / Overflow
- Process table with 1000+ entries (performance boundary)
- Token values at Int.max (no overflow in display formatting)
- 10+ Claude Code sessions simultaneously (popover scrolling / layout)
- Rapid toggling: 50 ON/OFF cycles in sequence (no assertion leak)

### Concurrency
- Poll timer fires while toggle is in progress (thread safety of `isActive` / `processCount`)
- Popover opens during poll update (data consistency)
- SIGTERM arrives during toggle transition (cleanup in partial state)
- Multiple `cleanup()` calls (idempotent)

### Permission Boundaries
- App running without Full Disk Access (token files may be inaccessible)
- App running in App Store sandbox (IOPMAssertion behavior)
- App running as non-admin user (IOKit assertions should work regardless)

### Platform Boundaries
- macOS 14.0 (minimum supported -- no newer API usage)
- macOS 15.x (latest -- verify no deprecations)
- Apple Silicon (arm64) vs Intel (x86_64) -- Universal Binary correctness
- Retina vs non-Retina display (icon rendering)

---

## Test Data and Fixtures

### Token Data Fixtures

| Fixture | Description | File |
|---------|-------------|------|
| `valid_single_session.json` | Single session with context=45200, input=22100, output=11800 | `Tests/Fixtures/TokenData/` |
| `valid_multi_session/` | Directory with 3 session subdirectories, each with valid JSON | `Tests/Fixtures/TokenData/` |
| `malformed.json` | Invalid JSON: `{ "context": }` | `Tests/Fixtures/TokenData/` |
| `wrong_schema.json` | Valid JSON but unexpected keys: `{ "tokens_used": 1000 }` | `Tests/Fixtures/TokenData/` |
| `empty.json` | Zero-byte file | `Tests/Fixtures/TokenData/` |
| `large_values.json` | Token values at 999,999,999 | `Tests/Fixtures/TokenData/` |
| `zero_values.json` | All token values at 0 | `Tests/Fixtures/TokenData/` |

### Process List Fixtures (Mocked)

| Fixture | Description |
|---------|-------------|
| `processes_with_claude` | ["Finder", "claude", "Safari", "loginwindow"] |
| `processes_with_multiple_claude` | ["claude", "claude", "claude-code", "Finder"] |
| `processes_without_claude` | ["Finder", "Safari", "loginwindow", "WindowServer"] |
| `processes_with_similar_names` | ["claudex", "myclaude", "claude-helper", "Finder"] |
| `processes_empty` | [] |
| `processes_large` | 1000 random process names + 2 "claude" entries |

### Mock Protocols

```swift
// SleepManager protocol for testability
protocol SleepManaging {
    func preventSleep() -> Bool
    func allowSleep()
    var isAssertionHeld: Bool { get }
}

// ProcessMonitor protocol for testability
protocol ProcessMonitoring {
    func pollOnce() -> Int
    func startPolling(onUpdate: @escaping (Int) -> Void)
    func stopPolling()
}

// TokenMonitor protocol for testability
protocol TokenMonitoring {
    func readUsage() -> TokenUsage?
    func readPerSessionUsage() -> [SessionTokenUsage]
}
```

### Sensitive Data Handling

- No real PII in any test fixture
- Token data fixtures use synthetic numbers only
- Process names in fixtures are common macOS system processes or the target "claude" name
- No real file system paths beyond `~/.claude/` (which contains no PII)
- Test fixtures for file I/O use temporary directories (`FileManager.default.temporaryDirectory`)

---

## Automation Candidates

### CI (Every PR)

- [x] All unit tests (`XCTest` suite)
- [x] Integration tests with mocked system APIs
- [x] Build verification: Universal Binary compiles for arm64 + x86_64
- [x] `Info.plist` validation: `LSUIElement = true`
- [x] SwiftUI preview compilation (catches view layer build errors)
- [x] Static analysis: Swift compiler warnings as errors

### Nightly

- [x] XCUITest suite (dropdown menu, icon presence)
- [x] Performance benchmarks (memory, CPU, poll duration)
- [x] Integration tests on real IOKit (macos-14 runner, actual assertion create/release)
- [x] `pmset -g assertions` validation after test suite (no leaked assertions)

### Manual (Pre-release)

- [ ] Visual icon verification in light and dark mode
- [ ] Animation smoothness check (4-8fps, no jank)
- [ ] Hover popover positioning (near screen edge)
- [ ] VoiceOver announcement verification for all state changes
- [ ] Reduced motion preference: animation replaced with static frame
- [ ] Force-quit via Activity Monitor: verify no lingering assertion

---

## Visual Regression

### Applicability

Limited applicability for a menu bar app. The visual surface is small (18x18pt icon + popover + native NSMenu). However, icon rendering correctness is critical for the zombie theme UX.

### Approach

- **Icon snapshot tests**: Capture `NSImage` output of each animation frame and the static OFF frame. Compare against reference images using XCTest image comparison or a pixel-diff utility.
- **Popover layout snapshots**: Capture popover view in various states (data available, data unavailable, empty sessions, multiple sessions) using SwiftUI preview snapshots.
- **Threshold**: Pixel diff < 1% (menu bar icons are small; even minor changes are noticeable at 18x18pt)
- **Light/dark mode**: Separate reference snapshots for each appearance mode

### What to Snapshot

| Screen | States to Capture |
|--------|------------------|
| Menu bar icon - OFF | Static zombie, light mode; static zombie, dark mode |
| Menu bar icon - ON | Each animation frame (6-8 frames), light mode; dark mode |
| Menu bar icon - Error | Icon with red dot overlay |
| Popover - Default | 3 sessions, token data available |
| Popover - Empty | No sessions, no token data |
| Popover - Partial error | Process count shown, token data unavailable |
| Dropdown menu | OFF state; ON state; Error state |

---

## Release Checklist (Smoke)

Execute manually in under 5 minutes on a clean macOS 14+ machine:

- [ ] Launch app: icon appears in menu bar within 2 seconds, no Dock icon, sleeping zombie displayed
- [ ] Left-click icon: animated zombie starts, `pmset -g assertions | grep Neverdie` shows the assertion
- [ ] Left-click icon again: animation stops, static zombie displayed, `pmset -g assertions | grep Neverdie` returns empty
- [ ] Right-click icon: dropdown menu appears with "Neverdie: OFF", "Launch at Login", "Quit Neverdie"
- [ ] Toggle ON, then select "Quit Neverdie": app terminates, `pmset -g assertions | grep Neverdie` returns empty
- [ ] Verify Universal Binary: `lipo -info Neverdie.app/Contents/MacOS/Neverdie` shows both arm64 and x86_64
- [ ] Verify icon visibility in both light and dark mode (System Settings > Appearance toggle)

---

## Confidence Rating: **High**

**Reasoning**: The app has a small, well-defined surface area (5 modules, 3 UI layers, zero network). All 18 FRs are covered by at least one test case. Every critical flow (sleep prevention, auto-OFF, toggle, cleanup) has both positive and negative test cases. The two highest-risk areas (token data instability, hover popover feasibility) are covered with explicit degradation test cases (TC-041 through TC-045 for token, TC-072 through TC-077 for popover). The testing approach uses XCTest natively, matching the Swift/Xcode tech stack with zero additional test framework dependencies. The only area where confidence is slightly reduced is XCUITest coverage of menu bar interactions, which is inherently limited by macOS UI test automation capabilities -- this is mitigated by the manual smoke checklist.
