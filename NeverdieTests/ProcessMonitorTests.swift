import XCTest
@testable import Neverdie

// MARK: - Test Doubles

/// Fake ProcessMonitor for testing auto-ON/auto-OFF logic in AppState.
final class FakeProcessMonitor: ProcessMonitoring {
    private(set) var isPolling: Bool = false
    private var onUpdate: ((Int) -> Void)?
    var stubbedCount: Int = 0

    func pollOnce() -> Int {
        return stubbedCount
    }

    func startPolling(onUpdate: @escaping (Int) -> Void) {
        isPolling = true
        self.onUpdate = onUpdate
        // Fire immediately like the real implementation
        onUpdate(stubbedCount)
    }

    func stopPolling() {
        isPolling = false
        onUpdate = nil
    }

    /// Simulate a poll update with a given count.
    func simulateUpdate(_ count: Int) {
        stubbedCount = count
        onUpdate?(count)
    }
}

// MARK: - ProcessMonitor Unit Tests

final class ProcessMonitorPollTests: XCTestCase {

    /// pollOnce returns a non-negative integer (basic sanity on real system).
    func testPollOnce_returnsNonNegative() {
        let monitor = ProcessMonitor()
        let count = monitor.pollOnce()
        XCTAssertGreaterThanOrEqual(count, 0)
    }

    /// Target names include exactly "claude" and "claude-code".
    func testTargetNames_exactSet() {
        XCTAssertEqual(ProcessMonitor.targetNames, ["claude", "claude-code"])
    }

