import AppKit
import SwiftUI
import os

/// Manages the NSStatusItem for the Neverdie menu bar app.
///
/// StatusBarController handles:
/// - Left-click: Toggle Neverdie mode via AppState
/// - Icon switching between OFF (zombie sleep) and ON (bolt.fill placeholder)
/// - Error indicator overlay (red dot) when errors occur
/// - VoiceOver announcements on state changes and errors
/// - AppKit-level NSStatusItem management
final class StatusBarController {
    private var statusItem: NSStatusItem
    private let appState: AppState
    private let logger = Logger.ui
    private var popoverManager: PopoverManager?

    // MARK: - Icon Images

    /// Static sleeping zombie icon for OFF state.
    private lazy var offIcon: NSImage? = {
        guard let img = NSImage(named: "ZombieSleep") else {
            logger.warning("ZombieSleep asset not found, will use fallback")
            return nil
        }
        img.isTemplate = true
        img.size = NSSize(width: 18, height: 18)
        return img
    }()

    /// Placeholder ON icon (SF Symbol bolt.fill until animation is wired).
    private lazy var onIcon: NSImage? = {
        let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Neverdie active")
        img?.isTemplate = true
        img?.size = NSSize(width: 18, height: 18)
        return img
    }()

    // MARK: - Error Pulse State

    /// Timer for error pulse animation.
    private var errorPulseTimer: Timer?

    /// Current pulse count (2 pulses then solid).
    private var errorPulseCount: Int = 0

    // MARK: - Init

    /// Create a StatusBarController.
    /// - Parameter appState: The shared AppState instance.
    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        setupButton()
        updateIcon()
        setupPopover()
        logger.info("StatusBarController initialized")
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
            statusText = "Neverdie: Error -- could not prevent sleep"
        } else {
            let state = appState.isActive ? "ON" : "OFF"
            statusText = "Neverdie: \(state)"
        }
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(title: "Quit Neverdie", action: #selector(handleQuit(_:)), keyEquivalent: "q")
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
            // Left-click: toggle
            appState.toggle()
            updateIcon()
            updateAccessibility()
            announceStateChange()
            logger.info("Toggle triggered via left-click, isActive=\(self.appState.isActive)")
        }
    }

    @objc private func handleQuit(_ sender: NSMenuItem) {
        logger.info("Quit selected from menu")
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Icon Management

    /// Update the menu bar icon based on current state.
    func updateIcon() {
        guard let button = statusItem.button else { return }

        let baseIcon: NSImage?
        if appState.isActive {
            baseIcon = onIcon
        } else {
            baseIcon = offIcon
        }

        if let icon = baseIcon {
            if appState.lastError != nil {
                button.image = iconWithErrorDot(icon)
                startErrorPulseAnimation()
            } else {
                stopErrorPulseAnimation()
                button.image = icon
            }
        } else {
            button.image = nil
            button.title = "ND"
        }
    }

    // MARK: - Error Indicator

    /// Composites a 2x2pt red dot onto the bottom-right of an icon image.
    /// - Parameter baseIcon: The base icon to overlay on.
    /// - Returns: A new NSImage with the red dot overlay.
    private func iconWithErrorDot(_ baseIcon: NSImage) -> NSImage {
        let size = baseIcon.size
        let composited = NSImage(size: size)
        composited.lockFocus()

        // Draw base icon
        baseIcon.draw(in: NSRect(origin: .zero, size: size))

        // Draw red dot (2x2pt) at bottom-right corner
        let dotSize: CGFloat = 4.0  // 4pt for visibility at @2x
        let dotRect = NSRect(
            x: size.width - dotSize - 1,
            y: 1,
            width: dotSize,
            height: dotSize
        )
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        composited.unlockFocus()
        // Do not set isTemplate=true so the red dot color is preserved
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
                // Toggle opacity for pulse effect (2 full pulses = 4 toggles)
                let isVisible = self.errorPulseCount % 2 == 0
                button.alphaValue = isVisible ? 1.0 : 0.7
            } else {
                // After 2 pulses, remain solid
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
            button.setAccessibilityLabel("Neverdie error")
        } else {
            let state = appState.isActive ? "ON" : "OFF"
            button.setAccessibilityLabel("Neverdie -- sleep prevention \(state)")
        }
    }

    /// Post a VoiceOver announcement when state changes.
    private func announceStateChange() {
        let announcement: String
        if appState.lastError != nil {
            announcement = "Neverdie error: could not prevent sleep"
        } else {
            let state = appState.isActive ? "ON" : "OFF"
            announcement = "Neverdie \(state)"
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
