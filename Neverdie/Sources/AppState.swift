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
@Observable
final class AppState {
    // MARK: - State

    /// Whether Neverdie mode is active (sleep prevention enabled).
    private(set) var isActive: Bool = false

    /// The most recent error, if any.
    private(set) var lastError: NeverdieError? = nil

    // MARK: - Dependencies

    private let sleepManager: SleepManaging?

    // MARK: - Internal State

    private var lastToggleDate: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.3

    // MARK: - Init

    init(sleepManager: SleepManaging? = nil) {
        self.sleepManager = sleepManager
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
        if let sm = sleepManager {
            let success = sm.preventSleep()
            if !success {
                lastError = .assertionFailed
                Logger.sleep.error("Failed to create sleep prevention assertion")
                return
            }
        }
        lastError = nil
        isActive = true
        Logger.lifecycle.info("Neverdie activated")
    }

    private func deactivate() {
        sleepManager?.allowSleep()
        isActive = false
        Logger.lifecycle.info("Neverdie deactivated")
    }

    // MARK: - Cleanup

    /// Perform full cleanup before app termination.
    func cleanup() {
        if isActive {
            sleepManager?.allowSleep()
        }
        isActive = false
        lastError = nil
        Logger.lifecycle.info("Cleanup complete")
    }
}
