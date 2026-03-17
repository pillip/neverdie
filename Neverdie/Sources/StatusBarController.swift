import AppKit
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
        logger.info("StatusBarController initialized")
    }

    // MARK: - Setup

    private func setupButton() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp])

        // Accessibility
        updateAccessibility()
    }

    // MARK: - Click Handling

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        appState.toggle()
        updateIcon()
        updateAccessibility()
        announceStateChange()
        logger.info("Toggle triggered via left-click, isActive=\(self.appState.isActive)")
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
