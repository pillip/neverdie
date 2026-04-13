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

    // MARK: - Stress: Rapid lid open/close idempotency (ISSUE-026)

    /// 50 rapid lid open/close cycles ending with close on battery -> isPaused true, assertion released.
    func testRapidLidCycles_finalCloseOnBattery_isPausedTrue() {
        power.simulateTransition(.battery)
        appState.toggle() // activate
        XCTAssertTrue(appState.isActive)

        for _ in 0..<50 {
            clamshell.simulateClose()
            clamshell.simulateOpen()
        }
        // Final close on battery
        clamshell.simulateClose()

        XCTAssertTrue(appState.isActive, "isActive should remain true")
        XCTAssertTrue(appState.isPausedDueToClamshell, "should be paused after final close on battery")
        XCTAssertFalse(sleepSpy.isAssertionHeld, "assertion should be released")

        // No assertion leaks: preventSleep - allowSleep is 0 or 1
        let delta = sleepSpy.preventSleepCallCount - sleepSpy.allowSleepCallCount
        XCTAssertTrue(delta == 0 || delta == 1,
                       "Assertion leak detected: prevent=\(sleepSpy.preventSleepCallCount) allow=\(sleepSpy.allowSleepCallCount)")
    }

    /// 50 rapid AC/battery transitions with lid closed -> final state matches last power source.
    func testRapidPowerCycles_lidClosed_finalStateMatchesLastSource() {
        appState.toggle() // activate on AC
        clamshell.simulateClose()
        XCTAssertFalse(appState.isPausedDueToClamshell, "AC + lid closed -> not paused")

        for _ in 0..<50 {
            power.simulateTransition(.battery)
            power.simulateTransition(.ac)
        }
        // Final transition to battery
        power.simulateTransition(.battery)

        XCTAssertTrue(appState.isPausedDueToClamshell, "lid closed + battery -> paused")
        XCTAssertFalse(sleepSpy.isAssertionHeld)

        let delta = sleepSpy.preventSleepCallCount - sleepSpy.allowSleepCallCount
        XCTAssertTrue(delta == 0 || delta == 1,
                       "Assertion leak: prevent=\(sleepSpy.preventSleepCallCount) allow=\(sleepSpy.allowSleepCallCount)")
    }

    /// 50 rapid AC/battery transitions with lid closed -> final AC means not paused.
    func testRapidPowerCycles_lidClosed_finalAC_notPaused() {
        appState.toggle() // activate on AC
        clamshell.simulateClose()

        for _ in 0..<50 {
            power.simulateTransition(.battery)
            power.simulateTransition(.ac)
        }

        XCTAssertFalse(appState.isPausedDueToClamshell, "lid closed + AC -> not paused")
        XCTAssertTrue(sleepSpy.isAssertionHeld)
    }

    /// 100 interleaved lid+power events -> final state consistent with last (lid, power) pair.
    func testInterleavedLidAndPowerEvents_finalStateConsistent() {
        appState.toggle() // activate

        // Interleave lid and power events in varying patterns
        for i in 0..<100 {
            if i % 3 == 0 {
                clamshell.simulateClose()
            } else if i % 3 == 1 {
                clamshell.simulateOpen()
            } else {
                power.simulateTransition(i % 5 == 0 ? .battery : .ac)
            }
        }

        // Set known final state: lid closed + battery
        clamshell.simulateClose()
        power.simulateTransition(.battery)

        XCTAssertTrue(appState.isActive)
        XCTAssertTrue(appState.isPausedDueToClamshell)
        XCTAssertFalse(sleepSpy.isAssertionHeld)

        let delta = sleepSpy.preventSleepCallCount - sleepSpy.allowSleepCallCount
        XCTAssertTrue(delta == 0 || delta == 1,
                       "Assertion leak: prevent=\(sleepSpy.preventSleepCallCount) allow=\(sleepSpy.allowSleepCallCount)")
    }

    /// 100 interleaved events ending with lid open + AC -> assertion held, not paused.
    func testInterleavedEvents_finalOpenAC_assertionHeld() {
        appState.toggle() // activate

        for i in 0..<100 {
            switch i % 4 {
            case 0: clamshell.simulateClose()
            case 1: power.simulateTransition(.battery)
            case 2: clamshell.simulateOpen()
            case 3: power.simulateTransition(.ac)
            default: break
            }
        }

        // Set known final state: lid open + AC
        clamshell.simulateOpen()
        power.simulateTransition(.ac)

        XCTAssertTrue(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell)
        XCTAssertTrue(sleepSpy.isAssertionHeld)
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
