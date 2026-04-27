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

### ISSUE-024: Release sleep assertion on clamshell close when on battery power
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-019, NFR-005
- Priority: P0
- Estimate: 1.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-024-clamshell-battery-handling
- GH-Issue: https://github.com/pillip/neverdie/issues/45
- PR: https://github.com/pillip/neverdie/pull/46
- Depends-On: ISSUE-002, ISSUE-003

#### Goal
On battery power, Neverdie must release its `IOPMAssertionTypePreventUserIdleSystemSleep` assertion whenever the MacBook lid is closed, so macOS can enter clamshell sleep and stop draining the battery. On AC power, existing behavior is preserved (assertion held, clamshell with external display keeps working). The user's intent (`AppState.isActive == true`) is never lost -- the assertion is automatically re-acquired on lid open, or when AC power is reconnected while the lid is still closed.

#### Scope (In/Out)
- In: New `ClamshellObserver` module wrapping `IOServiceAddInterestNotification` on `IOPMrootDomain` / `AppleClamshellState`; new `PowerSourceMonitor` module wrapping `IOPSNotificationCreateRunLoopSource`; AppState substate (e.g., `isPausedDueToClamshell`) that keeps `isActive == true` while the assertion is released; coordination logic that suspends/resumes the assertion on every (lid x power-source) transition; wiring from `NeverdieApp` AppDelegate; unit tests with protocol-based fakes; manual verification matrix; VoiceOver announcement for the paused substate.
- Out: Any attempt to KEEP the system awake while the lid is closed on battery (that remains explicitly out of scope per PRD "Clamshell mode" exclusion); new UI affordances beyond the existing status line + VoiceOver; user-configurable overrides; power-source-aware behavior for features other than sleep assertion (animation, polling, token reads).

#### Acceptance Criteria (DoD)
- [ ] Given `isActive == true` and power source is battery, when the lid closes, then `SleepManager.allowSleep()` is called, the IOPMAssertion is released (verifiable via `pmset -g assertions`), and `AppState.isActive` remains `true` with the `isPausedDueToClamshell` substate set
- [ ] Given `isActive == true` and the assertion is suspended due to clamshell, when the lid opens, then `SleepManager.preventSleep()` is called, the assertion is re-acquired, and `isPausedDueToClamshell` is cleared
- [ ] Given `isActive == true` and power source is AC, when the lid closes, then the assertion is NOT released and clamshell + external display workflow continues to work as before
- [ ] Given `isActive == true`, assertion suspended due to clamshell, and the lid is still closed, when the power source switches from battery to AC, then the assertion is re-acquired and `isPausedDueToClamshell` is cleared
- [ ] Given `isActive == true` and the lid is closed on AC (assertion held), when the power source switches from AC to battery, then the assertion is released and `isPausedDueToClamshell` is set
- [ ] Given `isActive == false`, when either the lid state or the power source changes, then no assertion changes occur (observers are strict no-ops while inactive)
- [ ] Given the assertion is suspended due to clamshell, when the user manually toggles OFF from the dropdown menu, then the suspended substate is cleared and `AppState` transitions to a fully-OFF state with no assertion held
- [ ] Given the assertion is suspended due to clamshell, when the app terminates (quit, SIGTERM, `applicationWillTerminate`), then `cleanup()` unregisters both observers and no IOKit notification ports are leaked
- [ ] Given VoiceOver is focused on the menu bar icon while `isPausedDueToClamshell` is true, when it announces state, then it reads "Neverdie -- paused, waiting for lid open or AC power" (not "ON" or "OFF")
- [ ] Given the dropdown menu is opened while in the paused substate, when the status line is read, then it shows "Neverdie: Paused (lid closed on battery)"

