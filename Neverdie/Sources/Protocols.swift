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
