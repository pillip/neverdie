# Data Model

## Storage Strategy

- **Primary storage**: In-memory (Swift properties on `@Observable` AppState class)
- **Choice rationale**: This is a single-process macOS menu bar app with no server, no network, and no multi-user concerns. All state is ephemeral and resets on app launch. There is no database. The architecture document explicitly states: "This app has no persistent database. All state is ephemeral (in-memory) or derived from the system."
- **Secondary storage**: None
  - **System-managed persistence**: `SMAppService` handles Launch at Login state. The app queries it but does not store it.
  - **External read-only data**: `~/.claude/projects/*/` JSON files (token usage), kernel process table (via libproc), IOKit assertions (via IOKit C API).
  - **No UserDefaults, no Core Data, no SQLite, no file-based persistence** in MVP.

---

## Access Patterns

| Pattern | Source (Screen/Flow) | Operation | Frequency | Latency Target |
|---------|----------------------|-----------|-----------|----------------|
| Read app active state | Menu Bar Icon (Screen 1/2), Dropdown Menu (Screen 4) | read | Continuous (SwiftUI observation) | Immediate (in-memory) |
| Toggle active state | Left-click on icon (Flow 1/2) | write | Low (user-initiated) | < 100ms perceived |
| Read process count | Hover Popover (Screen 3) | read | On popover open + every 30s | Immediate (in-memory) |
| Poll process table | ProcessMonitor timer (Flow 3) | read (external) | Every 30 seconds (FR-013) | < 100ms (NFR-004) |
| Read token usage | Hover Popover (Screen 3) | read | On popover open (on-demand) | < 500ms (file I/O) |
| Parse token files | TokenMonitor (Flow 4) | read (external) | On-demand when popover opens | < 500ms |
| Read per-session tokens | Hover Popover P2 section (Screen 3) | read | On popover open (on-demand) | < 500ms |
| Read animation frame | Menu Bar Icon (Screen 2) | read | Every ~167ms (6fps, NFR-008) | Immediate (in-memory) |
| Read launch-at-login state | Dropdown Menu (Screen 4) | read (system) | On menu open | Immediate (SMAppService query) |
| Write launch-at-login | Dropdown Menu (Screen 4) | write (system) | Low (user-initiated) | < 200ms |
| Create/release IOPMAssertion | SleepManager (Flow 1/2/3/7) | write (system) | Low (state transitions) | < 50ms |
| Read assertion held state | AppState, cleanup paths | read | On state transitions | Immediate (in-memory) |
| Read error state | Menu Bar Icon (Screen 1/2), Dropdown (Screen 4) | read | Continuous (SwiftUI observation) | Immediate (in-memory) |

---

## Schema (In-Memory Entities)

### Entity: AppState (ViewModel -- Single Instance)

| Property | Type | Initial Value | Mutable | Description |
|----------|------|---------------|---------|-------------|
| `isActive` | `Bool` | `false` | Yes (private set) | Neverdie mode ON/OFF. Single source of truth for mode state. |
| `activationSource` | `ActivationSource` | `.manual` | Yes (private set) | How the current ON session was triggered. Reset on each activation. |
| `processCount` | `Int` | `0` | Yes (private set) | Number of detected `claude` processes. Updated every 30s poll. |
| `tokenUsage` | `TokenUsage?` | `nil` | Yes (private set) | Aggregate token usage across all sessions. `nil` means unavailable. |
| `perSessionTokenUsage` | `[SessionTokenUsage]` | `[]` | Yes (private set) | Per-session token breakdown (P2 feature, FR-018). Empty if unavailable. |
| `claudeProcessesEverDetected` | `Bool` | `false` | Yes (private set) | Tracks whether any claude process was seen during this ON session. Reset to `false` on each activation. Used for auto-OFF guard (FR-014). |
| `lastError` | `AppError?` | `nil` | Yes (private set) | Most recent error for UI display. `nil` means no error. |

- **Lifecycle**: Created once at app launch. Lives for the entire app runtime. Destroyed on app termination.
- **Observation**: Marked `@Observable` (Swift 5.9 Observation framework). SwiftUI views automatically re-render when properties change.
- **Relationships**: Owns (has references to) SleepManager, ProcessMonitor, TokenMonitor, AnimationManager as service dependencies.

### Entity: TokenUsage (Value Type)

| Property | Type | Constraints | Description |
|----------|------|-------------|-------------|
| `context` | `Int` | >= 0 | Context window tokens used |
| `input` | `Int` | >= 0 | Input tokens consumed |
| `output` | `Int` | >= 0 | Output tokens generated |

