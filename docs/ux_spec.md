# UX Spec: Neverdie

> macOS menu bar app -- keeps Claude Code awake with a zombie that refuses to die.

---

## Information Architecture

Neverdie is a **menu bar-only** app with no main window and no Dock icon (`LSUIElement = true`). The entire UI surface consists of three layers:

### Layer 1: Menu Bar Status Item
- **Location**: macOS system menu bar (right side, among other status items)
- **Size**: ~18x18pt icon area (standard macOS menu bar item)
- **Always visible** when the app is running
- **Primary interaction surface** -- conveys ON/OFF state at a glance via icon animation

### Layer 2: Hover Popover
- **Trigger**: Mouse hover (mouse-enter) on the status item, or click when popover mode is active
- **Content**: Process count + token usage bar graphs
- **Dismissal**: Mouse-exit, or clicking elsewhere
- **Note**: macOS does not natively support hover on `NSStatusItem`. Implementation should use `NSTrackingArea` on the status item button. If hover proves infeasible, fall back to left-click popover (see Assumption A5 in requirements.md). The click-based fallback would change the toggle interaction to a popover with a toggle button inside.

### Layer 3: Dropdown Menu (Context Menu)
- **Trigger**: Right-click (or Control+click) on the status item
- **Content**: Status display, Launch at Login toggle, Quit Neverdie
- **Dismissal**: Click outside, or selecting a menu item

### Navigation Map

```
Menu Bar Icon
  |
  |-- [Left-click] --> Toggle Neverdie ON/OFF
  |                     (icon animation changes immediately)
  |
  |-- [Hover] -------> Popover
  |                     +-- Process count ("N active sessions")
  |                     +-- Token usage bar graphs (Context / Input / Output)
  |                     +-- Per-session breakdown (P2, if multiple sessions)
  |
  +-- [Right-click] --> Dropdown Menu
                        +-- Status line ("Neverdie: ON" or "Neverdie: OFF")
                        +-- Separator
                        +-- "Launch at Login" (toggle, checkmark)
                        +-- Separator
                        +-- "Quit Neverdie"
```

---

## Key Flows

### Flow 1: Toggle Neverdie Mode ON

- **Trigger**: User left-clicks the menu bar icon while Neverdie mode is OFF.
- **Steps**:
  1. User sees the sleeping zombie icon (static) in the menu bar.
  2. User left-clicks the icon.
  3. App creates an `IOPMAssertion` (`kIOPMAssertionTypePreventUserIdleSystemSleep`).
  4. Icon transitions from static sleeping zombie to animated "being shot" zombie (looping, 4-8fps).
  5. VoiceOver announces: "Neverdie ON".
  6. Process polling begins (or continues) at 30-second intervals.
- **Success state**: Animated zombie icon displayed. System sleep prevented. Assertion visible in `pmset -g assertions`.
- **Error paths**:
  - **IOPMAssertion creation fails** (e.g., system error): Icon remains in OFF state. Dropdown menu status line shows "Neverdie: Error -- could not prevent sleep". VoiceOver announces "Neverdie error". User can retry by clicking again.
  - **Rapid double-click**: Debounce clicks with a 300ms cooldown. Second click within cooldown is ignored.
- **Edge cases**:
  - App launched for the first time: starts in OFF state, sleeping zombie icon.
  - User toggles ON while no Claude Code processes are running: mode stays ON (manual override), auto-OFF does not trigger unless processes are later detected and then all end.

### Flow 2: Toggle Neverdie Mode OFF

- **Trigger**: User left-clicks the menu bar icon while Neverdie mode is ON.
- **Steps**:
  1. User sees the animated zombie icon in the menu bar.
  2. User left-clicks the icon.
  3. App releases the `IOPMAssertion` via `IOPMAssertionRelease`.
  4. Icon transitions from animated zombie to static sleeping zombie.
  5. VoiceOver announces: "Neverdie OFF".
- **Success state**: Static sleeping zombie icon displayed. Normal sleep behavior restored.
- **Error paths**:
  - **Assertion release fails**: Log the error internally. Force-set state to OFF. Icon returns to sleeping zombie. If assertion persists (edge case), it will be cleaned up on app quit.