#### Implementation Notes
- **New file**: `Neverdie/Sources/ClamshellObserver.swift`. Use `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))` to obtain the root domain service, then `IOServiceAddInterestNotification` on `kIOGeneralInterest` with a callback that reads the `kAppleClamshellStateKey` property via `IORegistryEntryCreateCFProperty`. Deliver state changes on the main run loop via `IONotificationPortGetRunLoopSource`. Expose a `ClamshellObserving` protocol returning a callback `isLidClosed: Bool` so AppState can be unit tested against a fake.
- **New file**: `Neverdie/Sources/PowerSourceMonitor.swift`. Use `IOPSNotificationCreateRunLoopSource` with a `IOPowerSourceCallbackType` callback. On each callback, read `IOPSCopyPowerSourcesInfo` + `IOPSCopyPowerSourcesList`, inspect `kIOPSPowerSourceStateKey` to distinguish `kIOPSACPowerValue` vs `kIOPSBatteryPowerValue`. Deliver a `PowerSource` enum (`.ac`, `.battery`) via a `PowerSourceMonitoring` protocol. Initial value read synchronously at `start()` so AppState is never in an "unknown" state.
- **Modify**: `Neverdie/Sources/AppState.swift`. Add a private `isPausedDueToClamshell: Bool` substate (exposed read-only). Add injected dependencies on `ClamshellObserving` and `PowerSourceMonitoring` (protocol-based, default-constructed in production, fakes in tests). Implement a central `reconcileAssertion()` that is the ONLY place assertion state is changed when clamshell/power-source events arrive; it reads `(isActive, isLidClosed, powerSource)` and decides whether the assertion should be held or released. `toggle()` and the existing auto-OFF path both call through `reconcileAssertion()` so there is a single source of truth. When transitioning to `isActive == false`, make sure `isPausedDueToClamshell` is explicitly cleared.
- **Modify**: `Neverdie/Sources/SleepManager.swift`. No logic change required -- `preventSleep()` / `allowSleep()` are already idempotent (per ISSUE-003 TC-004 and TC-006). Add an integration check that calling `allowSleep()` while already released is a no-op (it already is). Log every suspend/resume at `.info` with category `"sleep"` including the `(lid, power)` reason.
- **Modify**: `Neverdie/Sources/NeverdieApp.swift`. In the AppDelegate / `@main` entry point, construct `ClamshellObserver` and `PowerSourceMonitor`, inject them into `AppState`, start them after the status item is installed, and ensure both are stopped in `applicationWillTerminate` before `SleepManager.allowSleep()` runs. Observers must be started even when `isActive == false` -- they are cheap and we must not miss the first event.
- **Modify**: `NeverdieTests/NeverdieTests.swift`. Add `FakeClamshellObserver` and `FakePowerSourceMonitor` conforming to the new protocols. Exercise the full 2x2x2 state matrix (`isActive` x `isLidClosed` x `powerSource`) plus the edge transitions. Use a `SleepManagingSpy` to record `preventSleep()` / `allowSleep()` calls and assert the expected sequence for each transition.
- **IOKit references**: `IOKit.pwr_mgt` is already linked via ISSUE-003. `IOKit.ps` (power sources) needs to be imported in `PowerSourceMonitor.swift`. Both APIs are available on macOS 14+.
- **Gotcha**: `IOServiceAddInterestNotification` requires an `IONotificationPort` whose run loop source must be explicitly added to the current run loop. Forgetting this results in callbacks never firing. Mirror the pattern in `SignalHandler.swift` for lifecycle management (`deinit` releases the notification port via `IONotificationPortDestroy`).
- **Gotcha**: Reading `AppleClamshellState` can briefly return `nil` during state transitions. Treat `nil` as "unchanged" and rely on the next callback rather than assuming `false`.
- **Gotcha**: `IOPSCopyPowerSourcesInfo` returns a `Unmanaged<CFTypeRef>` -- remember to `takeRetainedValue()` and release. A memory-leak regression here is invisible but will fail nightly leak checks.
- **Thread safety**: Both observer callbacks must marshal to the main actor before touching `AppState`. Use `DispatchQueue.main.async` from inside the C callback trampolines.
- **Out-of-scope stance**: We are NOT claiming clamshell support. We are respecting the user's environment so that battery is not drained while the machine is in a state where keep-awake is impossible anyway. Document this explicitly in `docs/requirements.md` Out of Scope clarification.

