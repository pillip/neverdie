import Foundation
import IOKit
import IOKit.pwr_mgt
import os

/// Manages system sleep prevention using IOPMAssertions.
///
/// SleepManager creates and releases IOPMAssertions to prevent
/// system idle sleep (not display sleep) while Neverdie mode is active.
///
/// ## Usage
/// ```swift
/// let manager = SleepManager()
/// let success = manager.preventSleep()  // Creates assertion
/// manager.allowSleep()                   // Releases assertion
/// ```
///
/// The assertion is automatically released on `deinit` if still held.
final class SleepManager: SleepManaging {
    /// The IOPMAssertion ID for the currently held assertion.
    private var assertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    /// Whether a sleep prevention assertion is currently held.
    private(set) var isAssertionHeld: Bool = false

    /// Human-readable name for the assertion (visible in `pmset -g assertions`).
    private let assertionName: String

    /// Logger for sleep-related events.
    private let logger = Logger.sleep

    // MARK: - Init / Deinit

    /// Create a SleepManager.
    /// - Parameter assertionName: Name shown in `pmset -g assertions`. Defaults to "Neverdie - Preventing sleep for Claude Code".
    init(assertionName: String = "Neverdie - Preventing sleep for Claude Code") {
        self.assertionName = assertionName
    }

    deinit {
        if isAssertionHeld {
            logger.info("SleepManager deinit: releasing held assertion")
            releaseAssertion()
        }
    }

    // MARK: - Public API

    /// Create a system sleep prevention assertion.
    ///
    /// Uses `kIOPMAssertionTypePreventUserIdleSystemSleep` which prevents
    /// system idle sleep but allows display sleep (screen dimming/off).
    ///
    /// - Returns: `true` if the assertion was successfully created, `false` on error.
    func preventSleep() -> Bool {
        guard !isAssertionHeld else {
            logger.debug("preventSleep called but assertion already held")
            return true
        }

        let cfName = assertionName as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            cfName,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isAssertionHeld = true
            logger.info("Sleep prevention assertion created (ID: \(self.assertionID))")
            return true
        } else {
            logger.error("Failed to create sleep assertion (IOReturn: \(result))")
            return false
        }
    }

    /// Release the sleep prevention assertion.
    ///
    /// No-op if no assertion is currently held. Safe to call multiple times.
    func allowSleep() {
        guard isAssertionHeld else {
            logger.debug("allowSleep called but no assertion held")
            return
        }
        releaseAssertion()
    }

    // MARK: - Private

    /// Release the currently held assertion.
    private func releaseAssertion() {
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            logger.info("Sleep prevention assertion released (ID: \(self.assertionID))")
        } else {
            logger.error("Failed to release sleep assertion (IOReturn: \(result))")
        }
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        isAssertionHeld = false
    }
}