- **Edge cases**:
  - User toggles OFF while Claude Code processes are still running: mode turns OFF regardless. The app does not warn -- user intent is explicit.

### Flow 3: Auto-OFF (All Claude Code Processes Terminated)

- **Trigger**: Process polling detects zero `claude` processes after previously detecting one or more.
- **Precondition**: Neverdie mode is ON AND at least one `claude` process was detected during this ON session.
- **Steps**:
  1. Polling timer fires (every 30 seconds).
  2. App scans for `claude` processes -- finds zero.
  3. App verifies that at least one process was previously detected in this ON session (to distinguish from manual-only activation).
  4. App releases the `IOPMAssertion`.
  5. Icon transitions to static sleeping zombie.
  6. VoiceOver announces: "Neverdie OFF -- all sessions ended".
  7. Popover (if open) updates to show "0 active sessions".
- **Success state**: Neverdie mode is OFF. Sleep behavior restored automatically.
- **Error paths**:
  - **Assertion release fails during auto-OFF**: Same handling as Flow 2 error path.
  - **Process detection fails** (e.g., permission error): Do NOT auto-OFF. Log the error. Continue polling. Show "Process detection unavailable" in popover if opened.
- **Edge cases**:
  - User manually activated Neverdie, never had any Claude Code process: auto-OFF does NOT trigger. Mode stays ON until manual toggle or quit.
  - One process terminates but another is still running: no auto-OFF. Count updates in popover.
  - Process terminates and a new one starts within the same polling interval: no auto-OFF triggered (count never reached zero at poll time).

### Flow 4: Hover Popover Display

- **Trigger**: Mouse enters the menu bar icon area.
- **Steps**:
  1. User hovers over the menu bar icon.
  2. Popover appears after a 200ms hover delay (prevents flickering on pass-through).
  3. Popover displays:
     - **Process count**: "N active sessions" (or "No active sessions")
     - **Token usage**: Three bar graphs (Context / Input / Output) with numeric values
  4. Data refreshes on popover open (does not wait for next poll cycle).
- **Dismissal**: Mouse exits the popover area (with 100ms grace period to prevent accidental dismissal when moving mouse within popover).
- **Success state**: Popover visible with current data.
- **Error paths**:
  - **Token data unavailable** (data source not found or unreadable): Show "Token data unavailable" in place of bar graphs. Process count still displays normally.
  - **Process detection fails**: Show "Process detection unavailable" in place of count. Token data may still display if independently available.
- **Edge cases**:
  - Popover open while auto-OFF triggers: Popover updates in-place (process count drops to 0, status changes).
  - Popover open while user clicks to toggle: Popover remains open, content updates to reflect new state.
  - No Claude Code processes running and token data unavailable: Popover shows minimal content -- "No active sessions" and "Token data unavailable".

### Flow 5: Dropdown Menu Interaction

- **Trigger**: User right-clicks (or Control+clicks) the menu bar icon.
- **Steps**:
  1. Dropdown menu appears below the icon.
  2. User sees: status line, separator, "Launch at Login" toggle, separator, "Quit Neverdie".
  3. User selects an option.
- **Actions**:
  - **"Launch at Login"**: Toggles the checkmark. Registers/unregisters via `SMAppService`. State persists.
  - **"Quit Neverdie"**: Releases any held assertion, then terminates the app.
- **Error paths**:
  - **SMAppService registration fails**: Show a brief "Could not enable Launch at Login" system alert (standard `NSAlert`). Menu item remains unchecked.
- **Edge cases**:
  - Right-click while popover is open: Popover dismisses, dropdown menu appears.
  - Right-click during animation: Animation continues in the background; dropdown appears normally.

### Flow 6: App Launch

- **Trigger**: User launches Neverdie (from Applications, Spotlight, or auto-login).
- **Steps**:
  1. App starts with `LSUIElement = true` (no Dock icon).
  2. Menu bar icon appears with the static sleeping zombie (OFF state).
  3. Process polling starts immediately (to detect any running Claude Code sessions).
  4. VoiceOver announces: "Neverdie -- sleep prevention OFF" when icon gains focus.