#### Tests
- [ ] Unit test: `FakeClamshellObserver.simulateClose()` while `isActive == true` and power source is battery -> `SleepManagingSpy.allowSleepCallCount == 1`, `isActive == true`, `isPausedDueToClamshell == true`
- [ ] Unit test: subsequent `FakeClamshellObserver.simulateOpen()` -> `SleepManagingSpy.preventSleepCallCount == 2` (initial ON + resume), `isPausedDueToClamshell == false`
- [ ] Unit test: `FakeClamshellObserver.simulateClose()` while power source is AC -> no call to `allowSleep()`, assertion still held, `isPausedDueToClamshell == false`
- [ ] Unit test: lid closed + battery (paused) then `FakePowerSourceMonitor.simulateTransition(.ac)` -> `preventSleep()` called, paused substate cleared
- [ ] Unit test: lid closed + AC (assertion held) then `FakePowerSourceMonitor.simulateTransition(.battery)` -> `allowSleep()` called, paused substate set
- [ ] Unit test: `isActive == false` and any combination of lid/power events -> zero calls to either `preventSleep()` or `allowSleep()`
- [ ] Unit test: `AppState.toggle()` to OFF while `isPausedDueToClamshell == true` -> paused substate cleared, `isActive == false`, no spurious `allowSleep()` error
- [ ] Unit test: `AppState.cleanup()` while paused -> observers stopped, `allowSleep()` safe no-op
- [ ] Unit test: `ClamshellObserver` calls its registered callback on a simulated `IOServiceInterestCallback` (via protocol injection of a fake IOKit notification source)
- [ ] Unit test: `PowerSourceMonitor` reports the correct initial power source on `start()` (mock `IOPSCopyPowerSourcesList` behind a protocol)
- [ ] Manual test (MacBook on battery): activate Neverdie -> close lid -> `pmset -g assertions | grep Neverdie` returns empty, system enters sleep within ~30s -> reopen lid -> wake -> `pmset -g assertions | grep Neverdie` shows the assertion again
- [ ] Manual test (MacBook on AC + external display): activate Neverdie -> close lid -> `pmset -g assertions | grep Neverdie` still shows assertion, external display drives the session normally
- [ ] Manual test (transition): on battery with lid closed (paused) -> plug in MagSafe/USB-C -> verify assertion re-appears in `pmset -g assertions` without opening the lid
- [ ] Manual test (transition): on AC with lid closed (assertion held) -> unplug -> verify assertion disappears from `pmset -g assertions` within one observer cycle
- [ ] Leak test: run with `leaks` or Instruments Leaks template through 50 lid-open/close cycles and 50 AC/battery transitions; no growth in IOKit notification ports

#### Rollback
Revert `ClamshellObserver.swift`, `PowerSourceMonitor.swift`, and the `AppState` / `NeverdieApp` diffs. `SleepManager.swift` is untouched by this issue so no rollback is needed there. Post-rollback, the app returns to the prior behavior: assertion is held regardless of lid/power (the original battery-drain bug). Document this as a known regression in the rollback PR so the fix can be re-applied.

---

### ISSUE-025: Wire StatusBarController to reactively update icon and accessibility for isPausedDueToClamshell
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-019, NFR-007
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-025-statusbar-reactive
- GH-Issue: https://github.com/pillip/neverdie/issues/47
- PR: https://github.com/pillip/neverdie/pull/49
- Depends-On: ISSUE-024

#### Goal
When `isPausedDueToClamshell` transitions via IOKit callbacks (lid close/open, power source change), the `StatusBarController` reactively updates the menu bar icon (dim to 50% opacity, show OFF/sleeping zombie frame) and fires VoiceOver announcements automatically -- without requiring the user to open the popover or toggle manually. This addresses RL-001 (reactive UI not wired to new state properties).

#### Scope (In/Out)
- In: StatusBarController reactive observation of `isPausedDueToClamshell` changes, icon opacity dimming to 50% on pause, animation stop/resume on pause/resume transitions, VoiceOver `announceStateChange()` calls on automatic transitions, unit test with mock AppState
- Out: New UI elements, new modules, changes to AppState or ClamshellObserver/PowerSourceMonitor, changes to the popover (it already reads the property correctly)

#### Acceptance Criteria (DoD)
- [ ] Given `isPausedDueToClamshell` transitions from false to true (via IOKit callback), when StatusBarController observes this change, then the animation stops, the OFF (sleeping zombie) icon is shown at 50% opacity, and VoiceOver announces "Neverdie paused -- lid closed on battery"
- [ ] Given `isPausedDueToClamshell` transitions from true to false while `isActive` is true, when StatusBarController observes this change, then the animation resumes, opacity returns to 100%, and VoiceOver announces "Neverdie resumed"
- [ ] Given the app is in the paused state, when the dropdown menu is opened, then the status line reads "Neverdie: Paused (lid closed on battery)" (verify the reactive path matches the existing popover path)
- [ ] Given a mock AppState with `isPausedDueToClamshell` toggled programmatically, when the observation fires, then the icon update callback is invoked with the correct parameters

