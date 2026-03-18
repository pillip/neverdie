import SwiftUI
import AppKit
import os

/// Application delegate for handling lifecycle events.
///
/// Creates and owns the AppState, SleepManager, and StatusBarController.
/// Manages the NSStatusItem directly for left-click toggle support.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var sleepManager: SleepManager!
    private var animationManager: AnimationManager!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon but remain visible in Spotlight (unlike LSUIElement)
        NSApp.setActivationPolicy(.accessory)
        // Single-instance guard: quit if another instance is already running
        let runningInstances = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.neverdie.app"
        )
        if runningInstances.count > 1 {
            Logger.lifecycle.warning("Another instance of Neverdie is already running -- quitting")
            NSApplication.shared.terminate(nil)
            return
        }

        sleepManager = SleepManager()
        animationManager = AnimationManager()
        appState = AppState(sleepManager: sleepManager)
        statusBarController = StatusBarController(appState: appState, animationManager: animationManager)

        // Register signal handlers for clean shutdown on SIGTERM/SIGINT
        SignalHandler.register { [weak self] in
            self?.appState?.cleanup()
        }

        Logger.lifecycle.info("Neverdie app launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        SignalHandler.unregister()
        appState?.cleanup()
        Logger.lifecycle.info("Neverdie app terminating")
    }
}

/// Main entry point for the Neverdie menu bar app.
///
/// Neverdie prevents macOS system sleep while Claude Code is running.
/// It lives in the menu bar only (no Dock icon via .accessory activation policy).
///
/// Uses NSApplicationDelegateAdaptor to wire AppDelegate for lifecycle
/// management and NSStatusItem-based menu bar control.
@main
struct NeverdieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Use Settings scene as a no-op since we manage the menu bar via NSStatusItem
        Settings {
            EmptyView()
        }
    }
}

/// View that displays the appropriate menu bar icon.
///
/// Shows the sleeping zombie icon from the asset catalog,
/// with fallback to "ND" text if the asset is not available.
/// Kept for potential reuse in SwiftUI contexts.
struct MenuBarIconView: View {
    var body: some View {
        if let zombieImage = NSImage(named: "ZombieSleep") {
            let _ = zombieImage.isTemplate = true
            Image(nsImage: zombieImage)
                .accessibilityLabel("Neverdie -- sleep prevention OFF")
        } else {
            // Fallback: text "ND" when zombie asset is missing
            Text("ND")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .accessibilityLabel("Neverdie -- sleep prevention OFF")
        }
    }
}
