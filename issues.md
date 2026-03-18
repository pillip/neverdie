# Neverdie -- Implementation Issues

> Generated: 2026-03-18
> Source: docs/requirements.md, docs/ux_spec.md, docs/architecture.md
> Confidence: **High** -- All Must-priority FRs map to well-understood macOS APIs. No external dependencies. Two medium-risk areas (token data source, hover popover) have documented fallbacks.

---

## Phase 1: MVP (Menu Bar App + Sleep Prevention + Static Icon)

### ISSUE-001: Scaffold Xcode project and configure build settings
- Track: platform
- UI: false
- Manual: false
- PRD-Ref: FR-001, NFR-001, NFR-002
- Priority: P0
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-001-scaffold-xcode
- GH-Issue: https://github.com/pillip/neverdie/issues/1
- PR: https://github.com/pillip/neverdie/pull/2
- Depends-On: none

#### Goal
A buildable Xcode project exists with correct deployment target, Universal Binary, LSUIElement, and SwiftUI MenuBarExtra entry point.

#### Scope (In/Out)
- In: Xcode project creation, macOS 14.0 deployment target, Universal Binary (arm64 + x86_64), Info.plist with LSUIElement=true, NeverdieApp entry point with empty MenuBarExtra, os.Logger setup with subsystem "com.neverdie.app", .xcode-version file, Hardened Runtime enabled
- Out: Any functional features, icon assets, tests beyond build verification

#### Acceptance Criteria (DoD)
- [ ] Given a fresh clone, when the developer runs `xcodebuild build`, then the project compiles without errors for both arm64 and x86_64
- [ ] Given the app is launched, when the user checks the Dock, then no Dock icon is shown (LSUIElement=true verified in Info.plist)
- [ ] Given the app is launched, when the user checks the menu bar, then a placeholder system icon (e.g., "bolt.fill" SF Symbol) appears in the menu bar
- [ ] Given the built binary, when `lipo -info` is run, then both arm64 and x86_64 architectures are listed

#### Implementation Notes
- Create `NeverdieApp.swift` with `@main struct NeverdieApp: App` and `MenuBarExtra` scene
- Use `MenuBarExtra("Neverdie", systemImage: "bolt.fill")` as placeholder
- Set `LSUIElement = YES` (or `Application is agent (UIElement) = YES`) in Info.plist
- Configure os.Logger with categories: `sleep`, `process`, `token`, `ui`, `lifecycle`
- Enable Hardened Runtime in Signing & Capabilities

#### Tests
- [ ] Build succeeds on both architectures (CI verification)
- [ ] Manual verification: app launches, placeholder icon visible in menu bar, no Dock icon

#### Rollback
Delete the Xcode project and re-scaffold.

---

### ISSUE-002: Implement AppState ViewModel with state machine
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-002, FR-014
- Priority: P0
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-002-appstate-viewmodel
- GH-Issue: https://github.com/pillip/neverdie/issues/3
- PR: https://github.com/pillip/neverdie/pull/4
- Depends-On: ISSUE-001

#### Goal
A central `@Observable` AppState class exists with isActive toggle, activation source tracking, state machine for auto-OFF, click debounce, and cleanup method.

#### Scope (In/Out)
- In: AppState class with isActive, activationSource, processCount, tokenUsage, claudeProcessesEverDetected, lastError properties; toggle() with 300ms debounce; cleanup(); ActivationSource enum; state machine transitions; unit tests
- Out: Actual SleepManager/ProcessMonitor/AnimationManager integration (those use protocol stubs), UI wiring

#### Acceptance Criteria (DoD)
- [ ] Given AppState is initialized, when toggle() is called, then isActive flips from false to true (and vice versa)
- [ ] Given toggle() was just called, when toggle() is called again within 300ms, then the second call is ignored and isActive does not change
- [ ] Given isActive is true and claudeProcessesEverDetected is true, when processCount is set to 0, then isActive automatically becomes false
- [ ] Given isActive is true and claudeProcessesEverDetected is false, when processCount is 0, then isActive remains true (manual override)
- [ ] Given cleanup() is called, when checked, then isActive is false and all monitors are stopped (via protocol mock verification)

#### Implementation Notes
- File: `Sources/AppState.swift`
- Use `@Observable` macro (Swift 5.9+, macOS 14+)
- Define protocols `SleepManaging`, `ProcessMonitoring`, `TokenMonitoring` for dependency injection
- Debounce via storing `lastToggleDate` and comparing with 300ms threshold
- State machine: OFF -> ON_MANUAL (toggle, no processes) -> ON_TRACKING (processes detected) -> OFF (auto, all ended)

#### Tests
- [ ] Unit test: toggle flips isActive
- [ ] Unit test: rapid double-toggle within 300ms is debounced
- [ ] Unit test: auto-OFF triggers when claudeProcessesEverDetected=true and processCount drops to 0
- [ ] Unit test: auto-OFF does NOT trigger when claudeProcessesEverDetected=false
- [ ] Unit test: cleanup resets state and calls stop on injected mocks

#### Rollback
Revert the AppState.swift file.

---

### ISSUE-003: Implement SleepManager with IOPMAssertion
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-005, FR-006, FR-007, FR-008, FR-009
- Priority: P0
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-003-sleep-manager
- GH-Issue: https://github.com/pillip/neverdie/issues/5
- PR: https://github.com/pillip/neverdie/pull/6
- Depends-On: ISSUE-001

#### Goal
SleepManager correctly creates and releases IOPMAssertions for system-idle-sleep prevention (not display sleep), with cleanup on termination and signal handling.

#### Scope (In/Out)
- In: SleepManager class implementing SleepManaging protocol, preventSleep() -> Bool, allowSleep(), isAssertionHeld, deinit cleanup, SIGTERM/SIGINT signal handler registration, assertion name "Neverdie - Preventing sleep for Claude Code"
- Out: UI integration, App Delegate wiring (done in integration issue)

#### Acceptance Criteria (DoD)
- [ ] Given preventSleep() is called, when `pmset -g assertions` is checked, then a "Neverdie" assertion of type PreventUserIdleSystemSleep is listed
- [ ] Given preventSleep() is called, when the assertion type is inspected, then it is kIOPMAssertionTypePreventUserIdleSystemSleep (NOT display sleep)
- [ ] Given allowSleep() is called after preventSleep(), when `pmset -g assertions` is checked, then the Neverdie assertion is no longer listed
- [ ] Given allowSleep() is called without a prior preventSleep(), when called, then no error occurs (no-op)
- [ ] Given the SleepManager instance is deallocated while an assertion is held, when deinit runs, then the assertion is released