#### Implementation Notes
- **Modify**: `Neverdie/Sources/StatusBarController.swift`. Add an observation mechanism (Combine publisher on `AppState.isPausedDueToClamshell`, or `withObservationTracking` if using `@Observable`) to detect `isPausedDueToClamshell` changes and call an `applyPausedState()` method.
- When entering paused state: call `animationManager.stopAnimation()`, set button image to `staticOffIcon`, set `button.alphaValue = 0.5`, call `updateAccessibility()` and `announceStateChange()`.
- When exiting paused state (and `isActive` is true): call `animationManager.startAnimation()`, `startFrameObserver()`, set `button.alphaValue = 1.0`, call `updateAccessibility()` and `announceStateChange()`.
- The existing `updateAccessibility()` (line ~244) and `announceStateChange()` (line ~258) already handle the paused state labels (added in ISSUE-024). This issue only adds the *trigger* -- the reactive observation that calls these methods when the state changes outside of user-initiated actions.
- Reference RL-001 in `docs/review_lessons.md` -- this issue directly implements the prevention strategy described there.

#### Tests
- [ ] Unit test: mock AppState `isPausedDueToClamshell` change from false to true triggers icon update (animation stopped, opacity 0.5, accessibility updated)
- [ ] Unit test: mock AppState `isPausedDueToClamshell` change from true to false with `isActive == true` triggers animation resume (opacity 1.0, accessibility updated)
- [ ] Unit test: mock AppState `isPausedDueToClamshell` change from true to false with `isActive == false` does not start animation (stays at static OFF, opacity 1.0)
- [ ] Manual test: close MacBook lid on battery -> verify icon dims in menu bar on external display (if available) or after reopening

#### Rollback
Revert the StatusBarController observation wiring. The icon and accessibility will continue to update on user-initiated actions (toggle, popover open) but not on automatic IOKit-driven transitions -- returning to the pre-fix behavior.

---

### ISSUE-026: Add rapid lid open/close idempotency stress test
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-019
- Priority: P2
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-026-stress-tests
- GH-Issue: https://github.com/pillip/neverdie/issues/48
- PR: https://github.com/pillip/neverdie/pull/50
- Depends-On: ISSUE-024

#### Goal
Add unit tests that rapidly alternate lid open/close and AC/battery transitions (50+ cycles each) and verify that the final assertion state matches the expected state based on the last (lid, power) values. This guards against race conditions or state drift in the reconciliation logic when IOKit callbacks fire in rapid succession.

#### Scope (In/Out)
- In: New test cases in `NeverdieTests/ClamshellBatteryTests.swift` using existing `FakeClamshellObserver` and `FakePowerSourceMonitor` fakes; rapid-cycle lid tests, rapid-cycle power tests, interleaved lid+power tests, call-count balance assertion
- Out: Changes to production code, new fakes, new test infrastructure

#### Acceptance Criteria (DoD)
- [ ] Given AppState is active, when 50 rapid lid open/close cycles are executed followed by a final close on battery, then `isPausedDueToClamshell` is true and assertion is released
- [ ] Given AppState is active, when 50 rapid AC/battery transitions are executed with lid closed, then the final assertion state matches the last power source (AC = held, battery = released)
- [ ] Given AppState is active, when interleaved lid and power events (100 total) are executed, then the final state is consistent with the last (lid, power) pair per the decision table
- [ ] Given any rapid-cycle test completes, when `preventSleepCallCount - allowSleepCallCount` is checked, then the imbalance is 0 (final state released) or 1 (final state held) -- no leaked or double-released assertions

#### Implementation Notes
- **Modify**: `NeverdieTests/ClamshellBatteryTests.swift`. Add a new test class or extension with rapid-cycle test methods.
- Use the existing `FakeClamshellObserver` and `FakePowerSourceMonitor` fakes and `SleepManagingSpy` from ISSUE-024.
- Reference the state matrix from TC-110 through TC-125 in `docs/test_plan.md`. The rapid-cycle tests exercise the same decision table but verify idempotency across many transitions rather than single-step correctness.
- This is the unit-test counterpart to TC-124 (which focuses on IOKit notification port memory leaks under Instruments). The unit test version focuses on state correctness and call-count balance.

