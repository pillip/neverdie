import Foundation
import os

/// Source of the current activation.
enum ActivationSource: Equatable, Sendable {
    /// User manually toggled Neverdie ON.
    case manual
    /// Neverdie activated automatically (e.g., process detected).
    case auto
}

/// Possible error states for the Neverdie app.
enum NeverdieError: Equatable, Sendable {
    case assertionFailed
    case processDetectionFailed
}

/// Central state management for the Neverdie app.
///
/// AppState is the single source of truth for all UI and service state.
/// It coordinates SleepManager and ProcessMonitor via
/// protocol-based dependency injection.
///
/// ## State Machine
/// ```
/// OFF -> ON_MANUAL (toggle, no processes) -> ON_TRACKING (processes detected) -> OFF (auto, all ended)
/// ```
@Observable
final class AppState {
    // MARK: - Published State

    /// Whether Neverdie mode is active (sleep prevention enabled).
    private(set) var isActive: Bool = false

    /// How the current activation was triggered.
    private(set) var activationSource: ActivationSource = .manual

    /// Number of currently detected Claude Code processes.
    private(set) var processCount: Int = 0

    /// Whether Claude Code processes have ever been detected during this activation cycle.
    private(set) var claudeProcessesEverDetected: Bool = false

    /// The most recent error, if any.
    private(set) var lastError: NeverdieError? = nil

    // MARK: - Dependencies

    private let sleepManager: SleepManaging?
    private let processMonitor: ProcessMonitoring?

    // MARK: - Internal State

    /// Timestamp of the last toggle call, used for debounce.
    private var lastToggleDate: Date = .distantPast

    /// Debounce threshold in seconds.
    private let debounceInterval: TimeInterval = 0.3

    // MARK: - Init

    /// Create an AppState with optional dependency injection.
    ///
    /// - Parameters:
    ///   - sleepManager: Sleep prevention manager. Pass `nil` for testing without IOKit.
    ///   - processMonitor: Process detection monitor. Pass `nil` for testing.
    init(
        sleepManager: SleepManaging? = nil,
        processMonitor: ProcessMonitoring? = nil
    ) {
        self.sleepManager = sleepManager
        self.processMonitor = processMonitor
    }

    // MARK: - Toggle

    /// Toggle Neverdie mode ON/OFF with 300ms debounce.
    ///
    /// When toggling ON:
    /// - Calls `sleepManager.preventSleep()`
    /// - Starts process and token monitoring
    ///
    /// When toggling OFF:
    /// - Calls `sleepManager.allowSleep()`
    /// - Stops all monitoring
    /// - Resets tracking state
    func toggle() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleDate) >= debounceInterval else {
            Logger.lifecycle.debug("Toggle debounced (within 300ms)")
            return
        }
        lastToggleDate = now

        if isActive {
            deactivate(source: .manual)
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
        activationSource = .manual
        startMonitoring()
        Logger.lifecycle.info("Neverdie activated (manual)")
    }

    /// Deactivate Neverdie mode.
    /// - Parameter source: Whether deactivation was manual or automatic.
    private func deactivate(source: ActivationSource) {
        sleepManager?.allowSleep()
        isActive = false
        activationSource = source
        claudeProcessesEverDetected = false
        processCount = 0
        stopMonitoring()
        Logger.lifecycle.info("Neverdie deactivated (\(source == .manual ? "manual" : "auto"))")
    }

    // MARK: - Process Count Updates

    /// Update the process count from a polling callback.
    ///
    /// Implements the auto-OFF state machine:
    /// - If processes are detected, sets `claudeProcessesEverDetected = true`.
    /// - If count drops to 0 and processes were previously detected, auto-deactivates.
    func updateProcessCount(_ count: Int) {
        processCount = count
        if count > 0 {
            claudeProcessesEverDetected = true
            if activationSource == .manual {
                activationSource = .auto
            }
        } else if count == 0 && claudeProcessesEverDetected && isActive {
            Logger.lifecycle.info("All Claude processes ended -- auto-OFF triggered")
            deactivate(source: .auto)
        }
    }

    // MARK: - Monitoring

    /// Start process and token monitoring.
    func startMonitoring() {
        processMonitor?.startPolling { [weak self] count in
            self?.updateProcessCount(count)
        }
        Logger.lifecycle.debug("Monitoring started")
    }

    /// Stop all monitoring.
    func stopMonitoring() {
        processMonitor?.stopPolling()
        Logger.lifecycle.debug("Monitoring stopped")
    }

    // MARK: - Cleanup

    /// Perform full cleanup before app termination.
    ///
    /// Releases any held sleep assertion and stops all monitors.
    /// This method is idempotent and safe to call multiple times.
    func cleanup() {
        if isActive {
            sleepManager?.allowSleep()
        }
        isActive = false
        processCount = 0
        claudeProcessesEverDetected = false
        lastError = nil
        stopMonitoring()
        Logger.lifecycle.info("Cleanup complete")
    }
}
