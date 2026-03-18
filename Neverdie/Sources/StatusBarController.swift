import AppKit
import SwiftUI
import os

/// Manages the NSStatusItem for the Neverdie menu bar app.
///
/// StatusBarController handles:
/// - Left-click: Toggle Neverdie mode via AppState
/// - Animated icon via AnimationManager (ON state)
/// - Static sleeping zombie icon (OFF state)
/// - Transition animations (wake-up, fall-asleep, auto-OFF)
/// - Error indicator overlay (red dot) when errors occur
/// - VoiceOver announcements on state changes and errors
/// - App launch fade-in (200ms)
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private let animationManager: AnimationManager
    private let logger = Logger.ui
    private var popoverManager: PopoverManager?

    /// Timer to observe AnimationManager.currentFrame changes.
    private var frameObserverTimer: Timer?

    // MARK: - Error Pulse State

    /// Timer for error pulse animation.
    private var errorPulseTimer: Timer?

    /// Current pulse count (2 pulses then solid).
    private var errorPulseCount: Int = 0

    // MARK: - Init

    /// Create a StatusBarController.
    /// - Parameters:
    ///   - appState: The shared AppState instance.
    ///   - animationManager: The AnimationManager for icon frame cycling.
    init(appState: AppState, animationManager: AnimationManager) {
        self.appState = appState
        self.animationManager = animationManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        setupButton()
        updateIcon()
        setupPopover()
        performLaunchFadeIn()
        logger.info("StatusBarController initialized with AnimationManager")
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Accessibility
        updateAccessibility()
    }

    private func setupPopover() {
        guard let button = statusItem.button else { return }
        popoverManager = PopoverManager(appState: appState, statusButton: button)
    }

    /// Build the right-click context menu.
    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Status line (disabled, informational)
        let statusText: String
        if appState.lastError != nil {
            statusText = NSLocalizedString("menu.status_error", comment: "Menu status when error")
        } else if appState.isActive {
            statusText = NSLocalizedString("menu.status_on", comment: "Menu status when ON")
        } else {
            statusText = NSLocalizedString("menu.status_off", comment: "Menu status when OFF")
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(title: NSLocalizedString("menu.quit", comment: "Quit menu item"), action: #selector(handleQuit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Click Handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        // Dismiss popover on any click
        popoverManager?.dismissPopover()

        if event?.type == .rightMouseUp {
            // Right-click: show context menu
            let menu = buildMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Clear the menu so left-click works again
            statusItem.menu = nil
            logger.debug("Right-click menu shown")
        } else {
            // Left-click: toggle with transition animations
            let wasActive = appState.isActive
            appState.toggle()

            if appState.isActive && !wasActive {
                // OFF -> ON: play wake-up transition then start loop
                animationManager.stopAnimation()
                animationManager.playTransition(type: .wakeUp) { [weak self] in
                    self?.animationManager.startAnimation()
                }
                startFrameObserver()
            } else if !appState.isActive && wasActive {
                // ON -> OFF: play fall-asleep transition
                stopFrameObserver()
                animationManager.playTransition(type: .fallAsleep) { [weak self] in
                    self?.animationManager.stopAnimation()
                    self?.updateIcon()
                }
            }

            updateIcon()
            updateAccessibility()
            announceStateChange()
            logger.info("Toggle triggered via left-click, isActive=\(self.appState.isActive)")
        }
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        logger.info("Quit selected from menu")
        stopFrameObserver()
        animationManager.stopAnimation()
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Frame Observer

    /// Start observing AnimationManager.currentFrame changes to update the icon.
    private func startFrameObserver() {
        stopFrameObserver()
        // Poll currentFrame at the animation fps rate
        frameObserverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / animationManager.fps, repeats: true) { [weak self] _ in
            self?.updateAnimatedIcon()
        }
        frameObserverTimer?.tolerance = 0.05
    }

    /// Stop observing frame changes.
    private func stopFrameObserver() {
        frameObserverTimer?.invalidate()
        frameObserverTimer = nil
    }

    /// Update the icon from AnimationManager's current frame.
    private func updateAnimatedIcon() {
        guard let button = statusItem.button else { return }
        let frame = animationManager.currentFrame
        if appState.lastError != nil {
            button.image = iconWithErrorDot(frame)
        } else {
            button.image = frame
        }
    }

    // MARK: - Auto-OFF Animation

    /// Called when auto-OFF triggers to play the auto-OFF transition.
    func playAutoOffTransition() {
        stopFrameObserver()
        animationManager.playTransition(type: .autoOff) { [weak self] in
            self?.animationManager.stopAnimation()
            self?.updateIcon()
        }
    }

    // MARK: - Icon Management

    /// Update the menu bar icon based on current state.
    func updateIcon() {
        guard let button = statusItem.button else { return }

        if animationManager.isAnimating || animationManager.isPlayingTransition {
            // Animation is running -- frame observer handles updates
            let frame = animationManager.currentFrame
            if appState.lastError != nil {
                button.image = iconWithErrorDot(frame)
            } else {
                button.image = frame
            }
            return
        }

        // Static icon
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

    /// Perform a 200ms fade-in on app launch.
    private func performLaunchFadeIn() {
        guard let button = statusItem.button else { return }
        button.alphaValue = 0.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            button.animator().alphaValue = 1.0
        }

        logger.debug("Launch fade-in started (200ms)")
    }

    // MARK: - Error Indicator

    /// Composites a 2x2pt red dot onto the bottom-right of an icon image.
    private func iconWithErrorDot(_ baseIcon: NSImage) -> NSImage {
        let size = baseIcon.size
        let composited = NSImage(size: size)
        composited.lockFocus()

        baseIcon.draw(in: NSRect(origin: .zero, size: size))

        let dotSize: CGFloat = 4.0
        let dotRect = NSRect(
            x: size.width - dotSize - 1,
            y: 1,
            width: dotSize,
            height: dotSize
        )
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        composited.unlockFocus()
        return composited
    }

    /// Start the error pulse animation (2 pulses then solid).
    private func startErrorPulseAnimation() {
        guard errorPulseTimer == nil else { return }
        errorPulseCount = 0

        errorPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.errorPulseCount += 1

            guard let button = self.statusItem.button else { return }

            if self.errorPulseCount <= 4 {
                let isVisible = self.errorPulseCount % 2 == 0
                button.alphaValue = isVisible ? 1.0 : 0.7
            } else {
                button.alphaValue = 1.0
                timer.invalidate()
                self.errorPulseTimer = nil
            }
        }
    }

    /// Stop the error pulse animation.
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
        } else if appState.isActive {
            button.setAccessibilityLabel(NSLocalizedString("status.sleep_prevention_on", comment: "Accessibility label when ON"))
        } else {
            button.setAccessibilityLabel(NSLocalizedString("status.sleep_prevention_off", comment: "Accessibility label when OFF"))
        }

        // Ensure keyboard activation (Space/Enter) triggers the button action
        button.setAccessibilityRole(.button)
    }

    /// Post a VoiceOver announcement when state changes.
    private func announceStateChange() {
        let announcement: String
        if appState.lastError != nil {
            announcement = NSLocalizedString("announce.error", comment: "VoiceOver error announcement")
        } else if appState.isActive {
            announcement = NSLocalizedString("announce.on", comment: "VoiceOver ON announcement")
        } else {
            announcement = NSLocalizedString("announce.off", comment: "VoiceOver OFF announcement")
        }

        let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
            NSAccessibility.NotificationUserInfoKey(rawValue: NSAccessibility.NotificationUserInfoKey.announcement.rawValue): announcement,
            NSAccessibility.NotificationUserInfoKey(rawValue: NSAccessibility.NotificationUserInfoKey.priority.rawValue): NSAccessibilityPriorityLevel.high.rawValue
        ]
        NSAccessibility.post(
            element: statusItem.button as Any,
            notification: .announcementRequested,
            userInfo: userInfo
        )
    }

    // MARK: - Public API

    /// Get the NSStatusItem for menu wiring.
    var item: NSStatusItem { statusItem }
}
