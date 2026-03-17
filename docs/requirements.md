# Requirements

## Goals (from PRD)

1. **Zero sleep interruption**: Completely prevent macOS system sleep from interrupting Claude Code tasks while Neverdie mode is ON.
2. **Hands-free automation**: Automatically manage sleep prevention by detecting Claude Code processes -- no manual intervention required.
3. **At-a-glance monitoring**: Show Claude Code token usage and process status from the menu bar without switching to the terminal.
4. **Delightful UX**: Communicate app state intuitively through animated zombie character icons.

## Primary User

macOS developers (macOS 14 Sonoma or later) who routinely use Claude Code CLI and leave long-running agent tasks (builds, tests, large-scale refactoring) unattended.

## User Stories (prioritized -- Must > Should > Could)

### US-001: Manual sleep prevention toggle
- **As a** Claude Code user, **I want** to toggle sleep prevention by clicking the menu bar icon **so that** I do not have to change system settings manually for long tasks.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given the app is running and Neverdie mode is OFF, when the user clicks the menu bar icon, then Neverdie mode turns ON and system sleep is prevented.
  - [ ] Given the app is running and Neverdie mode is ON, when the user clicks the menu bar icon, then Neverdie mode turns OFF and normal sleep behavior is restored.

### US-002: Display sleep allowed while system stays awake
- **As a** Claude Code user, **I want** the display to turn off while the system remains awake in Neverdie mode **so that** battery is conserved while tasks continue.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is ON, when the display idle timeout elapses, then the display turns off but the system does NOT enter sleep.
  - [ ] Given Neverdie mode is ON, when a Claude Code process is running, then the process continues executing after the display turns off.

### US-003: Animated icon reflects state
- **As a** Claude Code user, **I want** the menu bar icon to show different animations for ON and OFF states **so that** I can tell the current state at a glance.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is OFF, then the menu bar displays a static (sleeping/peaceful) zombie icon.
  - [ ] Given Neverdie mode is ON, then the menu bar displays a looping frame animation of a zombie being shot at.
  - [ ] Given the system appearance changes between light and dark mode, then the icon remains clearly visible in both modes.

### US-004: Auto-OFF when all Claude Code processes end
- **As a** Claude Code user, **I want** Neverdie mode to turn off automatically when all Claude Code processes terminate **so that** sleep is not prevented unnecessarily.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is ON and one or more `claude` processes are running, when all `claude` processes terminate, then Neverdie mode turns OFF within the polling interval (default 30 seconds).
  - [ ] Given Neverdie mode is ON and the user manually activated it (no Claude Code processes running), when the user does not toggle OFF, then the mode remains ON (auto-OFF only applies when processes were detected and then all ended).

### US-005: Hover shows process count
- **As a** Claude Code user, **I want** to see the number of running Claude Code processes when I hover over the menu bar icon **so that** I know how many sessions are active.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is ON and 3 Claude Code processes are running, when the user hovers over the menu bar icon, then a popover displays "3 active sessions" (or equivalent).
  - [ ] Given no Claude Code processes are running, when the user hovers over the menu bar icon, then the popover displays "0 active sessions" (or equivalent).

### US-006: Hover shows token usage
- **As a** Claude Code user, **I want** to see token usage (Context, Input, Output) as bar graphs and numbers in a hover popover **so that** I can monitor usage without switching to the CLI.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] Given at least one Claude Code session is running, when the user hovers over the menu bar icon, then a popover displays three bar graphs (Context, Input, Output) with numeric values.
  - [ ] Given token data is unavailable (e.g., data source not found), when the user hovers, then the popover displays "Token data unavailable" instead of crashing or showing stale data.

### US-007: Quit from menu
- **As a** user, **I want** a "Quit Neverdie" option in the dropdown menu **so that** I can cleanly exit the app.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given the app is running, when the user opens the dropdown menu, then a "Quit Neverdie" option is visible.
  - [ ] Given Neverdie mode is ON, when the user selects "Quit Neverdie", then the IOPMAssertion is released and the app terminates.

