import AppKit
import SwiftUI
import os

/// Manages the hover popover for the menu bar icon.
///
/// PopoverManager installs an NSTrackingArea on the status bar button
/// to detect mouse enter/exit events. On hover (200ms delay), it shows
/// an NSPopover with process count. On mouse exit (100ms grace period),
/// it dismisses the popover.
final class PopoverManager: NSObject {
    private let logger = Logger.ui
    private weak var appState: AppState?
    private var popover: NSPopover?
    private var trackingArea: NSTrackingArea?
    private weak var statusButton: NSStatusBarButton?

    /// Timer for hover delay (200ms before showing).
    private var hoverTimer: DispatchWorkItem?

    /// Timer for dismiss grace period (100ms before hiding).
    private var dismissTimer: DispatchWorkItem?

    /// Hover delay before showing popover (seconds).
    let hoverDelay: TimeInterval = 0.2

    /// Grace period before dismissing popover (seconds).
    let dismissGrace: TimeInterval = 0.1

    /// Create a PopoverManager.
    /// - Parameters:
    ///   - appState: The shared AppState for process count data.
    ///   - statusButton: The NSStatusBarButton to track.
    init(appState: AppState, statusButton: NSStatusBarButton) {
        self.appState = appState
        self.statusButton = statusButton
        super.init()
        setupTrackingArea()
        logger.info("PopoverManager initialized")
    }

    deinit {
        removeTrackingArea()
        dismissPopover()
    }

    // MARK: - Tracking Area

    private func setupTrackingArea() {
        guard let button = statusButton else { return }

        let area = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(area)
        trackingArea = area
        logger.debug("Tracking area installed on status button")
    }

    private func removeTrackingArea() {
        if let area = trackingArea, let button = statusButton {
            button.removeTrackingArea(area)
        }
        trackingArea = nil
    }

    // MARK: - Mouse Events

    @objc func mouseEntered(with event: NSEvent) {
        // Cancel any pending dismiss
        dismissTimer?.cancel()
        dismissTimer = nil

        // Start hover delay
        let work = DispatchWorkItem { [weak self] in
            self?.showPopover()
        }
        hoverTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: work)
    }

    @objc func mouseExited(with event: NSEvent) {
        // Cancel any pending show
        hoverTimer?.cancel()
        hoverTimer = nil

        // Start dismiss grace period
        let work = DispatchWorkItem { [weak self] in
            self?.dismissPopover()
        }
        dismissTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissGrace, execute: work)
    }

    // MARK: - Popover

    private func showPopover() {
        guard let button = statusButton else { return }
        guard popover == nil || popover?.isShown == false else { return }

        // Refresh token data when popover opens
        appState?.refreshTokenUsage()

        let processCount = appState?.processCount ?? 0
        let tokenUsage = appState?.tokenUsage

        let contentView = PopoverView(processCount: processCount, tokenUsage: tokenUsage)
        let hostingController = NSHostingController(rootView: contentView)

        let pop = NSPopover()
        pop.contentViewController = hostingController
        pop.behavior = .transient
        pop.animates = true

        pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = pop

        logger.debug("Popover shown with \(processCount) processes")
    }

    func dismissPopover() {
        popover?.performClose(nil)
        popover = nil
    }
}
