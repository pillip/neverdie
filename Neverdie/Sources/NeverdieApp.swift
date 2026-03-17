import SwiftUI
import os

/// Main entry point for the Neverdie menu bar app.
///
/// Neverdie prevents macOS system sleep while Claude Code is running.
/// It lives in the menu bar only (no Dock icon via LSUIElement=true).
///
/// The menu bar icon shows a sleeping zombie when OFF.
/// Falls back to "ND" text if the zombie asset is missing.
@main
struct NeverdieApp: App {
    var body: some Scene {
        MenuBarExtra {
            Text("Neverdie")
                .padding()
        } label: {
            MenuBarIconView()
        }
    }
}

/// View that displays the appropriate menu bar icon.
///
/// Shows the sleeping zombie icon from the asset catalog,
/// with fallback to "ND" text if the asset is not available.
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