- **Lifecycle**: Created on each successful token file parse. Immutable value type (`struct`). Replaced wholesale on each read.
- **Relationships**: Embedded in `AppState.tokenUsage` (optional). Also embedded in each `SessionTokenUsage`.

### Entity: SessionTokenUsage (Value Type, Identifiable)

| Property | Type | Constraints | Description |
|----------|------|-------------|-------------|
| `id` | `String` | Non-empty | Session identifier (PID or session ID from file) |
| `label` | `String` | Non-empty | Human-readable label (working directory path or PID) |
| `usage` | `TokenUsage` | Valid TokenUsage | Token counts for this session |

- **Lifecycle**: Created on each token file parse. Immutable. Array replaced wholesale on each read.
- **Relationships**: Array of these stored in `AppState.perSessionTokenUsage`.

### Entity: ActivationSource (Enum)

| Case | Description |
|------|-------------|
| `.manual` | User clicked the icon to activate |
| `.auto` | (Reserved for future use -- currently activation is always manual, but auto-ON could be added) |

- **Lifecycle**: Set on each activation. Read during auto-OFF logic.

### Entity: AppError (Enum)

| Case | Description |
|------|-------------|
| `.assertionCreationFailed` | IOPMAssertionCreateWithName returned non-success |
| `.assertionReleaseFailed` | IOPMAssertionRelease returned non-success |
| `.processDetectionFailed` | proc_listallpids failed |

- **Lifecycle**: Set when an error occurs. Cleared on next successful operation or manual retry.
- **UI mapping**: Drives the error dot on the icon (Screen 1/2) and error status in dropdown (Screen 4).

### Entity: SleepManager (Service -- Single Instance)

| Property | Type | Initial Value | Description |
|----------|------|---------------|-------------|
| `assertionID` | `IOPMAssertionID` | `kIOPMNullAssertionID` | System-assigned assertion ID. Non-null when assertion is held. |

- **Lifecycle**: Created at app launch. `deinit` releases any held assertion.
- **Computed**: `isAssertionHeld: Bool` -- derived from `assertionID != kIOPMNullAssertionID`.

### Entity: ProcessMonitor (Service -- Single Instance)

| Property | Type | Initial Value | Description |
|----------|------|---------------|-------------|
| `pollInterval` | `TimeInterval` | `30.0` | Hardcoded for MVP (FR-013) |
| `timer` | `Timer?` | `nil` | Active polling timer. `nil` when not polling. |
| `processNames` | `[String]` | `["claude", "claude-code"]` | Process name match list |

- **Lifecycle**: Created at app launch. Timer started/stopped with mode transitions.
- **No accumulated state**: Each poll is a fresh snapshot. No history of process counts is retained.

### Entity: TokenMonitor (Service -- Single Instance)

| Property | Type | Initial Value | Description |
|----------|------|---------------|-------------|
| `basePath` | `String` | `"~/.claude/projects"` | Root directory for Claude Code project data |

- **Lifecycle**: Created at app launch. Stateless -- reads files on demand.
- **No caching**: Each `readUsage()` call re-reads from disk. This is intentional because files may change between reads and the call frequency is low (on popover open only).

### Entity: AnimationManager (Service -- Single Instance)

| Property | Type | Initial Value | Description |
|----------|------|---------------|-------------|
| `frames` | `[NSImage]` | Loaded from asset catalog | Pre-loaded animation frames (ON state) |
| `staticOffIcon` | `NSImage` | Loaded from asset catalog | Sleeping zombie (OFF state) |
| `currentFrameIndex` | `Int` | `0` | Current position in animation loop |
| `fps` | `Double` | `6.0` | Frame rate (FR-011: 4-8fps range) |
| `timer` | `Timer?` | `nil` | Animation timer. `nil` when not animating. |

- **Lifecycle**: Created at app launch. Frames loaded once and retained for app lifetime.
- **Memory**: ~40KB total for all frames (18x18pt @2x, 8 frames). Negligible per NFR-003.
- **Computed**: `currentFrame: NSImage` -- derived from `frames[currentFrameIndex]`.

---

## State Machine: Neverdie Mode

### States

| State | `isActive` | `claudeProcessesEverDetected` | Icon | Assertion |
|-------|-----------|-------------------------------|------|-----------|
| **OFF** | `false` | `false` (reset) | Static sleeping zombie | Released |
| **ON_MANUAL** | `true` | `false` | Animated zombie | Held |
| **ON_TRACKING** | `true` | `true` | Animated zombie | Held |

Note: `ON_MANUAL` and `ON_TRACKING` are not separate enum cases in the implementation. They are the same `isActive == true` state, distinguished by the `claudeProcessesEverDetected` flag.