- **Success state**: Icon visible in menu bar, OFF state, polling active.
- **Error paths**:
  - **Icon fails to render**: Fallback to a text-only status item showing "ND" (two letters).
- **Edge cases**:
  - App is already running and user tries to launch again: Second instance detects the first (via `NSRunningApplication`) and quits immediately, bringing focus to the existing instance's menu bar icon.

### Flow 7: App Quit

- **Trigger**: User selects "Quit Neverdie" from the dropdown menu, or sends SIGTERM/SIGINT.
- **Steps**:
  1. If Neverdie mode is ON, release the `IOPMAssertion`.
  2. Stop process polling timer.
  3. Dismiss any open popover.
  4. Terminate the app.
- **Success state**: App removed from menu bar. No lingering assertions. Normal sleep restored.
- **Error paths**:
  - **Force-quit via Activity Monitor**: IOKit reclaims assertions automatically when the process dies. No user action needed.

---

## Screen List

### Screen 1: Menu Bar Icon -- OFF State

- **Purpose**: Indicate that Neverdie mode is inactive and system sleep is allowed.
- **Visual**: Static sleeping zombie icon (18x18pt). Eyes closed, Z's or peaceful expression. Line-art/pixel-art style.
- **States**:
  | State | Description |
  |-------|-------------|
  | **Default (OFF)** | Static sleeping zombie icon. Monochrome, uses template rendering for automatic light/dark adaptation. |
  | **Hover** | Subtle highlight (standard macOS menu bar hover behavior). Triggers popover after 200ms delay. |
  | **Click (mouseDown)** | Standard macOS press appearance (slight darken). Transitions to ON state on mouseUp. |
  | **Error** | Icon displays with a small red dot overlay (2x2pt) in the bottom-right corner, indicating an error condition (e.g., assertion creation failed on last attempt). |
  | **Launching** | Brief fade-in from 0% to 100% opacity over 200ms when the app first starts. |
- **Data dependencies**: App state (ON/OFF), error flag.
- **User actions**: Left-click (toggle ON), right-click (dropdown menu), hover (popover).

### Screen 2: Menu Bar Icon -- ON State

- **Purpose**: Indicate that Neverdie mode is active and system sleep is prevented.
- **Visual**: Animated zombie being shot. Looping frame animation, 4-8fps. 4-8 frames showing the zombie getting hit, recoiling, and recovering (loop). Line-art/pixel-art style.
- **States**:
  | State | Description |
  |-------|-------------|
  | **Default (ON, animating)** | Looping frame animation. Zombie gets shot, recoils, recovers, repeat. Template rendering for light/dark mode. |
  | **Hover** | Animation continues. Popover appears after 200ms. |
  | **Click (mouseDown)** | Standard press appearance. Animation pauses momentarily. Transitions to OFF on mouseUp. |
  | **Error (ON but assertion uncertain)** | Animation continues but with red dot overlay. Indicates the assertion may have been lost (e.g., system reclaimed it). |
  | **Auto-OFF transition** | Animation plays a "falling asleep" sequence (2-3 extra frames: zombie slows down, closes eyes, Z appears) before settling into OFF state. Duration: ~500ms. |
- **Data dependencies**: App state (ON/OFF), animation frame timer, error flag.
- **User actions**: Left-click (toggle OFF), right-click (dropdown menu), hover (popover).

### Screen 3: Hover Popover

- **Purpose**: Show Claude Code process count and token usage at a glance without disrupting workflow.
- **Visual**: Compact popover (~240pt wide, variable height). Dark translucent background with vibrancy (matches macOS system popover style). Content arranged vertically.
- **Layout**:
  ```
  +--------------------------------------+
  |  ACTIVE SESSIONS                     |
  |  [zombie icon] 3 Claude Code         |
  |                                      |
  |  TOKEN USAGE                         |
  |  Context  [========----]  45.2K      |
  |  Input    [====--------]  22.1K      |
  |  Output   [==----------]  11.8K      |
  |                                      |
  |  (Per-session breakdown -- P2)       |
  +--------------------------------------+
  ```
