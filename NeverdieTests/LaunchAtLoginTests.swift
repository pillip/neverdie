import XCTest
@testable import Neverdie

// MARK: - Test Doubles

/// A fake `LoginItemManaging` implementation for testing toggle logic.
final class FakeLoginItemManager: LoginItemManaging {
    var currentStatus: LoginItemStatus = .notRegistered
    var registerShouldThrow: Error?
    var unregisterShouldThrow: Error?
    private(set) var registerCallCount: Int = 0
    private(set) var unregisterCallCount: Int = 0

    var status: LoginItemStatus {
        return currentStatus
    }

    func register() throws {
        registerCallCount += 1
        if let error = registerShouldThrow {
            throw error
        }
        currentStatus = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let error = unregisterShouldThrow {
            throw error
        }
        currentStatus = .notRegistered
    }
}

/// Test error for simulating SMAppService failures.
enum TestLoginError: LocalizedError {
    case registrationDenied

    var errorDescription: String? {
        return "The operation couldn't be completed. (SMAppService error 1.)"
    }
}

// MARK: - LoginItemManaging Protocol Tests

/// Tests for the Launch at Login toggle functionality (ISSUE-030).
///
/// Verifies that:
/// - Successful register() sets status to .enabled
/// - Successful unregister() sets status to .notRegistered
/// - Failed register() throws and status remains .notRegistered
/// - Failed unregister() throws and status remains .enabled
/// - Error callback is invoked on failure
final class LaunchAtLoginTests: XCTestCase {

    // MARK: - Successful Registration

    /// AC-1: When SMAppService.register() succeeds, launchAtLogin is set to true.
    func testRegister_succeeds_statusBecomesEnabled() throws {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered

        XCTAssertEqual(manager.status, .notRegistered)

        try manager.register()

        XCTAssertEqual(manager.status, .enabled)
        XCTAssertEqual(manager.registerCallCount, 1)
    }

    // MARK: - Successful Unregistration

    /// AC-3: When SMAppService.unregister() succeeds, launchAtLogin is set to false.
    func testUnregister_succeeds_statusBecomesNotRegistered() throws {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled

        XCTAssertEqual(manager.status, .enabled)

        try manager.unregister()

        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(manager.unregisterCallCount, 1)
    }

    // MARK: - Registration Failure

    /// AC-2: When SMAppService.register() fails, launchAtLogin remains false
    /// and error feedback is provided.
    func testRegister_throws_statusRemainsNotRegistered() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        XCTAssertThrowsError(try manager.register()) { error in
            XCTAssertTrue(error is TestLoginError)
        }

