import Foundation

/// Protocol for sleep prevention management (IOPMAssertion).
/// Enables dependency injection and testability.
protocol SleepManaging: AnyObject {
    /// Attempt to create a system sleep prevention assertion.
    /// - Returns: `true` if the assertion was successfully created.
    func preventSleep() -> Bool

    /// Release the sleep prevention assertion. No-op if none is held.
    func allowSleep()

    /// Whether a sleep prevention assertion is currently held.
    var isAssertionHeld: Bool { get }
}

/// Protocol for Claude Code process monitoring.
/// Enables dependency injection and testability.
protocol ProcessMonitoring: AnyObject {
    /// Begin polling for Claude Code processes at a regular interval.
    /// - Parameter onUpdate: Called with the current process count on each poll.
    func startPolling(onUpdate: @escaping (Int) -> Void)

    /// Stop polling. No further callbacks will fire.
    func stopPolling()

    /// Perform a single poll and return the current Claude Code process count.
    func pollOnce() -> Int
}

/// Protocol for token usage monitoring.
/// Enables dependency injection and testability.
protocol TokenMonitoring: AnyObject {
    /// Read aggregate token usage from local Claude Code files.
    /// - Returns: A `TokenUsage` value, or `nil` if data is unavailable.
    func readUsage() -> TokenUsage?

    /// Read per-session token usage data.
    /// - Returns: An array of per-session usage, or empty if unavailable.
    func readPerSessionUsage() -> [SessionTokenUsage]
}

/// Aggregate token usage across all Claude Code sessions.
struct TokenUsage: Equatable, Sendable {
    let context: Int
    let input: Int
    let output: Int
}

/// Per-session token usage with identifying label.
struct SessionTokenUsage: Equatable, Sendable, Identifiable {
    let id: String
    let label: String
    let usage: TokenUsage
}