- **States**:
  | State | Description |
  |-------|-------------|
  | **Default** | Process count and token bar graphs displayed with current data. |
  | **Loading** | On first open, if data is being fetched: show process count area with a subtle pulse animation on the number. Token bars show skeleton placeholders (gray bars at 50% width, pulsing). |
  | **Empty (no processes)** | "No active sessions" text. Token section either shows last-known data (labeled "Last session") or "No token data" if never collected. |
  | **Error (data unavailable)** | Process count: "Process detection unavailable". Token section: "Token data unavailable -- check Claude Code installation". |
  | **Partial error** | Process count displays normally, but token section shows "Token data unavailable". Or vice versa. Each section degrades independently. |
- **Data dependencies**: Process count (from polling), token usage data (Context/Input/Output from local Claude Code state).
- **User actions**: Mouse hover to keep open, mouse exit to dismiss. No interactive elements inside the popover (read-only display).

### Screen 4: Dropdown Menu

- **Purpose**: Provide secondary actions (status info, launch-at-login toggle, quit).
- **Visual**: Standard macOS `NSMenu` dropdown. Native appearance, no custom styling.
- **Layout**:
  ```
  +--------------------------------------+
  |  Neverdie: ON                        |  <- Status (disabled item, informational)
  |  ---                                 |  <- Separator
  |  [checkmark] Launch at Login         |  <- Toggle item
  |  ---                                 |  <- Separator
  |  Quit Neverdie                       |  <- Action item
  +--------------------------------------+
  ```
- **States**:
  | State | Description |
  |-------|-------------|
  | **Default (OFF)** | Status line reads "Neverdie: OFF". All items enabled. |
  | **Default (ON)** | Status line reads "Neverdie: ON". All items enabled. |
  | **Error** | Status line reads "Neverdie: Error". All items still enabled (user can still quit or toggle login). |
  | **Launch at Login enabled** | Checkmark appears next to "Launch at Login". |
  | **Launch at Login disabled** | No checkmark next to "Launch at Login". |
- **Data dependencies**: App state (ON/OFF/Error), Launch at Login registration status.
- **User actions**: Click "Launch at Login" to toggle, click "Quit Neverdie" to exit.

### Screen 5: Icon Transition Animations

- **Purpose**: Provide smooth, delightful state transitions that reinforce the zombie character.
- **Transitions**:
  | Transition | Description | Duration |
  |-----------|-------------|----------|
  | **OFF to ON** | Sleeping zombie "wakes up" -- eyes open, then first bullet hits. 2-3 transition frames before entering the main animation loop. | ~400ms transition, then continuous loop |
  | **ON to OFF (manual)** | Zombie catches the last bullet, staggers, then falls asleep. 2-3 transition frames. | ~400ms |
  | **ON to OFF (auto)** | Same as manual OFF, but slightly slower. Zombie looks around (no more bullets?), then relaxes and falls asleep. 3-4 transition frames. | ~600ms |
  | **App launch** | Icon fades in from 0 to 100% opacity. | 200ms, ease-out |
  | **Error flash** | Red dot pulses twice (opacity 0-100-0-100) then stays solid. | 400ms for pulses |
- **States**: These are intermediate states, not persistent. Each transition ends in either Screen 1 (OFF) or Screen 2 (ON).

---

## Copy Guidelines

### Tone
- **Casual and slightly playful**, matching the zombie theme.
- Technical accuracy for developer audience -- do not oversimplify.
- Concise -- menu bar apps have minimal text real estate.

### Key Labels and Text

| Context | Text | Notes |
|---------|------|-------|
| Status line (OFF) | "Neverdie: OFF" | Dropdown menu, disabled item |
| Status line (ON) | "Neverdie: ON" | Dropdown menu, disabled item |
| Status line (Error) | "Neverdie: Error" | Dropdown menu, disabled item |
| Launch at Login | "Launch at Login" | Standard macOS phrasing |
| Quit | "Quit Neverdie" | Standard macOS phrasing, matches "Quit [AppName]" convention |
| Process count (plural) | "N active sessions" | e.g., "3 active sessions" |
| Process count (singular) | "1 active session" | Singular form |
| Process count (zero) | "No active sessions" | Not "0 active sessions" |
| Token section header | "Token Usage" | Popover section header |
| Token labels | "Context", "Input", "Output" | Short labels for bar graphs |
| Token values | "45.2K" / "1.2M" | Abbreviated with K (thousands) and M (millions). Use 1 decimal place. Below 1000, show exact number. |