#### Tests
- [ ] `testRapidLidCycles_finalClosedOnBattery_isPaused`: 50x open/close, final close on battery -> paused, assertion released
- [ ] `testRapidPowerCycles_lidClosed_finalBattery_isPaused`: lid closed, 50x AC/battery, final battery -> paused, assertion released
- [ ] `testRapidPowerCycles_lidClosed_finalAC_isHeld`: lid closed, 50x AC/battery, final AC -> not paused, assertion held
- [ ] `testInterleavedLidAndPower_100events_finalStateConsistent`: 100 interleaved events, final state matches last (lid, power) pair
- [ ] `testCallCountBalance_noLeakedAssertions`: after any rapid cycle, `preventSleepCallCount - allowSleepCallCount` is 0 or 1

#### Rollback
Delete the new test methods. No production code is affected.

---

### ISSUE-027: Implement ProcessMonitor with proc_listallpids and wire auto-ON/auto-OFF into AppState
- Track: product
- UI: false
- Manual: false
- PRD-Ref: FR-013, FR-014, FR-020
- Priority: P0
- Estimate: 1.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-027-process-monitor-auto-on-off
- GH-Issue: https://github.com/pillip/neverdie/issues/51
- PR: https://github.com/pillip/neverdie/pull/52
- Depends-On: ISSUE-002, ISSUE-003

#### Goal
ProcessMonitor detects running Claude Code processes via `proc_listallpids()` + `proc_name()`, and AppState uses the process count to automatically switch Neverdie ON when a Claude process appears (auto-ON) and OFF when all Claude processes terminate (auto-OFF), making the app fully hands-free.

#### Scope (In/Out)
- In: Full ProcessMonitor implementation using `proc_listallpids()` + `proc_name()` with 30-second Timer-based polling; `ProcessMonitoring` protocol in Protocols.swift; `FakeProcessMonitor` for tests; AppState integration for auto-ON (activate when OFF and processes detected) and auto-OFF (deactivate when ON, processes were detected, and count drops to 0); `ActivationSource` enum (.manual, .auto); `claudeProcessesEverDetected` tracking; VoiceOver announcements for auto-ON/auto-OFF; interaction with `reconcileAssertion()` for clamshell correctness; unit tests for ProcessMonitor and auto-ON/auto-OFF integration
- Out: Token monitoring changes, UI/popover changes, hover interaction changes, settings/preferences for poll interval

#### Acceptance Criteria (DoD)
- [x] Given the app is running, when `ProcessMonitor.pollOnce()` is called, then it returns the count of processes with exact name match on `claude` or `claude-code` (not substring -- rejects `claudex`, `myclaude`)
- [x] Given polling is started, when 30 seconds elapse, then the callback fires with updated count
- [x] Given `proc_listallpids` fails, then `pollOnce()` returns 0, logs error via os.Logger, and does not crash
- [x] Given Neverdie is ON and `claudeProcessesEverDetected == true`, when polling detects 0 claude processes, then AppState deactivates (isActive=false), assertion released via `reconcileAssertion()`, animation stopped, VoiceOver announces "Neverdie OFF -- all sessions ended"
- [x] Given Neverdie is ON via manual toggle with no claude processes ever detected, when polling detects 0, then Neverdie stays ON (manual override respected)
- [x] Given Neverdie is ON and 2 claude processes running, when 1 terminates, then Neverdie stays ON (count > 0)
- [x] Given Neverdie is OFF, when polling detects >= 1 claude process, then AppState activates automatically (isActive=true, activationSource=.auto), assertion created via `reconcileAssertion()`, animation starts, VoiceOver announces "Neverdie ON -- Claude Code detected"
- [x] Given auto-ON triggers while lid is closed on battery, then isActive becomes true but assertion is NOT held (reconcileAssertion handles it), isPausedDueToClamshell set
- [x] Given auto-OFF triggers while isPausedDueToClamshell==true, then isActive becomes false, isPausedDueToClamshell cleared

