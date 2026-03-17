import SwiftUI
import os

/// Main entry point for the Neverdie menu bar app.
///
/// Neverdie prevents macOS system sleep while Claude Code is running.
/// It lives in the menu bar only (no Dock icon via LSUIElement=true).
@main
struct NeverdieApp: App {
    var body: some Scene {
        MenuBarExtra("Neverdie", systemImage: "bolt.fill") {
            Text("Neverdie")
                .padding()
        }
    }
}
