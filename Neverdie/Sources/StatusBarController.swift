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

    /// Timer to observe AnimationManager.currentFrame changes.
    private var frameObserverTimer: Timer?

    // MARK: - Error Pulse State
    private var errorPulseTimer: Timer?
    private var errorPulseCount: Int = 0

    // MARK: - Init

    init(appState: AppState, animationManager: AnimationManager) {
        self.appState = appState
        self.animationManager = animationManager
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        setupButton()
        updateIcon()
        performLaunchFadeIn()
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
        stopFrameObserver()
        animationManager.stopAnimation()
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Popover

    private func showPopover() {
        guard let button = statusItem.button else { return }

        let contentView = ControlPopoverView(
            isActive: appState.isActive,
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

        if appState.isActive && !wasActive {
            animationManager.stopAnimation()
            animationManager.playTransition(type: .wakeUp) { [weak self] in
                self?.animationManager.startAnimation()
            }
            startFrameObserver()
        } else if !appState.isActive && wasActive {
            stopFrameObserver()
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

    // MARK: - Frame Observer

    private func startFrameObserver() {
        stopFrameObserver()
        frameObserverTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / animationManager.fps, repeats: true) { [weak self] _ in
            self?.updateAnimatedIcon()
        }
        frameObserverTimer?.tolerance = 0.05
    }

    private func stopFrameObserver() {
        frameObserverTimer?.invalidate()
        frameObserverTimer = nil
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
}