#### Implementation Notes
- **Rewrite**: `Neverdie/Sources/ProcessMonitor.swift` -- full implementation with `proc_listallpids()` + `proc_name()` from Darwin/libproc. Do NOT use NSRunningApplication (only lists GUI apps) or shell commands (no `pgrep`, no `ps`).
- **Modify**: `Neverdie/Sources/Protocols.swift` -- add `ProcessMonitoring` protocol with `pollOnce() -> Int`, `startPolling(onUpdate:)`, `stopPolling()`.
- **Modify**: `Neverdie/Sources/AppState.swift` -- add `processCount: Int`, `claudeProcessesEverDetected: Bool`, `activationSource: ActivationSource` enum (.manual, .auto). Auto-OFF logic: only when `isActive && claudeProcessesEverDetected && processCount == 0`. Auto-ON logic: when `!isActive && processCount > 0`. After activate/deactivate, call `reconcileAssertion()` to respect clamshell/power state.
- **Modify**: `Neverdie/Sources/NeverdieApp.swift` -- create ProcessMonitor, inject into AppState, start polling on launch.
- Timer-based polling on main run loop with 30-second interval (`Timer.scheduledTimer`, tolerance ~5s for energy efficiency).
- Process matching: exact name match on `claude` and `claude-code`. NOT substring.
- Per RL-001: ensure all UI consumers (StatusBarController) react to auto-ON/auto-OFF state changes, not just manual toggles.
- Per RL-002: if popover is open during auto-ON/auto-OFF, ensure state updates are reactive (pass `@Observable` AppState, not snapshot).

#### Tests
- [x] Unit: `pollOnce()` returns correct count for mock process list containing "claude", "claude-code", "Finder"
- [x] Unit: `pollOnce()` returns 0 for process list with "claudex", "myclaude" (exact match only)
- [x] Unit: `pollOnce()` returns 0 and logs error when `proc_listallpids` fails (mocked)
- [x] Unit: auto-OFF triggers when `isActive && claudeProcessesEverDetected && processCount == 0`
- [x] Unit: auto-OFF does NOT trigger when `claudeProcessesEverDetected == false`
- [x] Unit: auto-ON triggers when `!isActive && processCount > 0`
- [x] Unit: auto-ON sets `activationSource = .auto`
- [x] Unit: auto-ON while clamshell-on-battery results in isActive=true, isPausedDueToClamshell=true, assertion NOT held
- [x] Unit: auto-OFF while isPausedDueToClamshell clears the paused state
- [x] Integration: `stopPolling()` invalidates timer, no further callbacks fire

#### Rollback
Revert ProcessMonitor.swift to stub, revert AppState.swift and Protocols.swift changes. Auto-ON/auto-OFF behavior is removed; app returns to manual-only toggle.

## Phase 7: Energy Optimization

### ISSUE-028: Reduce ProcessMonitor polling frequency when Neverdie is OFF and enable App Nap
- Track: product
- UI: false
- Manual: false
- PRD-Ref: NFR-004, NFR-005
- Priority: P2
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-028-polling-interval-optimization
- GH-Issue: https://github.com/pillip/neverdie/issues/54
- PR: https://github.com/pillip/neverdie/pull/55
- Depends-On: ISSUE-027

#### Goal
When Neverdie is OFF, ProcessMonitor uses a longer polling interval (>= 60s) to reduce timer wake-ups and allow macOS App Nap; when Neverdie is ON, the current 30-second interval is preserved for timely auto-OFF detection.

#### Scope (In/Out)
- In: Longer polling interval (60-120s) when Neverdie is OFF; switch to 30s on auto-ON; switch back to longer interval on auto-OFF or manual toggle OFF; timer tolerance scaled to interval; unit tests for interval switching behavior
- Out: Event-based process detection (e.g., DispatchSource.process), changes to the ProcessMonitoring protocol interface, UI changes

#### Acceptance Criteria (DoD)
- [ ] Given Neverdie is OFF, when ProcessMonitor is polling, then the interval is >= 60 seconds
- [ ] Given Neverdie transitions from OFF to ON (auto-ON), then the polling interval switches to 30 seconds
- [ ] Given Neverdie transitions from ON to OFF (auto-OFF or manual), then the polling interval switches to the longer interval
- [ ] Given Neverdie is OFF with the longer polling interval, when Activity Monitor is checked, then App Nap shows "Yes" or Energy Impact is lower than before
- [ ] Given the polling interval changes, when stopPolling() is called, then the timer is correctly invalidated regardless of current interval