### US-008: Launch at login
- **As a** user, **I want** Neverdie to start automatically when I log in **so that** I do not have to remember to launch it.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] Given the user enables "Launch at Login" in the app menu, when the user logs in to macOS, then Neverdie starts automatically and appears in the menu bar.
  - [ ] Given the user disables "Launch at Login", when the user logs in, then Neverdie does not start automatically.

### US-009: Per-session token breakdown
- **As a** Claude Code user, **I want** to see token usage separated by session when multiple sessions are running **so that** I can identify which session is consuming the most tokens.
- **Priority**: Could
- **Acceptance Criteria**:
  - [ ] Given 2+ Claude Code sessions are running, when the user views the hover popover, then token usage is displayed per session with a way to distinguish them.

---

## Functional Requirements

### Feature Area: Menu Bar App

#### FR-001: Menu bar icon display
- **Description**: On launch, the app displays an icon in the macOS menu bar. No Dock icon is shown (LSUIElement = true).
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] The app icon appears in the macOS menu bar within 2 seconds of launch.
  - [ ] No icon appears in the Dock while the app is running.
  - [ ] The app's Info.plist contains `LSUIElement = true`.
- **Dependencies**: None

#### FR-002: Toggle Neverdie mode via click
- **Description**: Clicking the menu bar icon toggles Neverdie mode between ON and OFF.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] A single left-click on the menu bar icon changes the mode from OFF to ON.
  - [ ] A single left-click on the menu bar icon changes the mode from ON to OFF.
  - [ ] The icon animation updates immediately (within 1 frame cycle) to reflect the new state.
- **Dependencies**: FR-001, FR-005, FR-006

#### FR-003: Dropdown menu with Quit option
- **Description**: The menu bar icon provides a dropdown/context menu containing at least a "Quit Neverdie" option.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Right-click (or long-press, or designated secondary interaction) on the menu bar icon opens a dropdown menu.
  - [ ] The dropdown contains a "Quit Neverdie" menu item.
  - [ ] Selecting "Quit Neverdie" terminates the app after cleanup (see FR-009).
- **Dependencies**: FR-001

#### FR-004: Launch at Login
- **Description**: The app supports registration in macOS Login Items so it starts automatically on user login.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] A "Launch at Login" toggle is available in the dropdown menu.
  - [ ] When enabled, the app registers itself via SMAppService (or ServiceManagement) as a Login Item.
  - [ ] When disabled, the app removes itself from Login Items.
  - [ ] The toggle state persists across app restarts.
- **Dependencies**: FR-003

### Feature Area: Sleep Prevention

#### FR-005: Prevent system sleep via IOPMAssertion
- **Description**: When Neverdie mode is ON, the app creates an IOPMAssertion of type `kIOPMAssertionTypePreventUserIdleSystemSleep` to prevent the system from sleeping.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] When Neverdie mode transitions to ON, an IOPMAssertion is created with `IOPMAssertionCreateWithName`.
  - [ ] The assertion type is `kIOPMAssertionTypePreventUserIdleSystemSleep` (not display sleep prevention).
  - [ ] While the assertion is active, `pmset -g assertions` shows the Neverdie assertion.
  - [ ] The system does not enter idle sleep while the assertion is held.
- **Dependencies**: None

#### FR-006: Allow display sleep
- **Description**: The sleep prevention assertion must NOT prevent the display from turning off on idle.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] When Neverdie mode is ON, the display is allowed to turn off per the user's Energy Saver / Display settings.
  - [ ] The assertion type used does NOT include `kIOPMAssertionTypePreventUserIdleDisplaySleep`.
- **Dependencies**: FR-005

#### FR-007: Release assertion on mode OFF
- **Description**: When Neverdie mode transitions to OFF, the IOPMAssertion is released.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] When Neverdie mode transitions to OFF, `IOPMAssertionRelease` is called on the held assertion ID.
  - [ ] After release, `pmset -g assertions` no longer shows the Neverdie assertion.
  - [ ] Normal system sleep behavior is restored.
- **Dependencies**: FR-005

