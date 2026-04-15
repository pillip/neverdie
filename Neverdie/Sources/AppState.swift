import Foundation
import os

/// Possible error states for the Neverdie app.
enum NeverdieError: Equatable, Sendable {
    case assertionFailed
}

/// How Neverdie was activated.
enum ActivationSource: Equatable, Sendable {
    case manual
    case auto
}

/// Central state management for the Neverdie app.
///
/// AppState is the single source of truth for UI and service state.
/// It coordinates with SleepManager via protocol-based dependency injection.
///
/// ## Assertion Reconciliation (FR-019)
/// `reconcileAssertion()` is the single point where the IOPMAssertion is
/// acquired or released. The decision table:
///
/// | isActive | isLidClosed | powerSource | Assertion | isPausedDueToClamshell |
/// |----------|-------------|-------------|-----------|------------------------|
/// | false    | any         | any         | no        | false                  |
/// | true     | false       | any         | yes       | false                  |
/// | true     | true        | AC          | yes       | false                  |
/// | true     | true        | battery     | **no**    | **true**               |
@Observable
final class AppState {
    // MARK: - State

    /// Whether Neverdie mode is active (sleep prevention enabled).
    private(set) var isActive: Bool = false

    /// Whether the assertion is temporarily suspended due to clamshell + battery.
    private(set) var isPausedDueToClamshell: Bool = false

    /// The most recent error, if any.
    private(set) var lastError: NeverdieError? = nil

    /// How Neverdie was activated (manual click or auto-detected process).
    private(set) var activationSource: ActivationSource = .manual

    /// Number of detected Claude Code processes from the last poll.
    private(set) var processCount: Int = 0

    /// Whether any Claude process was ever detected during the current ON session.
    private(set) var claudeProcessesEverDetected: Bool = false

    // MARK: - Dependencies

    private let sleepManager: SleepManaging?
    private(set) var clamshellObserver: ClamshellObserving?
    private(set) var powerSourceMonitor: PowerSourceMonitoring?
    private(set) var processMonitor: ProcessMonitoring?

    // MARK: - Internal State

    private var lastToggleDate: Date = .distantPast
    let debounceInterval: TimeInterval

    // MARK: - Init

    init(sleepManager: SleepManaging? = nil,
         clamshellObserver: ClamshellObserving? = nil,
         powerSourceMonitor: PowerSourceMonitoring? = nil,
         processMonitor: ProcessMonitoring? = nil,
         debounceInterval: TimeInterval = 0.3) {
        self.sleepManager = sleepManager
        self.clamshellObserver = clamshellObserver
        self.powerSourceMonitor = powerSourceMonitor
        self.processMonitor = processMonitor
        self.debounceInterval = debounceInterval
    }

    // MARK: - Observer Setup

    /// Start lid and power source observers. Call once after init.
    func startObservers() {
        clamshellObserver?.start { [weak self] _ in
            self?.reconcileAssertion()
        }
        powerSourceMonitor?.start { [weak self] _ in
            self?.reconcileAssertion()
        }
    }

    /// Stop lid and power source observers.
    func stopObservers() {
        clamshellObserver?.stop()
        powerSourceMonitor?.stop()
    }

    // MARK: - Process Monitoring

    /// Start process monitoring. Polling begins immediately and fires the
    /// auto-ON / auto-OFF logic on each update.
    func startProcessMonitoring() {
        processMonitor?.startPolling { [weak self] count in
            self?.handleProcessUpdate(count)
        }
    }

    /// Stop process monitoring.
    func stopProcessMonitoring() {
        processMonitor?.stopPolling()
    }

    /// Handle a process count update from ProcessMonitor.
    ///
    /// Note: If the user manually toggles ON while Claude is running, `claudeProcessesEverDetected`
    /// will be set to `true` on the next poll. This means auto-OFF will trigger when Claude exits,
    /// even though the user manually activated. This is intentional: once processes are detected,
    /// the app treats them as the reason for staying on, regardless of activation source.
    func handleProcessUpdate(_ count: Int) {
        processCount = count

        if isActive {
            // Track that we saw processes while active
            if count > 0 {
                claudeProcessesEverDetected = true
            }
            // Auto-OFF: only when processes were previously detected and now all gone
            if claudeProcessesEverDetected && count == 0 {
                autoDeactivate()
            }
        } else {
            // Auto-ON: activate when Claude processes appear
            if count > 0 {
                autoActivate()
            }
        }
    }

