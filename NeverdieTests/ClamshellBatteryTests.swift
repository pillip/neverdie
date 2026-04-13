import XCTest
@testable import Neverdie

// MARK: - Test Doubles

final class SleepManagingSpy: SleepManaging {
    private(set) var isAssertionHeld: Bool = false
    private(set) var preventSleepCallCount: Int = 0
    private(set) var allowSleepCallCount: Int = 0
    var preventSleepShouldFail: Bool = false

    func preventSleep() -> Bool {
        preventSleepCallCount += 1
        if preventSleepShouldFail { return false }
        isAssertionHeld = true
        return true
    }

    func allowSleep() {
        allowSleepCallCount += 1
        isAssertionHeld = false
    }
}

final class FakeClamshellObserver: ClamshellObserving {
    private(set) var isLidClosed: Bool = false
    private var onChange: ((Bool) -> Void)?

    func start(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func simulateClose() {
        isLidClosed = true
        onChange?(true)
    }

    func simulateOpen() {
        isLidClosed = false
        onChange?(false)
    }
}

final class FakePowerSourceMonitor: PowerSourceMonitoring {
    private(set) var currentSource: PowerSource = .ac
    private var onChange: ((PowerSource) -> Void)?

    func start(onChange: @escaping (PowerSource) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func simulateTransition(_ source: PowerSource) {
        currentSource = source
        onChange?(source)
    }
}

// MARK: - Tests

final class ClamshellBatteryTests: XCTestCase {

    private var sleepSpy: SleepManagingSpy!
    private var clamshell: FakeClamshellObserver!
    private var power: FakePowerSourceMonitor!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        sleepSpy = SleepManagingSpy()
        clamshell = FakeClamshellObserver()
        power = FakePowerSourceMonitor()
        appState = AppState(
            sleepManager: sleepSpy,
            clamshellObserver: clamshell,
            powerSourceMonitor: power,
            debounceInterval: 0
        )
        appState.startObservers()
    }

    override func tearDown() {
        appState.cleanup()
        super.tearDown()
    }

    // MARK: - AC 1: Lid close on battery → assertion released, isActive stays true

    func testLidCloseOnBattery_releasesAssertion() {
        power.simulateTransition(.battery)
        appState.toggle() // activate
        XCTAssertTrue(appState.isActive)
        XCTAssertTrue(sleepSpy.isAssertionHeld)

        clamshell.simulateClose()

        XCTAssertTrue(appState.isActive, "isActive should remain true")
        XCTAssertTrue(appState.isPausedDueToClamshell, "should be paused")
        XCTAssertFalse(sleepSpy.isAssertionHeld, "assertion should be released")
    }

    // MARK: - AC 2: Lid open after pause → assertion re-acquired

    func testLidOpenAfterPause_reacquiresAssertion() {
        power.simulateTransition(.battery)
        appState.toggle()
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        clamshell.simulateOpen()

        XCTAssertTrue(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
        XCTAssertEqual(sleepSpy.preventSleepCallCount, 2, "initial + resume")
    }

    // MARK: - AC 3: Lid close on AC → assertion NOT released

    func testLidCloseOnAC_assertionStaysHeld() {
        power.simulateTransition(.ac)
        appState.toggle()
        XCTAssertTrue(sleepSpy.isAssertionHeld)

        clamshell.simulateClose()

        XCTAssertFalse(appState.isPausedDueToClamshell)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
    }

    // MARK: - AC 4: Battery→AC while lid closed → assertion re-acquired

    func testBatteryToAC_whileLidClosed_reacquiresAssertion() {
        power.simulateTransition(.battery)
        appState.toggle()
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)
        XCTAssertFalse(sleepSpy.isAssertionHeld)

        power.simulateTransition(.ac)

        XCTAssertFalse(appState.isPausedDueToClamshell)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
    }

    // MARK: - AC 5: AC→Battery while lid closed → assertion released

    func testACToBattery_whileLidClosed_releasesAssertion() {
        power.simulateTransition(.ac)
        appState.toggle()
        clamshell.simulateClose()
        XCTAssertTrue(sleepSpy.isAssertionHeld, "AC + lid closed → held")
        XCTAssertFalse(appState.isPausedDueToClamshell)

        power.simulateTransition(.battery)

        XCTAssertTrue(appState.isPausedDueToClamshell)
        XCTAssertFalse(sleepSpy.isAssertionHeld)
    }

    // MARK: - AC 6: isActive == false → no-op on lid/power changes

    func testInactive_lidAndPowerChanges_noOp() {
        XCTAssertFalse(appState.isActive)

        clamshell.simulateClose()
        power.simulateTransition(.battery)
        clamshell.simulateOpen()
        power.simulateTransition(.ac)

        XCTAssertEqual(sleepSpy.preventSleepCallCount, 0)
        XCTAssertEqual(sleepSpy.allowSleepCallCount, 0)
        XCTAssertFalse(appState.isPausedDueToClamshell)
    }

    // MARK: - AC 7: Toggle OFF while paused → clears paused substate

    func testToggleOff_whilePaused_clearsPausedState() {
        power.simulateTransition(.battery)
        appState.toggle() // ON
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        appState.toggle() // OFF

        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell)
    }

    // MARK: - AC 8: Cleanup while paused → observers stopped, no leaks

    func testCleanup_whilePaused_stopsObservers() {
        power.simulateTransition(.battery)
        appState.toggle()
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        appState.cleanup()

        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell)
        // After cleanup, observer callbacks should be nil (stopped)
        // Simulate events — they should not cause changes
        clamshell.simulateOpen()
        XCTAssertFalse(appState.isActive)
    }

    // MARK: - Edge: No observers injected → defaults to AC behavior

    func testNoObservers_defaultsToACBehavior() {
        let stateNoObservers = AppState(sleepManager: sleepSpy, debounceInterval: 0)
        stateNoObservers.toggle()

        XCTAssertTrue(stateNoObservers.isActive)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
        XCTAssertFalse(stateNoObservers.isPausedDueToClamshell)

        stateNoObservers.cleanup()
    }

    // MARK: - Edge: preventSleep fails during reconciliation

    func testPreventSleepFails_duringReconciliation_setsError() {
        power.simulateTransition(.battery)
        appState.toggle()
        clamshell.simulateClose() // paused

        sleepSpy.preventSleepShouldFail = true
        clamshell.simulateOpen() // try to resume → fails

        XCTAssertEqual(appState.lastError, .assertionFailed)
    }

    // MARK: - Full cycle: ON → lid close (battery) → lid open → OFF

    func testFullCycle() {
        power.simulateTransition(.battery)

        // Activate
        appState.toggle()
        XCTAssertTrue(appState.isActive)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
        XCTAssertEqual(sleepSpy.preventSleepCallCount, 1)

        // Close lid → paused
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)
        XCTAssertFalse(sleepSpy.isAssertionHeld)
        XCTAssertEqual(sleepSpy.allowSleepCallCount, 1)

        // Open lid → resumed
        clamshell.simulateOpen()
        XCTAssertFalse(appState.isPausedDueToClamshell)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
        XCTAssertEqual(sleepSpy.preventSleepCallCount, 2)

        // Deactivate
        appState.toggle()
        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(sleepSpy.isAssertionHeld)
    }
}