#### FR-008: Release assertion on unexpected termination signals
- **Description**: The app handles SIGTERM, SIGINT, and normal app termination to ensure assertions are cleaned up.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] When the app receives SIGTERM, the assertion is released before the process exits.
  - [ ] When the app is force-quit via Activity Monitor, the OS reclaims the assertion (IOKit behavior -- verify in testing).
  - [ ] On `applicationWillTerminate`, the assertion is released if held.
- **Dependencies**: FR-005

#### FR-009: Cleanup on quit
- **Description**: Selecting "Quit Neverdie" releases any held assertion before terminating.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is ON, when the user quits the app, then the IOPMAssertion is released before the process exits.
  - [ ] Given Neverdie mode is OFF, when the user quits the app, then no assertion release is attempted (no-op).
- **Dependencies**: FR-005, FR-003

### Feature Area: Animated Icon

#### FR-010: Static icon for OFF state
- **Description**: When Neverdie mode is OFF, the menu bar displays a static zombie icon (sleeping/peaceful zombie).
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] A single static image is displayed in the menu bar when mode is OFF.
  - [ ] The image fits within approximately 18x18pt (menu bar standard size).
  - [ ] The image uses a simple line-art or pixel-art style.
- **Dependencies**: FR-001

#### FR-011: Animated icon for ON state
- **Description**: When Neverdie mode is ON, the menu bar displays a looping frame animation of a zombie being shot.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] The animation consists of multiple frames (minimum 4 frames) displayed in a loop.
  - [ ] The frame rate is between 4 and 8 fps.
  - [ ] The animation runs continuously while mode is ON and stops when mode is OFF.
- **Dependencies**: FR-001

#### FR-012: Light/Dark mode icon support
- **Description**: Icons must be clearly visible in both macOS light and dark appearance modes.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] The icon uses template image rendering (or provides separate light/dark variants).
  - [ ] When the user switches between light and dark mode, the icon remains clearly visible without app restart.
- **Dependencies**: FR-010, FR-011

### Feature Area: Process Detection

#### FR-013: Periodic Claude Code process polling
- **Description**: The app periodically checks for running `claude` processes.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] The app polls for `claude` processes at a configurable interval (default: 30 seconds).
  - [ ] The polling uses `Process`, `NSRunningApplication`, or `proc_listpids()` -- not shell commands that spawn subprocesses.
  - [ ] The detected count is stored and available for display (FR-015).
- **Dependencies**: None

#### FR-014: Auto-OFF when all Claude Code processes end
- **Description**: If Neverdie mode is ON and all detected Claude Code processes terminate, the mode automatically switches to OFF.
- **Priority**: Must
- **Acceptance Criteria**:
  - [ ] Given Neverdie mode is ON and at least one `claude` process was previously detected, when the next poll finds zero `claude` processes, then Neverdie mode is set to OFF.
  - [ ] The IOPMAssertion is released (per FR-007).
  - [ ] The icon switches to the static OFF state (per FR-010).
  - [ ] If the user manually activated Neverdie mode and no `claude` process was ever detected during this ON session, auto-OFF does NOT trigger (manual override).
- **Dependencies**: FR-013, FR-007, FR-010

#### FR-015: Display process count in popover
- **Description**: When the user hovers over the menu bar icon, a popover shows the number of active Claude Code processes.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] On hover (or mouse-enter on the menu bar icon area), a popover appears.
  - [ ] The popover displays the current Claude Code process count (e.g., "2 active sessions").
  - [ ] The count refreshes on each poll cycle or on popover open.
- **Dependencies**: FR-013

### Feature Area: Token Usage Monitoring

#### FR-016: Collect token usage data
- **Description**: The app reads Claude Code token usage data (Context, Input, Output tokens) from a local data source.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] The app reads token usage from Claude Code's local state file or CLI output.
  - [ ] The data includes at minimum: Context tokens, Input tokens, Output tokens.
  - [ ] If the data source is unavailable, the app gracefully degrades (shows "unavailable") without crashing.
- **Dependencies**: None

#### FR-017: Display token usage in popover
- **Description**: The hover popover displays token usage as three bar graphs with numeric values.
- **Priority**: Should
- **Acceptance Criteria**:
  - [ ] Three horizontal or vertical bar graphs are rendered: Context, Input, Output.
  - [ ] Each bar graph shows a numeric label with the token count.
  - [ ] Bar lengths are proportional to their respective values (or to a known max, e.g., context window size).