    /// stopPolling invalidates the timer; subsequent callbacks don't fire.
    func testStopPolling_invalidatesTimer() {
        let monitor = ProcessMonitor()
        var callCount = 0
        monitor.startPolling { _ in callCount += 1 }
        // Initial fire
        XCTAssertEqual(callCount, 1)

        monitor.stopPolling()

        // Wait briefly to ensure no more callbacks
        let expectation = XCTestExpectation(description: "No further callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertEqual(callCount, 1, "No callbacks after stopPolling")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Auto-ON / Auto-OFF Integration Tests

final class AutoOnOffTests: XCTestCase {

    private var sleepSpy: SleepManagingSpy!
    private var clamshell: FakeClamshellObserver!
    private var power: FakePowerSourceMonitor!
    private var processMonitor: FakeProcessMonitor!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        sleepSpy = SleepManagingSpy()
        clamshell = FakeClamshellObserver()
        power = FakePowerSourceMonitor()
        processMonitor = FakeProcessMonitor()
        appState = AppState(
            sleepManager: sleepSpy,
            clamshellObserver: clamshell,
            powerSourceMonitor: power,
            processMonitor: processMonitor,
            debounceInterval: 0
        )
        appState.startObservers()
    }

    override func tearDown() {
        appState.cleanup()
        super.tearDown()
    }

    // MARK: - Auto-ON Tests

    /// AC 7: OFF + count >= 1 → auto-activate with activationSource=.auto
    func testAutoOn_whenOffAndProcessDetected() {
        XCTAssertFalse(appState.isActive)

        appState.handleProcessUpdate(1)

        XCTAssertTrue(appState.isActive, "Should auto-activate when Claude detected")
        XCTAssertEqual(appState.activationSource, .auto)
        XCTAssertTrue(appState.claudeProcessesEverDetected)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
    }

    /// Auto-ON sets activationSource = .auto
    func testAutoOn_setsActivationSourceAuto() {
        appState.handleProcessUpdate(2)
        XCTAssertEqual(appState.activationSource, .auto)
    }

    /// Auto-ON while clamshell on battery → isActive=true, assertion NOT held
    func testAutoOn_clamshellOnBattery_isPausedNoAssertion() {
        power.simulateTransition(.battery)
        clamshell.simulateClose()

        appState.handleProcessUpdate(1)

        XCTAssertTrue(appState.isActive, "Should auto-activate")
        XCTAssertTrue(appState.isPausedDueToClamshell, "Should be paused due to clamshell")
        XCTAssertFalse(sleepSpy.isAssertionHeld, "Assertion should NOT be held on battery+clamshell")
    }

    /// Auto-ON does not fire when already active
    func testAutoOn_doesNotFireWhenAlreadyActive() {
        appState.toggle() // manual ON
        XCTAssertEqual(appState.activationSource, .manual)

        appState.handleProcessUpdate(1)

        XCTAssertEqual(appState.activationSource, .manual, "Should not change source")
        XCTAssertTrue(appState.claudeProcessesEverDetected, "Should track detected processes")
    }

    // MARK: - Auto-OFF Tests

    /// AC 4: ON + claudeProcessesEverDetected + count==0 → auto-deactivate
    func testAutoOff_whenActiveAndAllProcessesGone() {
        appState.handleProcessUpdate(1) // auto-ON
        XCTAssertTrue(appState.isActive)
        XCTAssertTrue(appState.claudeProcessesEverDetected)

        appState.handleProcessUpdate(0)

        XCTAssertFalse(appState.isActive, "Should auto-deactivate")
        XCTAssertFalse(sleepSpy.isAssertionHeld)
    }

    /// AC 5: Manual ON, no processes ever detected, count==0 → stays ON
    func testAutoOff_manualActivation_noProcessesEverDetected_staysOn() {
        appState.toggle() // manual ON
        XCTAssertTrue(appState.isActive)
        XCTAssertFalse(appState.claudeProcessesEverDetected)

        appState.handleProcessUpdate(0)

        XCTAssertTrue(appState.isActive, "Should stay ON (manual, no processes ever detected)")
    }

    /// AC 6: ON + 2 processes, 1 terminates → stays ON
    func testPartialExit_staysOn() {
        appState.handleProcessUpdate(2) // auto-ON
        XCTAssertTrue(appState.isActive)

        appState.handleProcessUpdate(1)

        XCTAssertTrue(appState.isActive, "Should stay ON with 1 remaining process")
        XCTAssertTrue(sleepSpy.isAssertionHeld)
    }

    /// Auto-OFF while isPausedDueToClamshell → isActive=false, paused cleared
    func testAutoOff_whilePaused_clearsPausedState() {
        power.simulateTransition(.battery)
        clamshell.simulateClose()

        appState.handleProcessUpdate(1) // auto-ON (paused due to clamshell)
        XCTAssertTrue(appState.isActive)
        XCTAssertTrue(appState.isPausedDueToClamshell)

        appState.handleProcessUpdate(0) // auto-OFF

        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell, "Paused should be cleared on auto-OFF")
    }

    /// Manual toggle sets activationSource = .manual
    func testManualToggle_setsManualSource() {
        appState.toggle()
        XCTAssertEqual(appState.activationSource, .manual)
    }

    /// Cleanup stops process monitoring
    func testCleanup_stopsProcessMonitoring() {
        appState.startProcessMonitoring()
        XCTAssertTrue(processMonitor.isPolling)

        appState.cleanup()

        XCTAssertFalse(processMonitor.isPolling)
        XCTAssertEqual(appState.processCount, 0)
        XCTAssertFalse(appState.claudeProcessesEverDetected)
    }

    /// processCount is updated on each poll
    func testProcessCount_updatedOnPoll() {
        appState.handleProcessUpdate(3)
        XCTAssertEqual(appState.processCount, 3)

        appState.handleProcessUpdate(1)
        XCTAssertEqual(appState.processCount, 1)
    }

    /// Full auto cycle: OFF → auto-ON (process appears) → auto-OFF (process ends)
    func testFullAutoCycle() {
        // Start OFF
        XCTAssertFalse(appState.isActive)

        // Process appears → auto-ON
        appState.handleProcessUpdate(1)
        XCTAssertTrue(appState.isActive)
        XCTAssertEqual(appState.activationSource, .auto)
        XCTAssertTrue(sleepSpy.isAssertionHeld)

        // Process ends → auto-OFF
        appState.handleProcessUpdate(0)
        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(sleepSpy.isAssertionHeld)
    }

    /// startProcessMonitoring fires initial poll
    func testStartProcessMonitoring_firesInitialPoll() {
        processMonitor.stubbedCount = 2
        appState.startProcessMonitoring()

        XCTAssertTrue(processMonitor.isPolling)
        // Initial poll should trigger auto-ON since count > 0
        XCTAssertTrue(appState.isActive)
        XCTAssertEqual(appState.processCount, 2)
    }
}