#### Implementation Notes
- Modify `Neverdie/Sources/ProcessMonitor.swift`: Add a `pollIntervalInactive` property (e.g., 90 seconds). Add a method to switch intervals (invalidate current timer, start new one with different interval). Timer tolerance should scale with the interval (e.g., tolerance = interval * 0.15).
- Modify `Neverdie/Sources/AppState.swift`: After auto-ON/auto-OFF and manual toggle, notify ProcessMonitor to switch intervals via a new protocol method or direct call.
- Consider using `ProcessInfo.processInfo.beginActivity(options:reason:)` with `.idleSystemSleepDisabled` only when active, to further improve energy profile.

#### Tests
- [ ] Unit: FakeProcessMonitor tracks interval changes
- [ ] Unit: auto-ON switches to fast polling interval
- [ ] Unit: auto-OFF switches to slow polling interval
- [ ] Unit: manual toggle OFF switches to slow polling interval
- [ ] Unit: stopPolling works correctly regardless of current interval

#### Rollback
Revert ProcessMonitor.swift and AppState.swift changes. Polling returns to fixed 30-second interval regardless of state.

---

### ISSUE-029: Replace StatusBarController frameObserverTimer with observation-based frame updates
- Track: product
- UI: false
- Manual: false
- PRD-Ref: NFR-004, NFR-005
- Priority: P2
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-029-remove-frame-observer-timer
- GH-Issue: https://github.com/pillip/neverdie/issues/53
- PR: https://github.com/pillip/neverdie/pull/56
- Depends-On: ISSUE-027

#### Goal
The frameObserverTimer in StatusBarController is removed and replaced with observation-based icon updates that fire only when AnimationManager.currentFrame changes, eliminating one of two 6fps timers during ON state.

#### Scope (In/Out)
- In: Make AnimationManager's `currentFrame` observable (via `@Observable` or callback pattern); remove `frameObserverTimer`, `startFrameObserver()`, and `stopFrameObserver()` from StatusBarController; replace with observation-based icon updates; update existing tests that check `isFrameObserverActive`
- Out: Changes to animation frame rate, animation frame assets, changes to AnimationManager's Timer internals

#### Acceptance Criteria (DoD)
- [ ] Given Neverdie is ON with animation running, when AnimationManager advances a frame, then StatusBarController updates the icon without a separate polling timer
- [ ] Given Neverdie transitions from ON to OFF, then no frame observation overhead remains
- [ ] Given the frame observer timer is removed, when the app is profiled, then there is one fewer timer firing at 6fps during ON state
- [ ] Given existing StatusBarClamshellTests, when the frame observer timer assertions are updated, then all tests pass

#### Implementation Notes
- **Option A (preferred)**: Make `AnimationManager` conform to `@Observable`. `currentFrame` is already `private(set) var` -- marking the class `@Observable` makes it trackable. StatusBarController can use `withObservationTracking` on `animationManager.currentFrame` (same pattern as AppState observation).
- **Option B**: Add a `onFrameChange: ((NSImage) -> Void)?` callback to AnimationManager, called from `advanceFrame()`. StatusBarController sets this callback instead of running its own timer.
- Modify `Neverdie/Sources/StatusBarController.swift`: Remove `frameObserverTimer`, `startFrameObserver()`, `stopFrameObserver()`. Add frame observation in the existing `scheduleObservationTracking()` or a separate observation chain.
- Update `NeverdieTests/StatusBarClamshellTests.swift`: Remove assertions on `isFrameObserverActive`. Replace with assertions that verify icon updates happen reactively.
- The `isFrameObserverActive` test helper can be removed or repurposed.

#### Tests
- [ ] Unit: icon updates when AnimationManager.currentFrame changes (without polling timer)
- [ ] Unit: no observation overhead when animation is stopped
- [ ] Unit: existing StatusBarClamshellTests pass with updated assertions
- [ ] Unit: transition animations still trigger icon updates correctly

#### Rollback
Revert StatusBarController.swift and AnimationManager changes. Restore frameObserverTimer-based polling for icon updates.

---

## Phase 8: Bug Fixes

### ISSUE-030: Fix "Launch at Login" silently failing and not reflecting external state changes
- Track: product
- UI: true
- Manual: false
- PRD-Ref: FR-004, US-008
- Priority: P1
- Estimate: 0.5d
- Status: done
- Owner:
- Branch: issue/ISSUE-030-fix-launch-at-login
- GH-Issue: https://github.com/pillip/neverdie/issues/57
- PR: https://github.com/pillip/neverdie/pull/58
- Depends-On: ISSUE-016