- **Dependencies**: FR-016, FR-015

#### FR-018: Per-session token breakdown
- **Description**: When multiple Claude Code sessions are running, token usage is displayed separately per session.
- **Priority**: Could
- **Acceptance Criteria**:
  - [ ] Each detected Claude Code session is listed separately in the popover.
  - [ ] Each session shows its own Context / Input / Output values.
  - [ ] Sessions are distinguishable (e.g., by PID or working directory).
- **Dependencies**: FR-016, FR-017, FR-013

---

## Non-functional Requirements

### NFR-001: Platform compatibility
- **Description**: The app must run on macOS 14 (Sonoma) and later.
- **Measurable target**: Builds and runs without errors on macOS 14.0+. Minimum deployment target set to macOS 14.0 in Xcode project.

### NFR-002: Universal Binary
- **Description**: The app must be distributed as a Universal Binary supporting both Apple Silicon (arm64) and Intel (x86_64).
- **Measurable target**: The built binary contains both architectures, verifiable via `lipo -info`.

### NFR-003: Memory usage
- **Description**: The app must use minimal memory while idle.
- **Measurable target**: Resident memory <= 50 MB when idle (Neverdie OFF, no popover open), measured via Activity Monitor or `footprint`.

### NFR-004: CPU usage
- **Description**: The app must not noticeably consume CPU, even during process polling.
- **Measurable target**: CPU usage < 1% averaged over 60 seconds during polling, measured via Activity Monitor.

### NFR-005: Battery impact
- **Description**: Beyond the intended sleep prevention, the app must not cause additional battery drain.
- **Measurable target**: Energy Impact rated as "Low" in Activity Monitor during normal operation (Neverdie ON, no popover open).

### NFR-006: Code signing
- **Description**: The app must be signed with an Apple Developer ID for distribution outside the App Store and for App Store submission.
- **Measurable target**: `codesign -v` returns valid; Gatekeeper does not block the app on first launch.

### NFR-007: Accessibility (VoiceOver)
- **Description**: The menu bar icon and popover must be accessible via VoiceOver.
- **Measurable target**: VoiceOver announces the current state ("Neverdie ON" / "Neverdie OFF") when the menu bar icon is focused. Popover content is readable by VoiceOver.

### NFR-008: Animation performance
- **Description**: The menu bar icon animation must not cause visible jank or excessive resource use.
- **Measurable target**: Animation renders at the target frame rate (4-8 fps) without dropped frames. No visible flicker on Retina displays.

---

## Out of Scope

- **Clamshell mode** (lid-closed) support -- PRD explicitly excludes this.
- **Windows / Linux** support -- macOS only.
- **Non-Claude-Code process detection** -- the app only monitors `claude` processes.
- **Direct Anthropic API calls** -- the app does NOT call the Anthropic API; it reads local data only.
- **Notifications / sounds** -- no audible or push notification features.
- **Settings/preferences window** -- PRD does not mention a dedicated settings UI. Configuration (e.g., poll interval) is not user-facing in MVP.
- **Automatic updates** -- PRD does not specify an auto-update mechanism. Assumed out of scope for MVP.
- **Network communication** -- the app does not make any network requests.

---

## Assumptions

1. **PRD does not specify the exact Claude Code process name to detect.** Assumed the process name is `claude` (matching via process name string). Verify with stakeholder -- the actual binary name may differ (e.g., `claude-code`, `node` with specific arguments).

2. **PRD does not specify how token usage data is accessed.** Assumed Claude Code writes usage data to a local file (e.g., `~/.claude/` or similar). If no such file exists, the feature (FR-016/FR-017) will degrade gracefully. This is the highest-risk assumption -- data source must be validated during Phase 4 implementation.

3. **PRD does not specify the click interaction model for toggle vs. dropdown.** Assumed: left-click toggles mode, right-click (or Control+click) opens the dropdown menu. Verify with stakeholder.