### Transitions

```
                    +-----------+
                    |    OFF    |  (initial state on app launch)
                    +-----+-----+
                          |
               [Left-click: toggle()]
                          |
                          v
                    +-----------+
                    | ON_MANUAL |  (isActive=true, everDetected=false)
                    +-----+-----+
                          |
            [Poll finds processCount > 0]
                          |
                          v
                   +-------------+
                   | ON_TRACKING |  (isActive=true, everDetected=true)
                   +------+------+
                          |
          +---------------+---------------+
          |                               |
[Poll finds processCount==0]     [Left-click: toggle()]
          |                               |
          v                               v
    +-----------+                   +-----------+
    |    OFF    |  (auto-OFF)       |    OFF    |  (manual OFF)
    +-----------+                   +-----------+
```

### Transition Rules

| From | Event | Guard | To | Side Effects |
|------|-------|-------|----|-------------|
| OFF | `toggle()` | -- | ON_MANUAL | Create IOPMAssertion, start animation, start polling, set `activationSource = .manual` |
| ON_MANUAL | `toggle()` | -- | OFF | Release assertion, stop animation, reset `claudeProcessesEverDetected` |
| ON_MANUAL | Poll: `processCount > 0` | -- | ON_TRACKING | Set `claudeProcessesEverDetected = true` |
| ON_MANUAL | Poll: `processCount == 0` | `claudeProcessesEverDetected == false` | ON_MANUAL | No-op. Stay ON. Manual override. |
| ON_TRACKING | `toggle()` | -- | OFF | Release assertion, stop animation, reset `claudeProcessesEverDetected` |
| ON_TRACKING | Poll: `processCount == 0` | `claudeProcessesEverDetected == true` | OFF | Release assertion, stop animation (auto-OFF per FR-014) |
| ON_TRACKING | Poll: `processCount > 0` | -- | ON_TRACKING | Update `processCount` display |
| Any ON | App quit / SIGTERM | -- | OFF | Release assertion, stop timers (FR-008, FR-009) |
| Any ON | Assertion creation fails | -- | OFF | Set `lastError = .assertionCreationFailed`, remain OFF |

---

## External Data Sources

### 1. Claude Code Token Files (`~/.claude/projects/*/`)

**Location**: `~/.claude/projects/<project-hash>/` directories.

**Expected file structure** (best-effort, needs implementation spike):

```
~/.claude/
  projects/
    <project-hash-1>/
      settings.json          # Project-level settings
      ...session files...    # Session data with token usage
    <project-hash-2>/
      settings.json
      ...
```

**Expected JSON structure for token data** (speculative, based on Claude Code patterns):

```json
{
  "session_id": "sess_abc123",
  "project_path": "/Users/user/my-project",
  "usage": {
    "context_tokens": 45200,
    "input_tokens": 22100,
    "output_tokens": 11800
  },
  "updated_at": "2026-03-18T10:30:00Z"
}
```

**Mapping to internal types**:

| JSON Field | Internal Property | Transform |
|------------|-------------------|-----------|
| `usage.context_tokens` | `TokenUsage.context` | Direct Int mapping |
| `usage.input_tokens` | `TokenUsage.input` | Direct Int mapping |
| `usage.output_tokens` | `TokenUsage.output` | Direct Int mapping |
| `session_id` | `SessionTokenUsage.id` | Direct String mapping |
| `project_path` | `SessionTokenUsage.label` | Extract last path component or use full path |

**Important caveats**:
- The exact file format is **not guaranteed** and may change between Claude Code versions.
- The `TokenMonitor` must use defensive JSON parsing: decode known fields, ignore unknown fields.
- If any field is missing or the wrong type, treat the entire session's token data as unavailable.
- The file encoding is assumed to be UTF-8.
- Files may be written to concurrently by Claude Code -- read should handle partial writes gracefully (catch `DecodingError`, return `nil`).

### 2. Kernel Process Table (via libproc)

**Access method**: `proc_listallpids()` to enumerate PIDs, then `proc_name()` per PID.

**Data extracted**:

| Field | Type | Usage |
|-------|------|-------|
| PID | `pid_t` (Int32) | Enumerate all running processes |
| Process name | `String` (up to `MAXCOMLEN` = 16 chars) | Match against `["claude", "claude-code"]` |

**Constraints**:
- `proc_name()` returns at most 16 characters (kernel `MAXCOMLEN` limit). Process names longer than 16 chars are truncated.
- No elevated permissions required -- the app can see the user's own processes.
- Returns a snapshot -- no subscription/notification mechanism.

