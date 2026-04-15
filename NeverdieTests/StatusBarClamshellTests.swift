import XCTest
@testable import Neverdie

/// Tests for StatusBarController reactive updates when isPausedDueToClamshell changes.
/// Verifies ISSUE-025: icon opacity dimming, animation stop/resume, and accessibility.
final class StatusBarClamshellTests: XCTestCase {

    private var sleepSpy: SleepManagingSpy!
    private var clamshell: FakeClamshellObserver!
    private var power: FakePowerSourceMonitor!
    private var appState: AppState!
    private var animationManager: AnimationManager!
    private var sut: StatusBarController!

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
        animationManager = AnimationManager()
        sut = StatusBarController(appState: appState, animationManager: animationManager)
    }

    override func tearDown() {
        appState.cleanup()
        sut = nil
        animationManager = nil
        super.tearDown()
    }

    // MARK: - AC 1: isPausedDueToClamshell false->true triggers icon stop + opacity 0.5

    func testEnterPaused_stopsAnimationAndDimsOpacity() {
        // Activate on battery
        power.simulateTransition(.battery)
        sut.performToggle()
        XCTAssertTrue(appState.isActive)

        // Close lid -> paused
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        // Synchronously process the state change
        sut._testHandleStateChange()

        XCTAssertFalse(animationManager.isAnimating, "Animation should stop when paused")
        XCTAssertEqual(sut.buttonAlphaValue, 0.5, accuracy: 0.01,
                       "Button alpha should be 0.5 when paused")
        XCTAssertFalse(sut.isFrameObserverActive, "Frame observer should be stopped when paused")
    }

    // MARK: - AC 2: isPausedDueToClamshell true->false with isActive==true resumes animation

    func testExitPaused_withActiveTrue_resumesAnimation() {
        // Activate, go to paused
        power.simulateTransition(.battery)
        sut.performToggle()
        clamshell.simulateClose()
        sut._testHandleStateChange()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        // Open lid -> resume
        clamshell.simulateOpen()
        XCTAssertFalse(appState.isPausedDueToClamshell)
        sut._testHandleStateChange()

        XCTAssertTrue(animationManager.isAnimating, "Animation should resume when unpaused")
        XCTAssertEqual(sut.buttonAlphaValue, 1.0, accuracy: 0.01,
                       "Button alpha should be 1.0 when resumed")
        XCTAssertTrue(sut.isFrameObserverActive, "Frame observer should be active when resumed")
    }

    // MARK: - AC 3: isPausedDueToClamshell true->false with isActive==false does not start animation

    func testExitPaused_withActiveFalse_doesNotStartAnimation() {
        // Activate, go to paused
        power.simulateTransition(.battery)
        sut.performToggle()
        clamshell.simulateClose()
        sut._testHandleStateChange()

        // Toggle off while paused
        appState.toggle()
        XCTAssertFalse(appState.isActive)
        XCTAssertFalse(appState.isPausedDueToClamshell) // cleared by toggle off

        sut._testHandleStateChange()

        XCTAssertFalse(animationManager.isAnimating, "Animation should not start when inactive")
        XCTAssertEqual(sut.buttonAlphaValue, 1.0, accuracy: 0.01,
                       "Button alpha should be restored to 1.0")
    }

    // MARK: - ISSUE-029: Observation-based frame updates (no polling timer)

    func testToggleOn_startsFrameObservation() {
        XCTAssertFalse(sut.isFrameObserverActive, "Frame observation should be inactive when OFF")

        sut.performToggle()
        XCTAssertTrue(appState.isActive)

        XCTAssertTrue(sut.isFrameObserverActive,
                      "Frame observation should be active after toggle ON")
    }

    func testToggleOff_stopsFrameObservation() {
        sut.performToggle() // ON
        XCTAssertTrue(sut.isFrameObserverActive)

        sut.performToggle() // OFF
        XCTAssertFalse(appState.isActive)

        XCTAssertFalse(sut.isFrameObserverActive,
                       "Frame observation should be inactive after toggle OFF")
    }

    func testAutoActivated_startsFrameObservation() {
        // Simulate auto-ON via state change
        appState.handleProcessUpdate(1)
        XCTAssertTrue(appState.isActive)

        sut._testHandleStateChange()

        XCTAssertTrue(sut.isFrameObserverActive,
                      "Frame observation should start on auto-activation")
    }

    func testAutoDeactivated_stopsFrameObservation() {
        // Auto-ON then auto-OFF
        appState.handleProcessUpdate(1)
        sut._testHandleStateChange()
        XCTAssertTrue(sut.isFrameObserverActive)

        appState.handleProcessUpdate(0)
        sut._testHandleStateChange()

        XCTAssertFalse(sut.isFrameObserverActive,
                       "Frame observation should stop on auto-deactivation")
    }

    // MARK: - updateIcon reflects paused state

    func testUpdateIcon_whenPaused_showsOffIconDimmed() {
        power.simulateTransition(.battery)
        sut.performToggle()
        clamshell.simulateClose()
        XCTAssertTrue(appState.isPausedDueToClamshell)

        sut.updateIcon()

        XCTAssertEqual(sut.buttonAlphaValue, 0.5, accuracy: 0.01,
                       "updateIcon should set alpha to 0.5 when paused")
    }
}