#### Implementation Notes
- File: `Sources/SleepManager.swift`
- Import IOKit and IOKit.pwr_mgt
- Use `IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleSystemSleep as CFString`
- Store `assertionID: IOPMAssertionID`, check against `kIOPMNullAssertionID`
- Signal handling: use `DispatchSource.makeSignalSource` for SIGTERM and SIGINT, call allowSleep() in handler
- Log with os.Logger category "sleep"

#### Tests
- [ ] Unit test: preventSleep() returns true and sets isAssertionHeld to true
- [ ] Unit test: allowSleep() sets isAssertionHeld to false
- [ ] Unit test: double allowSleep() does not crash
- [ ] Integration test: verify assertion appears in `pmset -g assertions` output (manual or scripted)
- [ ] Unit test: deinit releases held assertion (verify via mock or state check)

#### Rollback
Revert SleepManager.swift. No system state persists after process termination.

---

### ISSUE-004: Create static zombie icon assets and wire OFF state display
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-010, FR-012
- Priority: P0
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-004-static-zombie-icon
- GH-Issue: https://github.com/pillip/neverdie/issues/7
- PR: https://github.com/pillip/neverdie/pull/8
- Depends-On: ISSUE-001

#### Goal
A static sleeping zombie icon displays in the menu bar when Neverdie mode is OFF, with proper template rendering for light/dark mode.

#### Scope (In/Out)
- In: Sleeping zombie icon asset (18x18pt @1x, 36x36pt @2x) in asset catalog, template image rendering (isTemplate=true), MenuBarExtra wired to display the static icon, fallback to "ND" text if asset fails
- Out: Animated frames, ON state icon, transition animations

#### Acceptance Criteria (DoD)
- [ ] Given the app is launched, when mode is OFF, then the menu bar displays a static sleeping zombie icon
- [ ] Given the system is in light mode, when the icon is displayed, then the icon is clearly visible (dark icon on light background)
- [ ] Given the system is in dark mode, when the icon is displayed, then the icon is clearly visible (light icon on dark background)
- [ ] Given the icon asset is missing from the bundle, when the app launches, then a fallback text "ND" is displayed instead of crashing

#### Implementation Notes
- Create `Assets.xcassets/ZombieSleep.imageset` with @1x (18x18) and @2x (36x36) PNG
- Set `Render As: Template Image` in asset catalog
- In NeverdieApp, use `MenuBarExtra` with `Image("ZombieSleep")` or NSStatusItem button image
- For the sleeping zombie design: simple line-art, eyes closed, "Z" near head, monochrome black on transparent
- If using MenuBarExtra(content:label:), set the image on NSStatusItem.button

#### Tests
- [ ] Unit test: ZombieSleep image loads from asset catalog and isTemplate is true
- [ ] Manual test: icon visible and appropriate in both light and dark mode
- [ ] Unit test: fallback to text "ND" when image is nil

#### Rollback
Revert asset catalog changes and icon wiring. Placeholder SF Symbol returns.

---

### ISSUE-005: Wire left-click toggle to AppState and SleepManager
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-002, US-001
- Priority: P0
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-005-toggle-wiring
- GH-Issue: https://github.com/pillip/neverdie/issues/9
- PR: https://github.com/pillip/neverdie/pull/10
- Depends-On: ISSUE-002, ISSUE-003, ISSUE-004

#### Goal
Left-clicking the menu bar icon toggles Neverdie mode, creates/releases the IOPMAssertion, and switches the icon between static OFF and a placeholder ON state.

#### Scope (In/Out)
- In: Left-click handler on NSStatusItem button, AppState.toggle() invocation, SleepManager.preventSleep()/allowSleep() calls from AppState, icon swap between static OFF and a temporary static ON indicator (e.g., filled SF Symbol until animated frames exist), VoiceOver announcements for ON/OFF
- Out: Animation (separate issue), right-click menu, hover popover

#### Acceptance Criteria (DoD)
- [ ] Given mode is OFF, when the user left-clicks the menu bar icon, then mode becomes ON and the icon changes to the ON indicator
- [ ] Given mode is ON, when the user left-clicks the menu bar icon, then mode becomes OFF and the icon returns to the sleeping zombie
- [ ] Given mode transitions to ON, when `pmset -g assertions` is checked, then the Neverdie assertion is present
- [ ] Given mode transitions to OFF, when `pmset -g assertions` is checked, then the Neverdie assertion is absent
- [ ] Given VoiceOver is enabled, when the user toggles mode, then VoiceOver announces "Neverdie ON" or "Neverdie OFF"