#### Goal
`toggleLaunchAtLogin()` in PopoverView.swift silently swallows `SMAppService` errors and never shows user feedback on failure. Additionally, the `@State launchAtLogin` bool is evaluated only once at view creation, so external state changes are never reflected in the UI.

#### Scope (In/Out)
- In: Replace the silent `catch` block with an NSAlert presenting "Could not enable Launch at Login" and the error's localised description; add an `os.Logger` call at `.error` level in the same catch block (category "lifecycle"); add `.onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }` to re-sync state when the popover re-opens; note the `.requiresApproval` status in a code comment
- Out: Changes to SMAppService entitlement configuration, Login Item plist, or any other menu item behaviour

#### Acceptance Criteria (DoD)
- [ ] Given the user clicks "Launch at Login" (unchecked), when `SMAppService.register()` succeeds, then a checkmark appears next to the menu item and the app is registered as a login item
- [ ] Given the user clicks "Launch at Login" (unchecked), when `SMAppService.register()` fails, then an NSAlert is presented with the title "Could not enable Launch at Login" and `error.localizedDescription` as the informative text
- [ ] Given the user clicks "Launch at Login" (checked), when `SMAppService.unregister()` succeeds, then the checkmark disappears and the app is no longer registered
- [ ] Given the popover re-opens after an external state change (e.g., user toggled the entry in System Settings), when the view appears, then `launchAtLogin` reflects the current `SMAppService.mainApp.status`
- [ ] Given any `SMAppService` failure, when the error is caught, then it is logged via `os.Logger` at `.error` level with category "lifecycle"

#### Implementation Notes
- **Modify**: `Neverdie/Sources/PopoverView.swift`
- Replace the `// silently fail` catch block with: (1) an `os.Logger(subsystem:, category: "lifecycle").error("SMAppService failed: \(error.localizedDescription)")` call, and (2) an `NSAlert` configured with `messageText = "Could not enable Launch at Login"` and `informativeText = error.localizedDescription`, presented via `alert.runModal()`
- Add `.onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }` to the outermost view in `PopoverView.body` to re-sync state on every popover open
- Add a comment near the `else` branch noting that `SMAppService.mainApp.status == .requiresApproval` means macOS is waiting for the user to approve in System Settings > Login Items — this state should not be treated as an error
- Per ISSUE-016 original spec and FR-004: error feedback to the user is a hard requirement, not optional

#### Tests
- [ ] Unit: when `SMAppService.register()` throws, `launchAtLogin` remains false and an NSAlert is presented
- [ ] Unit: when `SMAppService.register()` succeeds, `launchAtLogin` is set to true
- [ ] Unit: when `SMAppService.unregister()` succeeds, `launchAtLogin` is set to false
- [ ] Unit: when `SMAppService` throws, the error is passed to `os.Logger` at `.error` level

#### Rollback
Revert `Neverdie/Sources/PopoverView.swift` to the previous version. Silent failure and stale `@State` return; no user-visible regression beyond restoring the original bug.

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

ISSUE-024 (Clamshell battery) -- ISSUE-025 (StatusBar reactive update)
                              +-- ISSUE-026 (Rapid-cycle stress test)

ISSUE-002 (AppState) + ISSUE-003 (SleepManager) -- ISSUE-027 (ProcessMonitor auto-ON/OFF)

ISSUE-027 -- ISSUE-028 (Polling optimization)
ISSUE-027 -- ISSUE-029 (Frame observer removal)
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
| Phase 4.5: Polish | ISSUE-017 through ISSUE-019, ISSUE-024 through ISSUE-026 | 4d |
| Phase 5: Distribution | ISSUE-020 through ISSUE-023 | 3.5d |
| Phase 6: Hands-Free | ISSUE-027 | 1.5d |
| Phase 7: Energy Optimization | ISSUE-028, ISSUE-029 | 1d |
| **Total** | **29 issues** | **23.5d** |

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
| FR-019 | ISSUE-024, ISSUE-025, ISSUE-026 |
| NFR-004 | ISSUE-028, ISSUE-029 |
| NFR-005 | ISSUE-024, ISSUE-028 |
| NFR-006 | ISSUE-020, ISSUE-021 |
| FR-020 | ISSUE-027 |
| NFR-007 | ISSUE-019, ISSUE-025 |
