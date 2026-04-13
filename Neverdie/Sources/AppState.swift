import Foundation
import os

/// Possible error states for the Neverdie app.
enum NeverdieError: Equatable, Sendable {
    case assertionFailed
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

    // MARK: - Dependencies

    private let sleepManager: SleepManaging?
    private(set) var clamshellObserver: ClamshellObserving?
    private(set) var powerSourceMonitor: PowerSourceMonitoring?

    // MARK: - Internal State

    private var lastToggleDate: Date = .distantPast
    let debounceInterval: TimeInterval

    // MARK: - Init

    init(sleepManager: SleepManaging? = nil,
         clamshellObserver: ClamshellObserving? = nil,
         powerSourceMonitor: PowerSourceMonitoring? = nil,
         debounceInterval: TimeInterval = 0.3) {
        self.sleepManager = sleepManager
        self.clamshellObserver = clamshellObserver
        self.powerSourceMonitor = powerSourceMonitor
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
        Logger.lifecycle.info("Neverdie activated")
        reconcileAssertion()
    }

    private func deactivate() {
        sleepManager?.allowSleep()
        isActive = false
        isPausedDueToClamshell = false
        Logger.lifecycle.info("Neverdie deactivated")
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
        stopObservers()
        if isActive || sleepManager?.isAssertionHeld == true {
            sleepManager?.allowSleep()
        }
        isActive = false
        isPausedDueToClamshell = false
        lastError = nil
        Logger.lifecycle.info("Cleanup complete")
    }
}