    // MARK: - Toggle

    /// Toggle Neverdie mode ON/OFF with 300ms debounce.
    func toggle() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleDate) >= debounceInterval else {
            Logger.lifecycle.debug("Toggle debounced (within 300ms)")
            return
        }
        lastToggleDate = now

        if isActive {
            deactivate()
        } else {
            activate()
        }
    }

    // MARK: - Activation / Deactivation

    private func activate() {
        lastError = nil
        isActive = true
        isPausedDueToClamshell = false
        activationSource = .manual
        claudeProcessesEverDetected = false
        processMonitor?.setActivePolling(true)
        Logger.lifecycle.info("Neverdie activated (source: manual)")
        reconcileAssertion()
    }

    private func deactivate() {
        sleepManager?.allowSleep()
        isActive = false
        isPausedDueToClamshell = false
        claudeProcessesEverDetected = false
        processMonitor?.setActivePolling(false)
        Logger.lifecycle.info("Neverdie deactivated (source: manual)")
    }

    private func autoActivate() {
        lastError = nil
        isActive = true
        isPausedDueToClamshell = false
        activationSource = .auto
        claudeProcessesEverDetected = true
        processMonitor?.setActivePolling(true)
        Logger.lifecycle.info("Neverdie activated (source: auto, claude processes detected)")
        reconcileAssertion()
    }

    private func autoDeactivate() {
        sleepManager?.allowSleep()
        isActive = false
        isPausedDueToClamshell = false
        claudeProcessesEverDetected = false
        processMonitor?.setActivePolling(false)
        Logger.lifecycle.info("Neverdie deactivated (source: auto, all sessions ended)")
    }

    // MARK: - Assertion Reconciliation (FR-019)

    /// Central decision point for whether the IOPMAssertion should be held.
    /// Called on every state change: toggle, lid change, power source change.
    func reconcileAssertion() {
        guard isActive else {
            // Not active — ensure no assertion is held
            if sleepManager?.isAssertionHeld == true {
                sleepManager?.allowSleep()
            }
            isPausedDueToClamshell = false
            return
        }

        let lidClosed = clamshellObserver?.isLidClosed ?? false
        let power = powerSourceMonitor?.currentSource ?? .ac

        let shouldHoldAssertion = !lidClosed || power == .ac

        if shouldHoldAssertion {
            // Need assertion
            if sleepManager?.isAssertionHeld != true {
                if let sm = sleepManager {
                    let success = sm.preventSleep()
                    if !success {
                        lastError = .assertionFailed
                        Logger.sleep.error("Failed to create sleep prevention assertion during reconciliation")
                        return
                    }
                }
            }
            if isPausedDueToClamshell {
                Logger.sleep.info("Assertion resumed (lid=\(lidClosed ? "closed" : "open"), power=\(String(describing: power)))")
            }
            isPausedDueToClamshell = false
            lastError = nil
        } else {
            // Lid closed + battery → release assertion
            if sleepManager?.isAssertionHeld == true {
                sleepManager?.allowSleep()
                Logger.sleep.info("Assertion suspended (lid=closed, power=battery)")
            }
            isPausedDueToClamshell = true
        }
    }

    // MARK: - Cleanup

    /// Perform full cleanup before app termination.
    func cleanup() {
        stopProcessMonitoring()
        stopObservers()
        if isActive || sleepManager?.isAssertionHeld == true {
            sleepManager?.allowSleep()
        }
        isActive = false
        isPausedDueToClamshell = false
        lastError = nil
        processCount = 0
        claudeProcessesEverDetected = false
        Logger.lifecycle.info("Cleanup complete")
    }
}
