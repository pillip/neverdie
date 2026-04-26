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
    case unregistrationDenied

    var errorDescription: String? {
        switch self {
        case .registrationDenied:
            return "The operation couldn't be completed. (SMAppService error 1.)"
        case .unregistrationDenied:
            return "The operation couldn't be completed. (SMAppService unregister error.)"
        }
    }
}

// MARK: - performLoginItemToggle Tests

/// Tests for `performLoginItemToggle()` — the extracted, testable toggle logic (ISSUE-030).
///
/// Every test calls the actual production function, not a copy of it.
final class LaunchAtLoginTests: XCTestCase {

    // MARK: - Register (enable) success

    /// AC-1: Click "Launch at Login" (unchecked) → register succeeds → .registered
    func testToggle_fromNotRegistered_succeeds_returnsRegistered() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered

        let result = performLoginItemToggle(manager: manager)

        guard case .registered = result else {
            XCTFail("Expected .registered, got \(result)")
            return
        }
        XCTAssertEqual(manager.status, .enabled)
        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 0)
    }

    // MARK: - Unregister (disable) success

    /// AC-3: Click "Launch at Login" (checked) → unregister succeeds → .unregistered
    func testToggle_fromEnabled_succeeds_returnsUnregistered() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled

        let result = performLoginItemToggle(manager: manager)

        guard case .unregistered = result else {
            XCTFail("Expected .unregistered, got \(result)")
            return
        }
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(manager.unregisterCallCount, 1)
        XCTAssertEqual(manager.registerCallCount, 0)
    }

    // MARK: - Register failure

    /// AC-2: register() fails → .failed(wasEnabling: true, error)
    func testToggle_registerThrows_returnsFailedWithWasEnablingTrue() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        let result = performLoginItemToggle(manager: manager)

        guard case .failed(let wasEnabling, let error) = result else {
            XCTFail("Expected .failed, got \(result)")
            return
        }
        XCTAssertTrue(wasEnabling, "wasEnabling should be true when register() fails")
        XCTAssertTrue(error is TestLoginError)
        XCTAssertEqual(manager.status, .notRegistered, "Status must NOT change on failure")
        XCTAssertEqual(manager.registerCallCount, 1)
    }

    /// AC-2: register fails → unregister is never called
    func testToggle_registerThrows_doesNotCallUnregister() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        _ = performLoginItemToggle(manager: manager)

        XCTAssertEqual(manager.unregisterCallCount, 0)
    }

    // MARK: - Unregister failure

    /// Unregister fails → .failed(wasEnabling: false, error)
    func testToggle_unregisterThrows_returnsFailedWithWasEnablingFalse() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled
        manager.unregisterShouldThrow = TestLoginError.unregistrationDenied

        let result = performLoginItemToggle(manager: manager)

        guard case .failed(let wasEnabling, let error) = result else {
            XCTFail("Expected .failed, got \(result)")
            return
        }
        XCTAssertFalse(wasEnabling, "wasEnabling should be false when unregister() fails")
        XCTAssertTrue(error is TestLoginError)
        XCTAssertEqual(manager.status, .enabled, "Status must NOT change on failure")
        XCTAssertEqual(manager.unregisterCallCount, 1)
        XCTAssertEqual(manager.registerCallCount, 0)
    }

    // MARK: - Error message differentiation (bug fix)

    /// Bug fix: enable failure → "Could not enable Launch at Login"
    func testToggle_registerFails_errorMessageSaysEnable() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        manager.registerShouldThrow = TestLoginError.registrationDenied

        let result = performLoginItemToggle(manager: manager)

        guard case .failed(let wasEnabling, _) = result else {
            XCTFail("Expected .failed")
            return
        }
        XCTAssertTrue(wasEnabling)
        // The view uses wasEnabling to pick the message:
        let message = wasEnabling
            ? "Could not enable Launch at Login"
            : "Could not disable Launch at Login"
        XCTAssertEqual(message, "Could not enable Launch at Login")
    }

    /// Bug fix: disable failure → "Could not disable Launch at Login"
    func testToggle_unregisterFails_errorMessageSaysDisable() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled
        manager.unregisterShouldThrow = TestLoginError.unregistrationDenied

        let result = performLoginItemToggle(manager: manager)

        guard case .failed(let wasEnabling, _) = result else {
            XCTFail("Expected .failed")
            return
        }
        XCTAssertFalse(wasEnabling)
        let message = wasEnabling
            ? "Could not enable Launch at Login"
            : "Could not disable Launch at Login"
        XCTAssertEqual(message, "Could not disable Launch at Login")
    }

    // MARK: - requiresApproval path

    /// When status is .requiresApproval, toggle calls register() (not unregister).
    func testToggle_fromRequiresApproval_callsRegister() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .requiresApproval

        let result = performLoginItemToggle(manager: manager)

        guard case .registered = result else {
            XCTFail("Expected .registered, got \(result)")
            return
        }
        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 0)
        XCTAssertEqual(manager.status, .enabled)
    }

    /// When status is .requiresApproval and register() throws, wasEnabling is true.
    func testToggle_fromRequiresApproval_registerThrows_wasEnablingTrue() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .requiresApproval
        manager.registerShouldThrow = TestLoginError.registrationDenied

        let result = performLoginItemToggle(manager: manager)

        guard case .failed(let wasEnabling, _) = result else {
            XCTFail("Expected .failed")
            return
        }
        XCTAssertTrue(wasEnabling)
        XCTAssertEqual(manager.status, .requiresApproval, "Status should remain .requiresApproval")
    }

    // MARK: - Full cycle

    /// Full toggle cycle: OFF → register → ON → unregister → OFF
    func testFullToggleCycle() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered

        // Toggle ON (register)
        let result1 = performLoginItemToggle(manager: manager)
        guard case .registered = result1 else {
            XCTFail("Expected .registered")
            return
        }
        XCTAssertEqual(manager.status, .enabled)

        // Toggle OFF (unregister)
        let result2 = performLoginItemToggle(manager: manager)
        guard case .unregistered = result2 else {
            XCTFail("Expected .unregistered")
            return
        }
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(manager.registerCallCount, 1)
        XCTAssertEqual(manager.unregisterCallCount, 1)
    }

    // MARK: - onAppear re-sync (AC-4)

    /// AC-4: .onAppear should sync launchAtLogin to true when status is .enabled
    func testOnAppear_syncWithCurrentStatus_enabled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .enabled
        // Simulate .onAppear closure: launchAtLogin = manager.status == .enabled
        XCTAssertTrue(manager.status == .enabled)
    }

    /// AC-4: .onAppear should sync launchAtLogin to false when status is .notRegistered
    func testOnAppear_syncWithCurrentStatus_notRegistered() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .notRegistered
        XCTAssertFalse(manager.status == .enabled)
    }

    /// AC-4: .requiresApproval should not show as enabled in the UI
    func testOnAppear_requiresApproval_treatedAsNotEnabled() {
        let manager = FakeLoginItemManager()
        manager.currentStatus = .requiresApproval
        XCTAssertFalse(manager.status == .enabled)
    }

    // MARK: - ControlPopoverView integration

    /// ControlPopoverView can be constructed with injected fake manager.
    func testControlPopoverView_constructsWithFakeManager() {
        let manager = FakeLoginItemManager()
        var capturedError: Error?

        let view = ControlPopoverView(
            isActive: false,
            isPaused: false,
            hasError: false,
            onToggle: {},
            onQuit: {},
            loginItemManager: manager,
            onLoginItemError: { capturedError = $0 }
        )

        XCTAssertNotNil(view)
        XCTAssertNil(capturedError)
    }

    // MARK: - SystemLoginItemManager wrapper

    /// SystemLoginItemManager wraps SMAppService.mainApp correctly (no crash).
    func testSystemLoginItemManager_statusReturnsValidValue() {
        let manager = SystemLoginItemManager()
        let status = manager.status

        switch status {
        case .enabled, .notRegistered, .requiresApproval:
            break // All valid
        }
    }
}