4. **PRD does not specify whether auto-OFF triggers when the user manually activated Neverdie without any Claude Code process running.** Assumed: auto-OFF only triggers if Claude Code processes were detected during the ON session and subsequently all terminated. Pure manual activation stays ON until manually toggled or the app quits.

5. **PRD does not specify hover behavior on macOS.** macOS menu bar items do not natively support hover popovers. Assumed implementation uses `NSPopover` triggered by mouse-entered event on the status item button, or an alternative approach such as showing info in the dropdown menu. Verify feasibility during implementation.

6. **PRD does not specify a polling interval configuration UI.** Assumed the 30-second default is hardcoded for MVP and may be made configurable in a future release.

7. **PRD lists both Homebrew Cask and App Store as distribution channels.** Assumed both are in scope for Phase 5 but not required for MVP functionality validation.

8. **PRD does not specify behavior when the app is launched but macOS is on AC power vs. battery.** Assumed the app behaves identically regardless of power source.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Claude Code token usage data source does not exist or changes format between versions | High | High | Investigate Claude Code's local file structure early. Design FR-016 with graceful degradation. Treat token monitoring (FR-016/FR-017) as best-effort. |
| Claude Code process name differs from assumed `claude` (e.g., runs as `node` subprocess) | Medium | High | Test with actual Claude Code installation. Support configurable process name matching or match by command-line arguments. |
| macOS menu bar does not support true hover events for popovers | Medium | Medium | Fall back to showing info in the dropdown/click menu instead of a hover popover. Investigate `NSTrackingArea` on status bar button. |
| App Store review rejection due to IOPMAssertion usage or LSUIElement configuration | Medium | Medium | Review Apple's App Store guidelines for power assertion usage. Prepare justification. Homebrew Cask serves as fallback distribution. |
| IOPMAssertion is not released on force-quit / crash | Low | Medium | IOKit typically reclaims assertions when a process dies. Verify this behavior. Document that force-quit is safe. |
| Animation in menu bar causes excessive CPU/energy on older Intel Macs | Low | Low | Profile on Intel hardware. Use Timer-based frame swapping (not Core Animation in menu bar) at low fps (4-8). |
| Apple deprecates IOPMAssertion API in future macOS versions | Low | High | Monitor Apple developer documentation. The API has been stable for 10+ years. Evaluate alternatives if deprecated. |

---

## Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Sleep interruptions during Neverdie ON | 0 occurrences | Automated test: run a long task with Neverdie ON, verify no sleep log entries in `pmset -g log`. |
| App memory usage (idle) | <= 50 MB | `footprint` or Activity Monitor measurement on idle app. |
| Process detection to auto-OFF latency | <= 30 seconds (one poll cycle) | Measure time between last `claude` process termination and Neverdie mode OFF transition. |
| Homebrew Cask install success rate | >= 99% | Track install failure reports on GitHub Issues. |
| App Store review | Pass on first submission | Binary outcome -- first submission accepted. |

---

## Traceability: User Stories to FRs

| User Story | Related FRs |
|-----------|-------------|
| US-001 | FR-001, FR-002, FR-005, FR-007 |
| US-002 | FR-005, FR-006 |
| US-003 | FR-010, FR-011, FR-012 |
| US-004 | FR-013, FR-014 |
| US-005 | FR-013, FR-015 |
| US-006 | FR-016, FR-017 |
| US-007 | FR-003, FR-009 |
| US-008 | FR-004 |
| US-009 | FR-018 |

---

## Confidence Rating: **Medium**

**Reasoning**: The PRD is well-structured with clear functional requirements and priorities. However, two areas introduce meaningful uncertainty:

1. **Token usage data source (FR-016)**: The PRD acknowledges this needs investigation ("Claude Code local state file parsing or CLI output parsing"). Without confirming the data source exists and its format, FR-016/FR-017/FR-018 may need significant redesign or deferral.

2. **Hover popover on macOS menu bar (FR-015/FR-017)**: Standard macOS menu bar items do not natively support hover. The implementation approach needs validation. This may require falling back to a click-based popover or embedding info in the dropdown menu.

All Must-priority requirements are clearly defined and implementable with high confidence. The Medium rating is driven by the Should/Could requirements above.
