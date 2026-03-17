import os

/// Centralized loggers for the Neverdie app.
///
/// Each subsystem category corresponds to a distinct module:
/// - `sleep`: IOPMAssertion lifecycle events
/// - `process`: Claude Code process detection and polling
/// - `token`: Token usage file parsing
/// - `ui`: UI state changes, icon updates, popover events
/// - `lifecycle`: App launch, termination, cleanup
extension Logger {
    private static let subsystem = "com.neverdie.app"

    /// Sleep prevention (IOPMAssertion) events
    static let sleep = Logger(subsystem: subsystem, category: "sleep")

    /// Process monitoring events
    static let process = Logger(subsystem: subsystem, category: "process")

    /// Token usage parsing events
    static let token = Logger(subsystem: subsystem, category: "token")

    /// UI state and rendering events
    static let ui = Logger(subsystem: subsystem, category: "ui")

    /// App lifecycle events (launch, terminate, cleanup)
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