### Error Messages

| Error | User-facing text | Where shown |
|-------|-----------------|-------------|
| Assertion creation failed | "Could not prevent sleep" | Dropdown status line: "Neverdie: Error -- could not prevent sleep" |
| Token data unavailable | "Token data unavailable" | Popover, in place of bar graphs |
| Process detection failed | "Process detection unavailable" | Popover, in place of process count |
| Launch at Login failed | "Could not enable Launch at Login" | System alert (`NSAlert`) |
| Already running | (no user-facing message) | Second instance quits silently |

### Localization Notes
- V1 is English-only.
- All user-facing strings should be extracted into a `Localizable.strings` file for future localization.
- The zombie theme and "Neverdie" brand name are not localized.

---

## Accessibility

### VoiceOver Announcements

| Event | VoiceOver reads | Implementation |
|-------|----------------|----------------|
| Icon gains focus | "Neverdie -- sleep prevention [ON/OFF]" | `accessibilityLabel` on status item button |
| Toggle to ON | "Neverdie ON" | Post `NSAccessibility.Notification.announcementRequested` |
| Toggle to OFF | "Neverdie OFF" | Post `NSAccessibility.Notification.announcementRequested` |
| Auto-OFF | "Neverdie OFF -- all sessions ended" | Post announcement notification |
| Error | "Neverdie error -- could not prevent sleep" | Post announcement notification |
| Popover opens | "Popover: N active sessions. Token usage: Context [value], Input [value], Output [value]" | `accessibilityLabel` on popover content view |
| Dropdown menu opens | Standard macOS menu VoiceOver behavior | Native `NSMenu` accessibility |

### Keyboard Navigation
- **Menu bar traversal**: Standard macOS keyboard navigation (Control+F8 or Fn+Control+F8 to focus menu bar, then arrow keys).
- **Dropdown menu**: Fully keyboard navigable via arrow keys (native `NSMenu` behavior).
- **Popover**: Popover content is read-only. VoiceOver reads the content as a single grouped element. No interactive controls inside the popover require keyboard focus.
- **Toggle via keyboard**: When the status item has keyboard focus, pressing Space or Enter triggers the same action as left-click (toggle ON/OFF).

### Focus Management
- Status item button is the single focusable element in the app.
- Popover does not steal focus -- it is an informational overlay.
- Dropdown menu follows standard macOS focus conventions.

### Color and Contrast
- Menu bar icon uses template rendering mode: macOS automatically adjusts the icon to be visible in both light mode (dark icon) and dark mode (light icon).
- Popover text uses standard system colors (`NSColor.labelColor`, `NSColor.secondaryLabelColor`) which automatically adapt to light/dark mode and meet WCAG AA contrast requirements (>= 4.5:1).
- Bar graph fills use a distinct color against the bar background with >= 3:1 contrast ratio.
- Error indicators (red dot) use `NSColor.systemRed` which meets contrast requirements in both modes.