#### Implementation Notes
- Use NSStatusItem with custom button action for left-click (cannot use MenuBarExtra's default behavior which shows a menu)
- May need to use AppKit NSStatusItem directly instead of SwiftUI MenuBarExtra to separate left-click (toggle) from right-click (menu)
- Post `NSAccessibility.Notification.announcementRequested` on toggle
- Wire AppState as the owner of SleepManager (inject via protocol)

#### Tests
- [ ] Integration test: left-click toggles isActive state
- [ ] Integration test: assertion state matches isActive
- [ ] Unit test: VoiceOver announcement posted on toggle (verify notification)
- [ ] Unit test: debounce prevents rapid toggling

#### Rollback
Revert click handler wiring. Icon returns to non-interactive placeholder.

---

### ISSUE-006: Implement dropdown menu with Quit and status display
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-003, FR-009, US-007
- Priority: P0
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-006-dropdown-menu
- GH-Issue: https://github.com/pillip/neverdie/issues/13
- PR: https://github.com/pillip/neverdie/pull/14
- Depends-On: ISSUE-005

#### Goal
Right-clicking the menu bar icon opens an NSMenu with status line ("Neverdie: ON/OFF"), separator, and "Quit Neverdie" that performs clean shutdown.

#### Scope (In/Out)
- In: Right-click opens NSMenu, status line item (disabled, informational), "Quit Neverdie" menu item, Quit triggers AppState.cleanup() then NSApplication.terminate, right-click dismisses popover if open
- Out: Launch at Login toggle (separate issue), popover interaction

#### Acceptance Criteria (DoD)
- [ ] Given the app is running, when the user right-clicks the menu bar icon, then a dropdown menu appears with "Neverdie: ON" or "Neverdie: OFF" status and "Quit Neverdie"
- [ ] Given Neverdie mode is ON, when the user selects "Quit Neverdie", then the IOPMAssertion is released and the app terminates
- [ ] Given Neverdie mode is OFF, when the user selects "Quit Neverdie", then the app terminates without attempting assertion release

#### Implementation Notes
- Use NSStatusItem.menu for right-click, or detect right-click via NSEvent and programmatically show NSMenu
- Status line: NSMenuItem with isEnabled=false, title dynamically set from AppState.isActive
- Quit action: call AppState.cleanup() which calls SleepManager.allowSleep(), then NSApplication.shared.terminate(nil)
- Separate left-click (toggle) from right-click (menu) -- this requires custom NSStatusItem button event handling

#### Tests
- [ ] Unit test: menu contains status item and Quit item
- [ ] Integration test: Quit triggers cleanup then terminate
- [ ] Unit test: status line text reflects current isActive state

#### Rollback
Revert menu wiring. Right-click becomes no-op.

---

### ISSUE-007: Handle SIGTERM/SIGINT and applicationWillTerminate cleanup
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-008, FR-009
- Priority: P0
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-007-signal-cleanup
- GH-Issue: https://github.com/pillip/neverdie/issues/11
- PR: https://github.com/pillip/neverdie/pull/12
- Depends-On: ISSUE-003, ISSUE-002

#### Goal
IOPMAssertion is always released when the app terminates, whether via Quit menu, SIGTERM, SIGINT, or normal termination.

#### Scope (In/Out)
- In: DispatchSource signal handlers for SIGTERM and SIGINT, NSApplication delegate applicationWillTerminate callback, all paths call AppState.cleanup(), logging of cleanup events
- Out: Force-kill handling (IOKit reclaims automatically -- documented behavior)

#### Acceptance Criteria (DoD)
- [ ] Given Neverdie mode is ON, when SIGTERM is sent to the process, then the IOPMAssertion is released before the process exits
- [ ] Given Neverdie mode is ON, when SIGINT is sent (Ctrl+C if running from terminal), then the IOPMAssertion is released
- [ ] Given Neverdie mode is ON, when applicationWillTerminate fires, then cleanup is performed
- [ ] Given Neverdie mode is OFF, when any termination signal is received, then no assertion release is attempted and the app exits cleanly

#### Implementation Notes
- File: update SleepManager.swift for signal sources, add AppDelegate or use SwiftUI lifecycle hooks
- Use `signal(SIGTERM, SIG_IGN)` then `DispatchSource.makeSignalSource(signal: SIGTERM)` pattern
- In event handler: call SleepManager.allowSleep(), then exit(0)
- applicationWillTerminate: call AppState.cleanup()
- Log "App terminating, cleanup complete" at .info level

#### Tests
- [ ] Integration test: send SIGTERM to running app, verify assertion released (check pmset)
- [ ] Unit test: cleanup is idempotent (calling twice does not crash)
- [ ] Unit test: cleanup when no assertion held is a no-op

#### Rollback
Revert signal handler and delegate changes.

---

## Phase 2: Personality (Animated Icon + Dark Mode)

### ISSUE-008: Create animated zombie frame assets for ON state
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-011, FR-012
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-008-animated-frames
- GH-Issue: https://github.com/pillip/neverdie/issues/19
- PR: https://github.com/pillip/neverdie/pull/20
- Depends-On: ISSUE-004

#### Goal
A set of animation frame assets (minimum 4 frames) for the ON state zombie exists in the asset catalog as template images.

#### Scope (In/Out)
- In: 4-8 animation frames (18x18pt @1x, 36x36pt @2x) in asset catalog, all as template images, zombie "being shot" loop (alert -> impact -> recoil -> recover), transition frames: wake-up (2 frames), fall-asleep (3 frames), auto-OFF variant (4 frames)
- Out: AnimationManager code (separate issue), runtime animation logic

#### Acceptance Criteria (DoD)
- [ ] Given the asset catalog is inspected, when animation frames are checked, then at least 4 loop frames exist (ZombieOn_01 through ZombieOn_04+)
- [ ] Given any animation frame is loaded, when isTemplate is checked, then it is true
- [ ] Given transition frames exist, when counted, then wake-up has 2, fall-asleep has 3, auto-OFF has 4 frames
- [ ] Given the frames are viewed in both light and dark mode (asset catalog preview), then all frames are clearly visible

#### Implementation Notes
- Asset naming: `ZombieOn_01`, `ZombieOn_02`, ..., `ZombieWake_01`, `ZombieWake_02`, `ZombieSleep_01`, `ZombieSleep_02`, `ZombieSleep_03`, `ZombieAutoOff_01`...`ZombieAutoOff_04`
- Style: simple line-art, monochrome black on transparent, "cute undead" not horror
- Each frame: 18x18pt canvas, @2x at 36x36
- Template rendering: set in asset catalog, Render As: Template Image

#### Tests
- [ ] Unit test: all expected frame images load from asset catalog without nil
- [ ] Unit test: all loaded images have isTemplate == true

#### Rollback
Remove animation frame assets from asset catalog.

---

### ISSUE-009: Implement AnimationManager with frame cycling
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-011, FR-012, NFR-008
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-009-animation-manager
- GH-Issue: https://github.com/pillip/neverdie/issues/29
- PR: https://github.com/pillip/neverdie/pull/32
- Depends-On: ISSUE-008

#### Goal
AnimationManager loads frames, cycles through them at 6fps via Timer, provides currentFrame, and supports start/stop/transition animations.

#### Scope (In/Out)
- In: AnimationManager class, pre-load all frames at init, Timer at ~166ms (6fps) with 50ms tolerance, currentFrame property, startAnimation/stopAnimation, playTransition(type:completion:) for wake-up/fall-asleep/auto-OFF, reduced motion support (static frame when accessibility preference set), fallback to SF Symbol if assets missing
- Out: Wiring to NSStatusItem (done in integration issue)

#### Acceptance Criteria (DoD)
- [ ] Given startAnimation() is called, when the timer fires, then currentFrame cycles through loop frames sequentially
- [ ] Given stopAnimation() is called, when checked, then the timer is invalidated and currentFrame returns the static OFF icon
- [ ] Given reduced motion is enabled, when startAnimation() is called, then currentFrame returns a single static ON frame (no cycling)
- [ ] Given playTransition(.wakeUp) is called, when complete, then the wake-up frames play in order before entering the main loop

#### Implementation Notes
- File: `Sources/AnimationManager.swift`
- Pre-load frames into `[NSImage]` array at init to avoid per-frame I/O
- Timer: `Timer.scheduledTimer(withTimeInterval: 1.0/6.0, repeats: true)` with `tolerance = 0.05`
- Check `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` for reduced motion
- Observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` to react to preference changes
- Fallback: if any frame is nil, use `NSImage(systemSymbolName: "bolt.fill")`

#### Tests
- [ ] Unit test: startAnimation begins timer, currentFrame changes over time
- [ ] Unit test: stopAnimation invalidates timer
- [ ] Unit test: reduced motion returns static frame
- [ ] Unit test: transition plays correct number of frames before entering loop
- [ ] Unit test: fallback icon returned when assets are nil

#### Rollback
Revert AnimationManager.swift. Icon falls back to static display.

---

### ISSUE-010: Wire AnimationManager to menu bar icon with state transitions
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-010, FR-011, FR-012, US-003
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-010-anim-wiring
- GH-Issue: https://github.com/pillip/neverdie/issues/35
- PR: https://github.com/pillip/neverdie/pull/37
- Depends-On: ISSUE-009, ISSUE-005

#### Goal
The menu bar icon animates in the ON state and shows a static sleeping zombie in the OFF state, with smooth transition animations between states.

#### Scope (In/Out)
- In: Wire AnimationManager.currentFrame to NSStatusItem.button.image, trigger startAnimation on toggle ON, trigger stopAnimation on toggle OFF, play wake-up transition (OFF->ON), play fall-asleep transition (ON->OFF manual), play auto-OFF transition (ON->OFF auto), app launch fade-in (200ms opacity)
- Out: Popover, dropdown menu changes

#### Acceptance Criteria (DoD)
- [ ] Given mode is OFF, when the user clicks to toggle ON, then the wake-up transition plays followed by the main animation loop
- [ ] Given mode is ON, when the user clicks to toggle OFF, then the fall-asleep transition plays and the icon settles to the static sleeping zombie
- [ ] Given auto-OFF triggers, when mode switches to OFF, then the auto-OFF transition plays (longer, 4 frames)
- [ ] Given the app launches, when the icon appears, then it fades in over ~200ms

#### Implementation Notes
- AnimationManager publishes currentFrame; observe it and set `statusItem.button?.image = currentFrame`
- Use KVO or Combine/observation to react to AnimationManager.currentFrame changes
- For app launch fade-in: animate statusItem.button.alphaValue from 0 to 1 over 200ms using NSAnimationContext
- Connect AppState toggle to AnimationManager via the existing protocol/injection

#### Tests
- [ ] Integration test: toggling ON starts animation (frame changes observed)
- [ ] Integration test: toggling OFF stops animation and shows static icon
- [ ] Manual test: transitions are visually smooth in both light and dark mode
- [ ] Unit test: auto-OFF uses the correct transition type

#### Rollback
Revert wiring. Static icon for both states.

---

## Phase 3: Intelligence (Process Detection + Auto-OFF)

### ISSUE-011: Implement ProcessMonitor with proc_listpids
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-013, NFR-004
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-011-process-monitor
- GH-Issue: https://github.com/pillip/neverdie/issues/15
- PR: https://github.com/pillip/neverdie/pull/16
- Depends-On: ISSUE-001

#### Goal
ProcessMonitor polls the system process table every 30 seconds using libproc APIs, returning the count of running Claude Code processes.

#### Scope (In/Out)
- In: ProcessMonitor class implementing ProcessMonitoring protocol, pollOnce() -> Int, startPolling(onUpdate:), stopPolling(), configurable process name match list (default: ["claude", "claude-code"]), Timer-based polling at 30s, logging at debug level
- Out: Auto-OFF logic (handled by AppState), UI display

#### Acceptance Criteria (DoD)
- [ ] Given a `claude` process is running on the system, when pollOnce() is called, then it returns a count >= 1
- [ ] Given no `claude` processes are running, when pollOnce() is called, then it returns 0
- [ ] Given startPolling is called, when 30 seconds elapse, then the onUpdate callback fires with the current count
- [ ] Given stopPolling is called, when checked, then the timer is invalidated and no further callbacks fire

#### Implementation Notes
- File: `Sources/ProcessMonitor.swift`
- Import Darwin (for proc_listallpids, proc_name)
- `proc_listallpids(nil, 0)` to get buffer size, allocate buffer, `proc_listallpids(&buffer, bufferSize)`
- For each PID: `proc_name(pid, &nameBuffer, UInt32(MAXCOMNAME))`, compare with match list
- Timer: `Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true)`
- Process name match: case-insensitive prefix match to handle variants
- Log: "Process poll: %d claude processes found" at .debug

#### Tests
- [ ] Unit test: pollOnce with mocked proc calls returns correct count
- [ ] Unit test: startPolling fires callback on timer tick
- [ ] Unit test: stopPolling invalidates timer
- [ ] Integration test: with a real process named "claude" running, pollOnce detects it (manual test)

#### Rollback
Revert ProcessMonitor.swift. Process count remains at 0.

---

### ISSUE-012: Wire ProcessMonitor to AppState for auto-OFF
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-014, US-004
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-012-auto-off-wiring
- GH-Issue: https://github.com/pillip/neverdie/issues/21
- PR: https://github.com/pillip/neverdie/pull/22
- Depends-On: ISSUE-011, ISSUE-002

#### Goal
AppState receives process count updates from ProcessMonitor and triggers auto-OFF when all Claude processes end (with everDetected guard).

#### Scope (In/Out)
- In: Wire ProcessMonitor callback to AppState.processCount, auto-OFF logic in AppState triggered by processCount changes, VoiceOver announcement "Neverdie OFF -- all sessions ended" on auto-OFF, logging of auto-OFF events
- Out: UI display of process count (popover issue)

#### Acceptance Criteria (DoD)
- [ ] Given mode is ON and a claude process was detected, when the next poll finds 0 processes, then mode auto-switches to OFF
- [ ] Given mode is ON but no claude process was ever detected, when poll finds 0 processes, then mode remains ON
- [ ] Given auto-OFF triggers, when checked, then the IOPMAssertion is released and the animation stops
- [ ] Given VoiceOver is enabled, when auto-OFF triggers, then "Neverdie OFF -- all sessions ended" is announced

#### Implementation Notes
- In AppState, inject ProcessMonitor and start polling when mode goes ON
- onUpdate callback: update processCount, if > 0 set claudeProcessesEverDetected=true, if == 0 and everDetected then auto-deactivate
- Stop polling when mode goes OFF (save resources)
- Auto-OFF calls the same deactivation path as manual toggle OFF

#### Tests
- [ ] Unit test: processCount update with count>0 sets claudeProcessesEverDetected
- [ ] Unit test: processCount drops to 0 with everDetected=true triggers deactivation
- [ ] Unit test: processCount 0 with everDetected=false does not deactivate
- [ ] Unit test: VoiceOver announcement posted on auto-OFF

#### Rollback
Revert wiring. Auto-OFF disabled, manual toggle still works.

---

## Phase 4: Monitoring (Popover + Token Usage)

### ISSUE-013: Implement hover popover shell with NSTrackingArea
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-015, US-005
- Priority: P1
- Estimate: 1.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-013-hover-popover
- GH-Issue: https://github.com/pillip/neverdie/issues/25
- PR: https://github.com/pillip/neverdie/pull/26
- Depends-On: ISSUE-005

#### Goal
Hovering over the menu bar icon shows an NSPopover with process count; moving the mouse away dismisses it. If hover is unreliable, fallback to click-based popover.

#### Scope (In/Out)
- In: NSTrackingArea on NSStatusItem button, 200ms hover delay before showing, 100ms grace period before dismissing, NSPopover with SwiftUI PopoverView hosted inside, process count display ("{N} active sessions" / "No active sessions"), popover width ~240pt, accessibility label on popover content, fallback to click-based popover if hover fails
- Out: Token bar graphs (next issue), per-session breakdown

#### Acceptance Criteria (DoD)
- [ ] Given mode is ON and 2 processes running, when the user hovers over the menu bar icon for 200ms, then a popover appears showing "2 active sessions"
- [ ] Given the popover is visible, when the mouse exits the popover area (after 100ms grace), then the popover dismisses
- [ ] Given no processes are running, when the popover opens, then it shows "No active sessions"
- [ ] Given VoiceOver is active, when the popover opens, then VoiceOver reads the popover content

#### Implementation Notes
- Subclass or extend the NSStatusItem button to add NSTrackingArea with mouseEntered/mouseExited
- Use NSPopover with NSHostingView wrapping a SwiftUI PopoverView
- PopoverView observes AppState.processCount
- Hover delay: DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
- Grace period: delay dismissal by 100ms, cancel if mouse re-enters
- If NSTrackingArea on NSStatusItem is unreliable: switch to left-click showing popover (with toggle button inside)
- Popover should not steal keyboard focus

#### Tests
- [ ] Unit test: PopoverView renders correct text for processCount=0, 1, N
- [ ] Unit test: PopoverView uses singular "session" for count=1
- [ ] Integration test: popover appears on hover (manual verification on macOS)
- [ ] Unit test: accessibility label contains process count text

#### Rollback
Revert popover and tracking area code. Hover becomes no-op.

---

### ISSUE-014: Implement TokenMonitor for local file parsing
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-016, US-006
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-014-token-monitor
- GH-Issue: https://github.com/pillip/neverdie/issues/17
- PR: https://github.com/pillip/neverdie/pull/18
- Depends-On: ISSUE-001

#### Goal
TokenMonitor reads Claude Code token usage (Context, Input, Output) from local files under ~/.claude/, returning structured data or nil on failure.

#### Scope (In/Out)
- In: TokenMonitor class implementing TokenMonitoring protocol, readUsage() -> TokenUsage?, scan ~/.claude/projects/ for JSON files, parse token data, graceful degradation (return nil if files missing/malformed), logging at .info for missing data
- Out: Per-session breakdown (P2), popover UI

#### Acceptance Criteria (DoD)
- [ ] Given Claude Code session files exist at ~/.claude/projects/*, when readUsage() is called, then it returns a TokenUsage with context, input, and output values
- [ ] Given no files exist at ~/.claude/, when readUsage() is called, then it returns nil without crashing
- [ ] Given a malformed JSON file exists, when readUsage() is called, then it returns nil and logs at .info level
- [ ] Given permission is denied on the directory, when readUsage() is called, then it returns nil without crashing

#### Implementation Notes
- File: `Sources/TokenMonitor.swift`
- Scan `~/.claude/projects/` using FileManager.default.contentsOfDirectory
- Look for JSON files with token usage data (exact schema TBD -- design for flexibility)
- Use JSONDecoder with lenient parsing (ignore unknown keys)
- TokenUsage struct: context: Int, input: Int, output: Int
- No polling timer -- read on-demand when popover opens
- This is the highest-risk feature: Claude Code file format may change. Design for graceful degradation first.

#### Tests
- [ ] Unit test: parse valid JSON fixture returns correct TokenUsage
- [ ] Unit test: missing directory returns nil
- [ ] Unit test: malformed JSON returns nil
- [ ] Unit test: empty directory returns nil
- [ ] Unit test: permission error returns nil (mock FileManager)

#### Rollback
Revert TokenMonitor.swift. Token data shows "unavailable" in popover.

---

### ISSUE-015: Add token usage bar graphs to popover
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-017, US-006
- Priority: P1
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-015-token-bars
- GH-Issue: https://github.com/pillip/neverdie/issues/28
- PR: https://github.com/pillip/neverdie/pull/33
- Depends-On: ISSUE-013, ISSUE-014

#### Goal
The hover popover displays three horizontal bar graphs (Context, Input, Output) with abbreviated numeric values, or "Token data unavailable" when data is nil.

#### Scope (In/Out)
- In: Token usage section in PopoverView with three horizontal bars, labels ("Context", "Input", "Output"), abbreviated values (45.2K, 1.2M format), bar proportional to value, "Token data unavailable" fallback, loading skeleton placeholder, system colors for contrast, accessibility labels on each bar
- Out: Per-session breakdown (P2)

#### Acceptance Criteria (DoD)
- [ ] Given token data is available, when the popover opens, then three bar graphs display with labels and numeric values
- [ ] Given token data is unavailable (nil), when the popover opens, then "Token data unavailable" text is shown instead of bar graphs
- [ ] Given a token value of 45200, when displayed, then it shows as "45.2K"
- [ ] Given a token value of 1200000, when displayed, then it shows as "1.2M"
- [ ] Given VoiceOver is active, when the popover opens, then each bar's label and value are read aloud

#### Implementation Notes
- Add TokenBarView SwiftUI component: horizontal bar with label, fill proportional to value/max, numeric label
- Number formatting: < 1000 -> exact, 1000-999999 -> "X.XK", >= 1000000 -> "X.XM"
- Bar fill color: use system accent color or a distinct color with >= 3:1 contrast
- Max value for bar proportion: use context window size as reference (e.g., 200K) or max of the three values
- Accessibility: `accessibilityLabel("Context: 45.2K tokens")` on each bar

#### Tests
- [ ] Unit test: number formatter produces "45.2K" for 45200
- [ ] Unit test: number formatter produces "1.2M" for 1200000
- [ ] Unit test: number formatter produces "999" for 999
- [ ] Unit test: PopoverView shows "Token data unavailable" when tokenUsage is nil
- [ ] Snapshot/preview test: bar graphs render with sample data

#### Rollback
Revert token UI changes. Popover shows only process count.

---

### ISSUE-016: Add Launch at Login toggle to dropdown menu
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-004, US-008
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-016-launch-at-login
- GH-Issue: https://github.com/pillip/neverdie/issues/27
- PR: https://github.com/pillip/neverdie/pull/30
- Depends-On: ISSUE-006

#### Goal
The dropdown menu includes a "Launch at Login" toggle that registers/unregisters the app as a login item via SMAppService.

#### Scope (In/Out)
- In: "Launch at Login" NSMenuItem with checkmark state, SMAppService.mainApp.register()/unregister() calls, persist state via SMAppService (system-managed), error handling with NSAlert on failure, query current state on menu open
- Out: Other preferences, settings window

#### Acceptance Criteria (DoD)
- [ ] Given the dropdown menu is open, when the user sees "Launch at Login", then a checkmark indicates the current registration state
- [ ] Given the user clicks "Launch at Login" (unchecked), when SMAppService registers successfully, then a checkmark appears
- [ ] Given the user clicks "Launch at Login" (checked), when SMAppService unregisters, then the checkmark disappears
- [ ] Given SMAppService registration fails, when the user clicks the toggle, then an NSAlert displays "Could not enable Launch at Login"

#### Implementation Notes
- Use `SMAppService.mainApp` (macOS 13+)
- Query status: `SMAppService.mainApp.status` returns .enabled/.notRegistered/etc.
- Register: `try SMAppService.mainApp.register()`
- Unregister: `try SMAppService.mainApp.unregister()`
- Menu item state: .on (checkmark) or .off based on status query
- Error handling: catch and show NSAlert

#### Tests
- [ ] Unit test: menu item state reflects SMAppService status (mock)
- [ ] Unit test: registration error triggers alert (mock)
- [ ] Integration test: toggle registers/unregisters (manual verification on macOS)

#### Rollback
Remove Launch at Login menu item. Feature disabled, no system side effects.

---

## Phase 4.5: Polish

### ISSUE-017: Add error state handling and error indicator overlay
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-005 (error path), US-001 (error path)
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-017-error-states
- GH-Issue: https://github.com/pillip/neverdie/issues/31
- PR: https://github.com/pillip/neverdie/pull/34
- Depends-On: ISSUE-005, ISSUE-006

#### Goal
When IOPMAssertion creation fails or process detection fails, the UI shows an error indicator (red dot overlay) and the dropdown status reflects the error.

#### Scope (In/Out)
- In: AppState.lastError property, red dot overlay (2x2pt) on icon when error exists, error pulse animation (2 pulses then solid), dropdown status shows "Neverdie: Error -- could not prevent sleep", VoiceOver announces error, error clears on next successful toggle
- Out: Network errors (none exist), token errors (handled separately as "unavailable")

#### Acceptance Criteria (DoD)
- [ ] Given IOPMAssertion creation fails, when toggle is attempted, then mode remains OFF and a red dot appears on the icon
- [ ] Given an error is active, when the dropdown menu is opened, then status reads "Neverdie: Error -- could not prevent sleep"
- [ ] Given an error is active and VoiceOver is on, when the icon is focused, then "Neverdie error" is announced
- [ ] Given an error is active, when the user successfully toggles ON, then the error clears

#### Implementation Notes
- Add `lastError: NeverdieError?` to AppState
- NeverdieError enum: .assertionFailed, .processDetectionFailed
- Red dot: draw a 2x2pt red circle in the bottom-right of the icon image (composite image)
- Error pulse: 2x opacity animation on the red dot, then solid
- Check `NSColor.systemRed` for the dot

#### Tests
- [ ] Unit test: failed preventSleep sets lastError
- [ ] Unit test: successful toggle clears lastError
- [ ] Unit test: error state reflected in menu status text
- [ ] Unit test: VoiceOver label includes error text

#### Rollback
Revert error handling UI. Errors logged but not visually indicated.

---

### ISSUE-018: Add single-instance guard
- Track: product
- UI: false
- Manual: false
- PRD-Ref: Flow 6 (UX Spec)
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-018-single-instance
- GH-Issue: https://github.com/pillip/neverdie/issues/23
- PR: https://github.com/pillip/neverdie/pull/24
- Depends-On: ISSUE-001

#### Goal
If Neverdie is already running and the user launches a second instance, the second instance quits immediately.

#### Scope (In/Out)
- In: Check NSRunningApplication for existing Neverdie instance at launch, quit second instance silently if first exists
- Out: Bringing focus to the existing instance (menu bar items cannot be focused programmatically)

#### Acceptance Criteria (DoD)
- [ ] Given Neverdie is already running, when the user launches a second instance, then the second instance quits within 1 second
- [ ] Given Neverdie is not running, when the user launches it, then it starts normally

#### Implementation Notes
- At app init: `NSRunningApplication.runningApplications(withBundleIdentifier: "com.neverdie.app")`
- If count > 1 (self + existing): `NSApplication.shared.terminate(nil)`
- Place this check in NeverdieApp.init or applicationDidFinishLaunching

#### Tests
- [ ] Unit test: detection logic correctly identifies duplicate (mock)
- [ ] Integration test: launch two instances, second one quits (manual)

#### Rollback
Remove guard. Multiple instances can run (harmless but wasteful).

---

### ISSUE-019: Implement accessibility labels and keyboard navigation
- Track: product
- UI: true
- Manual: false
- PRD-Ref: NFR-007
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-019-accessibility
- GH-Issue: https://github.com/pillip/neverdie/issues/39
- PR: https://github.com/pillip/neverdie/pull/40
- Depends-On: ISSUE-010, ISSUE-013, ISSUE-006

#### Goal
All UI elements have proper VoiceOver labels, and keyboard navigation (Space/Enter on focused status item triggers toggle) works correctly.

#### Scope (In/Out)
- In: accessibilityLabel on status item button ("Neverdie -- sleep prevention ON/OFF"), accessibilityLabel on popover content, Space/Enter triggers toggle when status item focused, all menu items accessible (native NSMenu), Localizable.strings file with all user-facing strings
- Out: Full localization (English only for V1)

#### Acceptance Criteria (DoD)
- [ ] Given VoiceOver is enabled, when the status item is focused, then VoiceOver reads "Neverdie -- sleep prevention [ON/OFF]"
- [ ] Given the status item has keyboard focus, when Space is pressed, then Neverdie mode toggles
- [ ] Given the popover is open with VoiceOver, when the content is read, then process count and token values are announced
- [ ] Given all user-facing strings, when Localizable.strings is checked, then all strings are externalized

#### Implementation Notes
- Set `statusItem.button?.accessibilityLabel` dynamically based on AppState.isActive
- Update label on every state change
- Space/Enter: NSStatusItem button already responds to keyboard activation when focused
- Create `Localizable.strings` with all strings from UX Spec copy guidelines
- Use `NSLocalizedString("key", comment:)` for all user-facing text

#### Tests
- [ ] Unit test: accessibility label changes with state
- [ ] Unit test: all expected keys exist in Localizable.strings
- [ ] Manual test: VoiceOver navigation through all UI elements

#### Rollback
Revert accessibility additions. Basic functionality unchanged.

---

## Phase 5: Distribution (P2)

### ISSUE-020: Provision Apple Developer ID certificate and configure code signing
- Track: platform
- UI: false
- Manual: true
- PRD-Ref: NFR-006
- Priority: P2
- Estimate: 0.5d
- Status: done
- Owner:
- Branch:
- GH-Issue:
- PR:
- Depends-On: none

#### Goal
A valid Apple Developer ID certificate is provisioned and configured for code signing and notarization.

#### Scope (In/Out)
- In: Apple Developer Program membership active, Developer ID Application certificate created, Developer ID stored in Keychain, Xcode project configured with signing team, Notarization credentials (app-specific password or API key) configured
- Out: CI/CD pipeline (separate issue), Homebrew formula

#### Acceptance Criteria (DoD)
- [ ] Given the Xcode project, when Archive + Export is run, then the app is signed with Developer ID
- [ ] Given the signed app, when `codesign -v Neverdie.app` is run, then it reports valid

#### Implementation Notes
- Requires active Apple Developer Program membership ($99/year)
- Create certificate at developer.apple.com > Certificates
- Download and install in Keychain Access
- Set signing team in Xcode project settings
- For notarization: create app-specific password at appleid.apple.com or use App Store Connect API key

#### Tests
- [ ] Manual: codesign -v validates the signed app
- [ ] Manual: Gatekeeper does not block app on first launch

#### Rollback
Use ad-hoc signing for development. Distribution blocked until resolved.

---

### ISSUE-021: Set up CI/CD pipeline with GitHub Actions
- Track: platform
- UI: false
- Manual: false
- PRD-Ref: NFR-002, NFR-006
- Priority: P2
- Estimate: 1d
- Status: done
- Owner:
- Branch: issue/ISSUE-021-cicd-pipeline
- GH-Issue: https://github.com/pillip/neverdie/issues/41
- PR: https://github.com/pillip/neverdie/pull/42
- Depends-On: ISSUE-020, ISSUE-001

#### Goal
A GitHub Actions workflow builds, signs, notarizes, and creates a .dmg on tagged releases.

#### Scope (In/Out)
- In: GitHub Actions workflow file (.github/workflows/release.yml), macOS runner (macos-14), xcodebuild archive + export, notarytool submit + staple, create-dmg packaging, SHA256 hash computation, upload .dmg as release artifact
- Out: Homebrew Cask formula update (separate), App Store submission

#### Acceptance Criteria (DoD)
- [ ] Given a tag `v*` is pushed, when the workflow runs, then a notarized .dmg is uploaded as a GitHub Release artifact
- [ ] Given the workflow output, when the .dmg is downloaded and opened, then Gatekeeper allows installation without warning

#### Implementation Notes
- Use `macos-14` runner for Xcode 15+ with macOS 14 SDK
- Store signing certificate and notarization credentials as GitHub Secrets
- Steps: checkout, xcodebuild archive, export, notarytool, stapler, create-dmg, upload
- create-dmg: use `create-dmg` CLI tool or `hdiutil create`
- SHA256: `shasum -a 256 Neverdie.dmg`

#### Tests
- [ ] CI test: workflow completes successfully on a tagged push
- [ ] Manual: downloaded .dmg installs and runs correctly

#### Rollback
Revert workflow file. Manual builds remain possible via Xcode.

---

### ISSUE-022: Create Homebrew Cask formula
- Track: platform
- UI: false
- Manual: false
- PRD-Ref: Phase 5 (Distribution)
- Priority: P2
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-022-homebrew-cask
- GH-Issue: https://github.com/pillip/neverdie/issues/43
- PR: https://github.com/pillip/neverdie/pull/44
- Depends-On: ISSUE-021

#### Goal
A Homebrew Cask formula exists that allows users to install Neverdie via `brew install --cask neverdie`.

#### Scope (In/Out)
- In: Cask formula Ruby file (neverdie.rb), references GitHub Release .dmg URL, SHA256 hash, app name, caveats
- Out: Homebrew tap hosting (if using custom tap), App Store submission

#### Acceptance Criteria (DoD)
- [ ] Given the formula is installed, when `brew install --cask neverdie` is run, then Neverdie.app is installed to /Applications
- [ ] Given a new version is released, when the formula is updated with new URL and SHA256, then `brew upgrade --cask neverdie` installs the new version

#### Implementation Notes
- Create `Cask/neverdie.rb` or submit to homebrew-cask
- Formula: `cask "neverdie" do ... version, sha256, url, name, homepage, app "Neverdie.app" end`
- For initial development: use a custom tap (homebrew-neverdie)
- Later: submit PR to homebrew/homebrew-cask for wider distribution

#### Tests
- [ ] Manual: `brew install --cask neverdie` from tap succeeds
- [ ] Manual: installed app launches and functions correctly

#### Rollback
Remove formula. Direct .dmg download remains available.

---

### ISSUE-023: Implement per-session token breakdown in popover (P2)
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-018, US-009
- Priority: P2
- Estimate: 1.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-023-per-session-tokens
- GH-Issue: https://github.com/pillip/neverdie/issues/36
- PR: https://github.com/pillip/neverdie/pull/38
- Depends-On: ISSUE-015, ISSUE-014

#### Goal
When multiple Claude Code sessions are running, the popover shows per-session token usage with collapsible sections identified by working directory or PID.

#### Scope (In/Out)
- In: TokenMonitor.readPerSessionUsage() returning [SessionTokenUsage], popover UI with collapsible sections per session, session label (working directory or PID), per-session bar graphs, max-height with scroll for 3+ sessions, first session expanded by default
- Out: Real-time updates (on-demand only)

#### Acceptance Criteria (DoD)
- [ ] Given 2+ Claude Code sessions are running, when the popover opens, then each session is listed separately with its own token bars
- [ ] Given 3+ sessions, when the popover opens, then the content scrolls (max height enforced)
- [ ] Given the first session, when the popover opens, then it is expanded by default and others are collapsed
- [ ] Given a session, when its label is inspected, then it shows the working directory (or PID as fallback)

#### Implementation Notes
- Extend TokenMonitor with readPerSessionUsage() -> [SessionTokenUsage]
- SessionTokenUsage: id (String), label (String from working dir), usage (TokenUsage)
- Popover: use DisclosureGroup for collapsible sections
- Max height: ~400pt with ScrollView
- Parse session data from separate files/directories under ~/.claude/projects/

#### Tests
- [ ] Unit test: readPerSessionUsage parses multiple session fixtures
- [ ] Unit test: PopoverView renders multiple sessions with collapse
- [ ] Unit test: session label shows working directory
- [ ] Unit test: scroll appears for 3+ sessions

#### Rollback
Revert per-session UI. Aggregate token view remains.

---

## Dependency Graph

```
ISSUE-001 (Scaffold)
  |
  +-- ISSUE-002 (AppState) -------+-- ISSUE-005 (Toggle wiring) --+-- ISSUE-006 (Dropdown menu) -- ISSUE-016 (Launch at Login)
  |                               |                                |
  +-- ISSUE-003 (SleepManager) ---+                                +-- ISSUE-007 (Signal cleanup)
  |                                                                |
  +-- ISSUE-004 (Static icon) -- ISSUE-008 (Anim assets) -- ISSUE-009 (AnimationMgr) -- ISSUE-010 (Anim wiring)
  |                                                                |
  +-- ISSUE-011 (ProcessMonitor) -- ISSUE-012 (Auto-OFF wiring)   |
  |                                                                |
  +-- ISSUE-014 (TokenMonitor)                                     +-- ISSUE-013 (Popover shell)
  |                                                                |
  +-- ISSUE-018 (Single instance)                                  +-- ISSUE-015 (Token bars) -- ISSUE-023 (Per-session P2)
                                                                   |
                                                                   +-- ISSUE-017 (Error states)
                                                                   |
                                                                   +-- ISSUE-019 (Accessibility)