### 3. IOKit Assertions (via IOKit C API)

**Access method**: `IOPMAssertionCreateWithName()` to create, `IOPMAssertionRelease()` to release.

**Data managed**:

| Field | Type | Usage |
|-------|------|-------|
| Assertion ID | `IOPMAssertionID` (UInt32) | Handle for the held assertion |
| Assertion type | `CFString` | `kIOPMAssertionTypePreventUserIdleSystemSleep` (FR-005/FR-006) |
| Assertion name | `CFString` | `"Neverdie - Preventing sleep for Claude Code"` |

**Lifecycle**: Created when mode turns ON, released when mode turns OFF or app terminates. IOKit automatically reclaims assertions if the process dies.

### 4. SMAppService (System-Managed)

**Access method**: `SMAppService.mainApp.status` to read, `.register()` / `.unregister()` to write.

**Data**:

| Field | Type | Usage |
|-------|------|-------|
| Registration status | `SMAppService.Status` | Whether Launch at Login is enabled |

**Persistence**: Managed entirely by macOS. The app does not store this value.

---

## Data Flow

```
External Sources              Monitors                AppState              UI (SwiftUI Views)
================              ========                ========              ==================

Process Table     --poll-->  ProcessMonitor  --callback-->  processCount  --@Observable-->  Popover (count)
(libproc)                    (every 30s)              claudeProcessesEverDetected           Icon (auto-OFF)

~/.claude/        --read-->  TokenMonitor    --return-->    tokenUsage    --@Observable-->  Popover (bars)
(JSON files)                 (on-demand)               perSessionTokenUsage                 Popover (sessions)

IOKit             <--API-->  SleepManager    --status-->    isActive      --@Observable-->  Icon (animation)
(assertions)                                                                                Dropdown (status)

SMAppService      <--API-->  (direct call)   --query-->     (computed)    --@Observable-->  Dropdown (toggle)
(Login Items)

User Click        ---------------------->    toggle()       isActive      --@Observable-->  All views
                                             activationSource
```

### Data Flow Rules

1. **Unidirectional for reads**: External sources flow through monitors into AppState, then into views. Views never read external sources directly.
2. **AppState is the single source of truth**: Views observe only AppState properties. Monitors update only AppState.
3. **On-demand token reads**: TokenMonitor reads files only when the popover opens (not on a timer). This avoids unnecessary file I/O per the architecture spec.
4. **Process polling is timer-driven**: ProcessMonitor polls on a 30-second timer when mode is ON. Results flow into AppState synchronously on the main thread.
5. **State transitions are synchronous**: `toggle()`, auto-OFF, and error handling all happen on the main thread. No async state mutations.

---

## Graceful Degradation

### Token Data Unavailable

| Condition | Detection | AppState | UI Display |
|-----------|-----------|----------|------------|
| `~/.claude/` directory does not exist | `FileManager.fileExists` returns false | `tokenUsage = nil` | "Token data unavailable" in popover |
| `~/.claude/projects/` is empty | No subdirectories found | `tokenUsage = nil` | "Token data unavailable" in popover |
| JSON files exist but cannot be parsed | `JSONDecoder` throws `DecodingError` | `tokenUsage = nil` | "Token data unavailable" in popover |
| JSON files have unexpected schema | Required fields missing | `tokenUsage = nil` | "Token data unavailable" in popover |
| Permission denied on `~/.claude/` | `FileManager` throws permission error | `tokenUsage = nil` | "Token data unavailable" in popover |
| Partial data (some sessions readable) | Per-file error handling | `tokenUsage` has aggregate of readable sessions | Bar graphs show partial data, unreadable sessions omitted |

**Key principle**: Token monitoring is best-effort. The app's core function (sleep prevention) is completely independent of token data. Token unavailability is logged at `.info` level, not `.error`.

### Process Detection Unavailable

| Condition | Detection | AppState | UI Display |
|-----------|-----------|----------|------------|
| `proc_listallpids` fails | Returns negative value | `processCount = 0`, `lastError = .processDetectionFailed` | "Process detection unavailable" in popover |
| No permission to read process table | API returns empty/error | `processCount = 0` | "Process detection unavailable" in popover |

**Key principle**: If process detection fails, auto-OFF does NOT trigger. The app errs on the side of keeping sleep prevention active rather than accidentally disabling it.

### IOKit Assertion Failure

| Condition | Detection | AppState | UI Display |
|-----------|-----------|----------|------------|
| Assertion creation fails | `IOPMAssertionCreateWithName` returns non-success | `isActive = false`, `lastError = .assertionCreationFailed` | Error state icon, "Neverdie: Error -- could not prevent sleep" in dropdown |
| Assertion release fails | `IOPMAssertionRelease` returns non-success | `isActive = false` (force), `lastError = .assertionReleaseFailed` | Logged, state forced to OFF |