### Reduced Motion
- When `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is `true`:
  - ON state icon shows a static "active zombie" frame instead of the animation loop.
  - Transition animations are replaced with immediate state changes (no intermediate frames).
  - Popover appears/disappears instantly (no fade).
  - The app still functions identically -- only visual motion is removed.

---

## Zombie Icon Concept

### Character Design Direction
- **Style**: Simple line-art or pixel-art, monochrome (works as template image).
- **Size**: 18x18pt canvas (@1x), 36x36pt (@2x Retina).
- **Personality**: Endearing, not gruesome. Think "cute undead" not "horror zombie".

### OFF State: Sleeping Zombie
- Zombie character in a peaceful sleeping pose.
- Eyes closed (simple curved lines or X shapes).
- Optional: Small "Z" or "z z z" near the head.
- Body relaxed, possibly leaning or slumped.
- Single static frame.

### ON State: Zombie Being Shot (Animation Loop)
- **Frame 1**: Zombie standing, looking alert. First bullet approaching.
- **Frame 2**: Bullet impact -- zombie recoils slightly, small impact lines.
- **Frame 3**: Zombie staggers backward, arms flailing.
- **Frame 4**: Zombie recovers, stands back up (resilient -- it's "neverdie").
- **Frame 5**: Back to alert stance, next bullet approaching.
- **Frame 6-8** (optional): Additional hit/recovery variations for visual interest.
- **Loop point**: Frame 5 (or 8) transitions seamlessly back to Frame 1.
- **Frame rate**: 6fps recommended (sweet spot between smooth and resource-efficient).

### Transition Frames
- **Wake-up** (OFF to ON): 2 frames -- eyes opening, body straightening.
- **Fall-asleep** (ON to OFF): 3 frames -- zombie slowing, eyes drooping, settling into sleep pose.
- **Auto-OFF variant**: 4 frames -- zombie looking around confused (no bullets?), shrugging, then falling asleep.

### Light/Dark Mode
- Use `NSImage` with `isTemplate = true` for automatic system tinting.
- All frames are single-color (black on transparent) -- macOS handles the inversion.
- If template rendering does not produce satisfactory results (e.g., detail loss), provide separate asset catalogs for light and dark appearances.

---

## P2 Features (Deferred Implementation)

### Per-Session Token Breakdown (FR-018 / US-009)

- **Popover layout extension**: When multiple Claude Code sessions are detected, the token section expands to show a tabbed or accordion view per session.
- **Session identification**: Each session is labeled by its working directory (preferred) or PID.
- **Layout sketch**:
  ```
  TOKEN USAGE

  > ~/project-alpha (PID 1234)
    Context  [========----]  45.2K
    Input    [====--------]  22.1K
    Output   [==----------]  11.8K

  > ~/project-beta (PID 5678)
    Context  [======------]  31.0K
    Input    [====---------]  18.5K
    Output   [==-----------]   9.2K
  ```
- **Interaction**: Sessions are collapsible. First session expanded by default, others collapsed.
- **Placement**: Documented here for future wireframing. Popover height will need a max-height with scroll for 3+ sessions.

---

## Technical UX Considerations

### Hover vs. Click Popover (Assumption A5)
macOS `NSStatusItem` does not natively support hover events. Two implementation approaches:

1. **Preferred**: Attach an `NSTrackingArea` to the status item's button view. On `mouseEntered`, show the popover. On `mouseExited`, dismiss it. This gives true hover behavior but may not work reliably across all macOS versions or with accessibility tools.

2. **Fallback**: If hover is infeasible, change to a **click-based popover** model:
   - Left-click opens the popover (which includes a prominent ON/OFF toggle button at the top).
   - Right-click opens the dropdown menu (unchanged).
   - This changes the toggle from "click icon" to "click toggle button inside popover" -- a small UX regression but still intuitive.

The implementation should try approach 1 first and fall back to approach 2 if issues arise.

### Click Debouncing
- 300ms debounce on left-click to prevent rapid toggling.
- During the debounce window, subsequent clicks are ignored.
- The debounce applies to the toggle action, not to the visual feedback (press appearance is immediate).

### Popover Positioning
- Popover anchors below the menu bar icon, pointing upward (standard macOS popover arrow position).
- On screens with the menu bar at the top, the popover opens downward.
- Popover should not extend beyond screen bounds -- adjust position if the icon is near the screen edge.

### Animation Performance
- Frame animation uses a `Timer` that swaps `NSImage` references on the status item button.
- Timer interval: ~167ms (6fps). Timer tolerance: 50ms (allows system to coalesce with other timers for energy efficiency).
- Animation stops when Neverdie mode is OFF (timer invalidated, not just paused).
- No Core Animation layers in the menu bar -- use direct image swapping only.

---

## Confidence Rating: **High**

**Reasoning**: The UX spec covers all 18 FRs and 9 user stories from the requirements document. The app's interaction surface is small (menu bar icon + popover + dropdown), which limits the scope of UX ambiguity. The two main risks identified in requirements.md (hover feasibility and token data source) are addressed with explicit fallback strategies. All Must-priority features have complete flow definitions with error paths. The P2 feature (per-session breakdown) is documented with layout placement. VoiceOver accessibility is specified for all state changes.