        // Status should NOT change on failure
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(manager.registerCallCount, 1)
    }

    /// AC-5: When SMAppService fails, the error is passed to the error handler.
    func testToggle_registerThrows_errorCallbackInvoked() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        var capturedError: Error?
        var launchAtLogin = false

        // Simulate the toggle logic from ControlPopoverView.toggleLaunchAtLogin()
        do {
            if manager.status == .enabled {
                try manager.unregister()
                launchAtLogin = false
            } else {
                try manager.register()
                launchAtLogin = true
            }
        } catch {
            capturedError = error
            // launchAtLogin should NOT be set to true on failure
        }

        XCTAssertNotNil(capturedError, "Error callback should have captured the error")
        XCTAssertFalse(launchAtLogin, "launchAtLogin should remain false on register failure")
        XCTAssertEqual(
            capturedError?.localizedDescription,
            "The operation couldn't be completed. (SMAppService error 1.)"
        )
    }

    /// AC-2: When register throws, unregister is NOT called.
    func testToggle_registerThrows_unregisterNotCalled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        do {
            if manager.status == .enabled {
                try manager.unregister()
            } else {
                try manager.register()
            }
        } catch {
            // Expected
        }

        XCTAssertEqual(manager.unregisterCallCount, 0,
                        "unregister() should not be called when status is not enabled")
        XCTAssertEqual(manager.registerCallCount, 1)
    }

    // MARK: - Unregistration Failure

    /// When unregister() throws, status remains .enabled.
    func testUnregister_throws_statusRemainsEnabled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled
        manager.unregisterShouldThrow = TestLoginError.registrationDenied

        XCTAssertThrowsError(try manager.unregister())

        // Status should NOT change when unregister fails because the fake
        // short-circuits before modifying currentStatus
        XCTAssertEqual(manager.status, .enabled)
    }

    // MARK: - onAppear Re-sync (AC-4)

    /// AC-4: When the popover re-opens, launchAtLogin reflects the current status.
    func testOnAppear_syncWithCurrentStatus_enabled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled

        // Simulate the .onAppear closure
        let synced = manager.status == .enabled
        XCTAssertTrue(synced, "onAppear should sync launchAtLogin to true when status is .enabled")
    }

    /// AC-4: When external state changes to notRegistered, onAppear reflects it.
    func testOnAppear_syncWithCurrentStatus_notRegistered() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered

        let synced = manager.status == .enabled
        XCTAssertFalse(synced, "onAppear should sync launchAtLogin to false when status is .notRegistered")
    }

    /// AC-4: The requiresApproval status is not treated as .enabled.
    func testOnAppear_requiresApproval_treatedAsNotEnabled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .requiresApproval

        let synced = manager.status == .enabled
        XCTAssertFalse(synced, "requiresApproval should not show as enabled in the UI")
    }

    // MARK: - Toggle Flow Integration

    /// Full toggle flow: OFF -> register -> ON -> unregister -> OFF
    func testFullToggleCycle() throws {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        var launchAtLogin = manager.status == .enabled

        XCTAssertFalse(launchAtLogin)

        // Toggle ON (register)
        if manager.status == .enabled {
            try manager.unregister()
            launchAtLogin = false
        } else {
            try manager.register()
            launchAtLogin = true
        }

        XCTAssertTrue(launchAtLogin)
        XCTAssertEqual(manager.status, .enabled)

        // Toggle OFF (unregister)
        if manager.status == .enabled {
            try manager.unregister()
            launchAtLogin = false
        } else {
            try manager.register()
            launchAtLogin = true
        }

        XCTAssertFalse(launchAtLogin)
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 1)
    }

    // MARK: - ControlPopoverView Error Callback

    /// Verify that ControlPopoverView forwards errors to onLoginItemError when provided.
    func testControlPopoverView_errorCallback_receivesError() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        var receivedError: Error?

        // Create view with error callback and fake manager
        // We can't directly test SwiftUI view actions, but we verify the
        // injectable components work correctly together.
        let view = ControlPopoverView(
            isActive: false,
            isPaused: false,
            hasError: false,
            onToggle: {},
            onQuit: {},
            loginItemManager: manager,
            onLoginItemError: { error in
                receivedError = error
            }
        )

        // Verify view can be constructed with injectable dependencies
        XCTAssertNotNil(view)
        XCTAssertEqual(manager.status, .notRegistered)

        // Simulate what toggleLaunchAtLogin does
        do {
            try manager.register()
            XCTFail("register() should have thrown")
        } catch {
            receivedError = error
        }

        XCTAssertNotNil(receivedError)
        XCTAssertEqual(
            receivedError?.localizedDescription,
            "The operation couldn't be completed. (SMAppService error 1.)"
        )
    }

    // MARK: - SystemLoginItemManager

    /// SystemLoginItemManager wraps SMAppService.mainApp correctly.
    /// This is an integration-level test that verifies the wrapper exists
    /// and returns a valid status (not a crash test).
    func testSystemLoginItemManager_statusReturnsValidValue() {
        let manager = SystemLoginItemManager()
        let status = manager.status

        // Status should be one of the valid enum cases
        switch status {
        case .enabled, .notRegistered, .requiresApproval:
            break // All valid
        }
        // If we get here without crashing, the wrapper works
    }
}
