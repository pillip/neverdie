import AppKit
import SwiftUI
import os

/// Manages the NSStatusItem for the Neverdie menu bar app.
///
/// StatusBarController handles:
/// - Click: Show/hide popover with toggle, settings, quit
/// - Animated icon via AnimationManager (ON state)
/// - Static sleeping zombie icon (OFF state)
/// - Error indicator overlay (red dot)
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private let animationManager: AnimationManager
    private let logger = Logger.ui
    private var popover: NSPopover?

    /// Whether frame observation is active (tracks animationManager.currentFrame).
    private var isObservingFrames: Bool = false

    // MARK: - Error Pulse State
    private var errorPulseTimer: Timer?
    private var errorPulseCount: Int = 0

    // MARK: - Clamshell Pause Observation
    /// Tracks the last known paused state to detect transitions.
    private var lastKnownPausedState: Bool = false
    /// Whether state observation is active (can be disabled for testing).
    private var isObservingState: Bool = false

    // MARK: - Init

    init(appState: AppState, animationManager: AnimationManager) {
        self.appState = appState
        self.animationManager = animationManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        setupButton()
        updateIcon()
        performLaunchFadeIn()
        startStateObservation()
        logger.info("StatusBarController initialized")
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp])
        updateAccessibility()
    }

    // MARK: - Click Handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if popover?.isShown == true {
            dismissPopover()
        } else {
            showPopover()
        }
    }

    private func performQuit() {
        logger.info("Quit selected from popover")
        isObservingState = false
        stopFrameObservation()
        animationManager.stopAnimation()
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Popover

    private func showPopover() {
        guard let button = statusItem.button else { return }

        let contentView = ControlPopoverView(
            isActive: appState.isActive,
            isPaused: appState.isPausedDueToClamshell,
            hasError: appState.lastError != nil,
            onToggle: { [weak self] in
                self?.performToggle()
            },
            onQuit: { [weak self] in
                self?.performQuit()
            }
        )
        let hostingController = NSHostingController(rootView: contentView)

        let pop = NSPopover()
        pop.contentViewController = hostingController
        pop.behavior = .transient  // Dismisses when clicking outside
        pop.animates = true

        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = pop

        // Make popover's window key so first click isn't swallowed
        pop.contentViewController?.view.window?.makeKey()

        logger.debug("Popover shown")
    }

    private func dismissPopover() {
        popover?.performClose(nil)
        popover = nil
    }

    /// Perform the ON/OFF toggle with animations.
    func performToggle() {
        let wasActive = appState.isActive
        appState.toggle()

        // Sync tracked state so handleStateChange doesn't re-process this toggle
        lastKnownActiveState = appState.isActive
        lastKnownPausedState = appState.isPausedDueToClamshell

        if appState.isActive && !wasActive {
            animationManager.stopAnimation()
            animationManager.playTransition(type: .wakeUp) { [weak self] in
                self?.animationManager.startAnimation()
            }
            startFrameObservation()
        } else if !appState.isActive && wasActive {
            stopFrameObservation()
            animationManager.playTransition(type: .fallAsleep) { [weak self] in
                self?.animationManager.stopAnimation()
                self?.updateIcon()
            }
        }

        updateIcon()
        updateAccessibility()
        announceStateChange()

        // Update popover content
        dismissPopover()
        showPopover()

        logger.info("Toggle triggered, isActive=\(self.appState.isActive)")
    }

    // MARK: - Frame Observation

    /// Start observing `animationManager.currentFrame` using the Observation framework.
    /// When `currentFrame` changes, `updateAnimatedIcon()` is called reactively.
    private func startFrameObservation() {
        guard !isObservingFrames else { return }
        isObservingFrames = true
        scheduleFrameTracking()
    }

    /// Stop observing frame changes. The next scheduled tracking cycle will
    /// see `isObservingFrames == false` and exit.
    private func stopFrameObservation() {
        isObservingFrames = false
    }

    /// Schedules a single observation tracking cycle for `currentFrame`.
    private func scheduleFrameTracking() {
        guard isObservingFrames else { return }
        withObservationTracking {
            _ = self.animationManager.currentFrame
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.isObservingFrames else { return }
                self.updateAnimatedIcon()
                self.scheduleFrameTracking()
            }
        }
    }

    // MARK: - State Observation (Clamshell Pause)

    /// Start observing AppState for `isPausedDueToClamshell` changes using
    /// `withObservationTracking` (Swift 5.9 Observation framework).
    private func startStateObservation() {
        isObservingState = true
        lastKnownPausedState = appState.isPausedDueToClamshell
        lastKnownActiveState = appState.isActive
        scheduleObservationTracking()
    }

    /// Schedules a single observation tracking cycle. When any observed property
    /// changes, the `onChange` closure fires on the main thread and we re-schedule.
    /// Tracks the last known active state to detect auto-ON/auto-OFF transitions.
    private var lastKnownActiveState: Bool = false

    private func scheduleObservationTracking() {
        guard isObservingState else { return }
        withObservationTracking {
            // Access properties we want to track — the framework records these.
            _ = self.appState.isPausedDueToClamshell
            _ = self.appState.isActive
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.handleStateChange()
            }
        }
    }

    /// Called when observed AppState properties change.
    private func handleStateChange() {
        let wasPaused = lastKnownPausedState
        let isPaused = appState.isPausedDueToClamshell
        let wasActive = lastKnownActiveState
        let isNowActive = appState.isActive

        if isPaused != wasPaused {
            lastKnownPausedState = isPaused
            if isPaused {
                handleEnterPaused()
            } else {
                handleExitPaused()
            }
        }

        // Handle auto-ON/auto-OFF transitions (isActive changed without user toggle)
        if isNowActive != wasActive {
            lastKnownActiveState = isNowActive
            if isNowActive {
                handleAutoActivated()
            } else {
                handleAutoDeactivated()
            }
        }

        // Re-schedule for next change
        scheduleObservationTracking()
    }

    /// Handle auto-ON: start animation, update icon and accessibility.
    private func handleAutoActivated() {
        animationManager.startAnimation()
        startFrameObservation()
        updateIcon()
        updateAccessibility()
        announceStateChange()
        logger.info("StatusBarController: auto-ON triggered")
    }

    /// Handle auto-OFF: stop animation, update icon and accessibility.
    private func handleAutoDeactivated() {
        stopFrameObservation()
        animationManager.stopAnimation()
        updateIcon()
        updateAccessibility()
        announceStateChange()
        logger.info("StatusBarController: auto-OFF triggered")
    }

    /// Handle transition into paused state (isPausedDueToClamshell: false -> true).
    /// Stops animation, shows OFF icon at 50% opacity, fires VoiceOver announcement.
    private func handleEnterPaused() {
        stopFrameObservation()
        animationManager.stopAnimation()

        guard let button = statusItem.button else { return }
        button.image = animationManager.staticOffIcon
        button.alphaValue = 0.5

        updateAccessibility()
        announceStateChange()

        logger.info("StatusBarController: entered paused state (lid closed on battery)")
    }

    /// Handle transition out of paused state (isPausedDueToClamshell: true -> false).
    /// If isActive, resumes animation at full opacity. Fires VoiceOver announcement.
    private func handleExitPaused() {
        guard let button = statusItem.button else { return }

        if appState.isActive {
            animationManager.startAnimation()
            startFrameObservation()
            button.alphaValue = 1.0
        }
        // If not active (user toggled off while paused), don't start animation
        // but restore opacity
        if !appState.isActive {
            button.alphaValue = 1.0
        }

        updateAccessibility()
        announceStateChange()

        logger.info("StatusBarController: exited paused state")
    }

    private func updateAnimatedIcon() {
        guard let button = statusItem.button else { return }
        let frame = animationManager.currentFrame
        if appState.lastError != nil {
            button.image = iconWithErrorDot(frame)
        } else {
            button.image = frame
        }
    }

    // MARK: - Icon Management

    func updateIcon() {
        guard let button = statusItem.button else { return }

        // Handle paused state: show OFF icon at 50% opacity
        if appState.isPausedDueToClamshell {
            stopErrorPulseAnimation()
            button.image = animationManager.staticOffIcon
            button.alphaValue = 0.5
            return
        }

        if animationManager.isAnimating || animationManager.isPlayingTransition {
            let frame = animationManager.currentFrame
            if appState.lastError != nil {
                button.image = iconWithErrorDot(frame)
            } else {
                button.image = frame
            }
            return
        }

        let baseIcon: NSImage
        if appState.isActive {
            baseIcon = animationManager.currentFrame
        } else {
            baseIcon = animationManager.staticOffIcon
        }

        if appState.lastError != nil {
            button.image = iconWithErrorDot(baseIcon)
            startErrorPulseAnimation()
        } else {
            stopErrorPulseAnimation()
            button.image = baseIcon
        }
    }

    // MARK: - Launch Fade-In

    private func performLaunchFadeIn() {
        guard let button = statusItem.button else { return }
        button.alphaValue = 0.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.animator().alphaValue = 1.0
        }
    }

    // MARK: - Error Indicator

    private func iconWithErrorDot(_ baseIcon: NSImage) -> NSImage {
        let size = baseIcon.size
        let composited = NSImage(size: size)
        composited.lockFocus()
        baseIcon.draw(in: NSRect(origin: .zero, size: size))
        let dotSize: CGFloat = 4.0
        let dotRect = NSRect(x: size.width - dotSize - 1, y: 1, width: dotSize, height: dotSize)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
        composited.unlockFocus()
        return composited
    }

    private func startErrorPulseAnimation() {
        guard errorPulseTimer == nil else { return }
        errorPulseCount = 0
        errorPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.errorPulseCount += 1
            guard let button = self.statusItem.button else { return }
            if self.errorPulseCount <= 4 {
                button.alphaValue = self.errorPulseCount % 2 == 0 ? 1.0 : 0.7
            } else {
                button.alphaValue = 1.0
                timer.invalidate()
                self.errorPulseTimer = nil
            }
        }
    }

    private func stopErrorPulseAnimation() {
        errorPulseTimer?.invalidate()
        errorPulseTimer = nil
        errorPulseCount = 0
        statusItem.button?.alphaValue = 1.0
    }

    // MARK: - Accessibility

    private func updateAccessibility() {
        guard let button = statusItem.button else { return }
        if appState.lastError != nil {
            button.setAccessibilityLabel(NSLocalizedString("status.error", comment: "Accessibility label when error"))
        } else if appState.isPausedDueToClamshell {
            button.setAccessibilityLabel(NSLocalizedString("status.paused", comment: "Accessibility label when paused due to clamshell"))
        } else if appState.isActive {
            button.setAccessibilityLabel(NSLocalizedString("status.sleep_prevention_on", comment: "Accessibility label when ON"))
        } else {
            button.setAccessibilityLabel(NSLocalizedString("status.sleep_prevention_off", comment: "Accessibility label when OFF"))
        }
        button.setAccessibilityRole(.button)
    }

    private func announceStateChange() {
        let announcement: String
        if appState.lastError != nil {
            announcement = NSLocalizedString("announce.error", comment: "VoiceOver error announcement")
        } else if appState.isPausedDueToClamshell {
            announcement = NSLocalizedString("announce.paused", comment: "VoiceOver paused announcement")
        } else if appState.isActive {
            announcement = NSLocalizedString("announce.on", comment: "VoiceOver ON announcement")
        } else {
            announcement = NSLocalizedString("announce.off", comment: "VoiceOver OFF announcement")
        }

        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            NSAccessibility.NotificationUserInfoKey(rawValue: NSAccessibility.NotificationUserInfoKey.announcement.rawValue): announcement,
            NSAccessibility.NotificationUserInfoKey(rawValue: NSAccessibility.NotificationUserInfoKey.priority.rawValue): NSAccessibilityPriorityLevel.high.rawValue
        ]
        NSAccessibility.post(element: statusItem.button as Any, notification: .announcementRequested, userInfo: userInfo)
    }

    var item: NSStatusItem { statusItem }

    // MARK: - Test Helpers

    /// Exposes the current button alpha value for testing.
    var buttonAlphaValue: CGFloat {
        statusItem.button?.alphaValue ?? 1.0
    }

    /// Exposes whether frame observation is active for testing.
    var isFrameObserverActive: Bool {
        isObservingFrames
    }

    /// Synchronously process a paused state change for testing.
    /// This bypasses the async observation tracking.
    func _testHandleStateChange() {
        handleStateChange()
    }
}