ISSUE-020 (Developer ID - Manual) -- ISSUE-021 (CI/CD) -- ISSUE-022 (Homebrew)
```

### Parallel Work Opportunities
- ISSUE-002, ISSUE-003, ISSUE-004, ISSUE-011, ISSUE-014, ISSUE-018 can ALL proceed in parallel after ISSUE-001
- ISSUE-008 (animation assets) can proceed independently alongside backend work
- ISSUE-020 (manual setup) can proceed at any time, only blocks ISSUE-021 (CI/CD)

### Critical Path
ISSUE-001 -> ISSUE-002 + ISSUE-003 -> ISSUE-005 -> ISSUE-006 -> ISSUE-007 (Phase 1 complete)
                                    -> ISSUE-010 (Phase 2 complete, with ISSUE-004 -> 008 -> 009 parallel track)
                                    -> ISSUE-012 (Phase 3 complete, with ISSUE-011 parallel track)
                                    -> ISSUE-013 -> ISSUE-015 (Phase 4 complete, with ISSUE-014 parallel track)

---

## Summary

| Phase | Issues | Total Estimate |
|-------|--------|---------------|
| Phase 1: MVP | ISSUE-001 through ISSUE-007 | 5d |
| Phase 2: Personality | ISSUE-008 through ISSUE-010 | 3d |
| Phase 3: Intelligence | ISSUE-011, ISSUE-012 | 1.5d |
| Phase 4: Monitoring | ISSUE-013 through ISSUE-016 | 4d |
| Phase 4.5: Polish | ISSUE-017 through ISSUE-019 | 1.5d |
| Phase 5: Distribution | ISSUE-020 through ISSUE-023 | 3.5d |
| **Total** | **23 issues** | **18.5d** |

### FR/US Coverage Traceability

| Requirement | Issue(s) |
|-------------|----------|
| FR-001 | ISSUE-001, ISSUE-004 |
| FR-002 | ISSUE-002, ISSUE-005 |
| FR-003 | ISSUE-006 |
| FR-004 | ISSUE-016 |
| FR-005 | ISSUE-003 |
| FR-006 | ISSUE-003 |
| FR-007 | ISSUE-003 |
| FR-008 | ISSUE-007 |
| FR-009 | ISSUE-006, ISSUE-007 |
| FR-010 | ISSUE-004, ISSUE-010 |
| FR-011 | ISSUE-008, ISSUE-009, ISSUE-010 |
| FR-012 | ISSUE-004, ISSUE-008 |
| FR-013 | ISSUE-011 |
| FR-014 | ISSUE-012 |
| FR-015 | ISSUE-013 |
| FR-016 | ISSUE-014 |
| FR-017 | ISSUE-015 |
| FR-018 | ISSUE-023 |
| US-001 | ISSUE-005 |
| US-002 | ISSUE-003 |
| US-003 | ISSUE-010 |
| US-004 | ISSUE-012 |
| US-005 | ISSUE-013 |
| US-006 | ISSUE-015 |
| US-007 | ISSUE-006 |
| US-008 | ISSUE-016 |
| US-009 | ISSUE-023 |
| NFR-006 | ISSUE-020, ISSUE-021 |
| NFR-007 | ISSUE-019 |
