import AppKit
import ServiceManagement
import SwiftUI
import os

/// Manages the NSStatusItem for the Neverdie menu bar app.
///
/// StatusBarController handles:
/// - Left-click: Toggle Neverdie mode via AppState
/// - Icon switching between OFF (zombie sleep) and ON (bolt.fill placeholder)
/// - VoiceOver announcements on state changes
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
        let state = appState.isActive ? "ON" : "OFF"
        let statusItem = NSMenuItem(title: "Neverdie: \(state)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        let loginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(handleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

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

    @objc private func handleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if isLaunchAtLoginEnabled {
                try service.unregister()
                logger.info("Launch at Login disabled")
            } else {
                try service.register()
                logger.info("Launch at Login enabled")
            }
        } catch {
            logger.error("Launch at Login toggle failed: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Could not enable Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - Launch at Login

    /// Query current SMAppService registration status.
    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // MARK: - Icon Management

    /// Update the menu bar icon based on current state.
    func updateIcon() {
        guard let button = statusItem.button else { return }

        if appState.isActive {
            if let icon = onIcon {
                button.image = icon
            } else {
                button.image = nil
                button.title = "ND"
            }
        } else {
            if let icon = offIcon {
                button.image = icon
            } else {
                button.image = nil
                button.title = "ND"
            }
        }
    }

    // MARK: - Accessibility

    private func updateAccessibility() {
        guard let button = statusItem.button else { return }
        let state = appState.isActive ? "ON" : "OFF"
        button.setAccessibilityLabel("Neverdie -- sleep prevention \(state)")
    }

    /// Post a VoiceOver announcement when state changes.
    private func announceStateChange() {
        let state = appState.isActive ? "ON" : "OFF"
        let announcement = "Neverdie \(state)"

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
