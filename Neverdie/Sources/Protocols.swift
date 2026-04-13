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

/// Power source state.
enum PowerSource: Equatable, Sendable {
    case ac
    case battery
}

/// Protocol for observing MacBook lid open/close state.
protocol ClamshellObserving: AnyObject {
    var isLidClosed: Bool { get }
    func start(onChange: @escaping (Bool) -> Void)
    func stop()
}

/// Protocol for observing AC vs battery power transitions.
protocol PowerSourceMonitoring: AnyObject {
    var currentSource: PowerSource { get }
    func start(onChange: @escaping (PowerSource) -> Void)
    func stop()
}