---

## Constraints and Validation

### Compile-Time Constraints (Swift Type System)

| Constraint | Enforcement |
|------------|-------------|
| `isActive` is `Bool` | Only `true`/`false` values possible |
| `activationSource` is a closed enum | Only `.manual` or `.auto` |
| `tokenUsage` is optional | Explicit `nil` handling required at call sites |
| `TokenUsage` fields are `Int` | No floating point rounding issues for token counts |
| `SessionTokenUsage` conforms to `Identifiable` | SwiftUI list rendering requires unique IDs |

### Runtime Validation (Application-Level)

| Validation | Location | Rule |
|------------|----------|------|
| Token counts non-negative | TokenMonitor.readUsage() | Reject sessions where any token count < 0 |
| Process count non-negative | ProcessMonitor.pollOnce() | `max(0, count)` -- clamp to zero |
| Assertion ID validity | SleepManager | Check `!= kIOPMNullAssertionID` before release |
| JSON decode safety | TokenMonitor | Wrap all JSONDecoder calls in do/catch, return nil on failure |
| File path safety | TokenMonitor | Use `FileManager` APIs only, no string interpolation into paths |
| Click debounce | AppState.toggle() | Ignore toggle calls within 300ms of last toggle |

### Data Integrity Rules

| Rule | Description |
|------|-------------|
| `isActive` and assertion must be in sync | If `isActive == true`, `SleepManager.isAssertionHeld` must be `true`. If they diverge, force `isActive = false` and log error. |
| `claudeProcessesEverDetected` resets on deactivation | Must be set to `false` every time `isActive` transitions to `false`. |
| Token data is never cached across sessions | `tokenUsage` is set to `nil` when mode turns OFF. Fresh read on next popover open. |
| Aggregate token usage must equal sum of per-session | `tokenUsage` is computed by summing `perSessionTokenUsage` entries, not read independently. |

---

## Scaling Notes

### Current Design Handles

- **Process table**: Up to ~1000 PIDs scanned every 30 seconds. Typical macOS has 300-600 processes. `proc_listallpids` + `proc_name` completes in < 10ms.
- **Token files**: Up to ~50 project directories under `~/.claude/projects/`. File I/O for 50 small JSON files completes in < 100ms.
- **Animation frames**: 8 frames at 18x18pt @2x. ~40KB total memory.
- **Single user, single machine**: No concurrency concerns beyond main thread timer callbacks.

### At 10x (Feature Growth)

| Scenario | Impact | Adaptation |
|----------|--------|------------|
| Support 10+ process name patterns | ProcessMonitor match loop takes slightly longer | Negligible -- still O(PIDs * patterns), both are small |
| 500+ Claude Code project directories | Token file scan takes 500ms+ | Add directory-level caching with file modification date checks. Only re-parse changed files. |
| User preferences (poll interval, process names) | Need persistent storage | Add `UserDefaults` for simple key-value preferences. No schema migration needed. |
| Multiple data sources for tokens (file + CLI + API) | TokenMonitor needs abstraction | Define `TokenDataSource` protocol. Each source implements it. TokenMonitor becomes an aggregator. |

### At 100x (Architectural Change)

| Scenario | Impact | Adaptation |
|----------|--------|------------|
| Multi-machine monitoring | Fundamentally different architecture | Would require network communication, a server component, and actual database storage. Out of scope for this app's design. |
| Historical token usage tracking | Need persistent time-series data | Would require SQLite or Core Data. Current in-memory model cannot support this. |
| Plugin system for monitors | Need process isolation | XPC services or plugin bundles. Current monolith architecture would need restructuring. |

---

## Confidence Rating: **High**

**Reasoning**: This data model is straightforward because the app has no database and no persistent state beyond system-managed Launch at Login. All entities are in-memory Swift types with clear lifecycles. The state machine has only 3 effective states with well-defined transitions directly from the requirements and architecture documents.

The one area of uncertainty is the exact JSON schema of Claude Code's token files under `~/.claude/projects/*/`. This is explicitly called out as the highest-risk area in both the architecture and requirements documents. However, the data model handles this through:
1. Optional types (`TokenUsage?`) that naturally represent unavailability.
2. Defensive parsing that treats any decode failure as `nil`.
3. Complete independence of the core sleep prevention feature from token data.

Every access pattern traces to a specific screen or flow in the UX spec. Every entity traces to the architecture document's module definitions. No speculative data structures have been added.
