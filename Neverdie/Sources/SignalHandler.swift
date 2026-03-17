import Foundation
import os

/// Registers SIGTERM and SIGINT signal handlers for clean shutdown.
///
/// When a termination signal is received, the handler calls the provided
/// cleanup closure (which should release IOPMAssertions) before exiting.
///
/// ## Usage
/// ```swift
/// SignalHandler.register { appState.cleanup() }
/// ```
///
/// Note: Uses `DispatchSource.makeSignalSource` after ignoring the default
/// signal behavior with `signal(SIG, SIG_IGN)`.
final class SignalHandler {
    private static var sigTermSource: DispatchSourceSignal?
    private static var sigIntSource: DispatchSourceSignal?
    private static let logger = Logger.lifecycle

    /// Register SIGTERM and SIGINT handlers.
    ///
    /// - Parameter cleanup: Closure to call before exiting. Should release
    ///   any held IOPMAssertions and stop monitors. Must be synchronous.
    static func register(cleanup: @escaping () -> Void) {
        // Ignore default signal behavior so DispatchSource can handle them
        signal(SIGTERM, SIG_IGN)
        signal(SIGINT, SIG_IGN)

        // SIGTERM handler
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler {
            logger.info("SIGTERM received, performing cleanup")
            cleanup()
            logger.info("Cleanup complete, exiting")
            exit(0)
        }
        termSource.resume()
        sigTermSource = termSource

        // SIGINT handler
        let intSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        intSource.setEventHandler {
            logger.info("SIGINT received, performing cleanup")
            cleanup()
            logger.info("Cleanup complete, exiting")
            exit(0)
        }
        intSource.resume()
        sigIntSource = intSource

        logger.info("Signal handlers registered (SIGTERM, SIGINT)")
    }

    /// Unregister signal handlers.
    ///
    /// Cancels the dispatch sources. Safe to call multiple times.
    static func unregister() {
        sigTermSource?.cancel()
        sigTermSource = nil
        sigIntSource?.cancel()
        sigIntSource = nil
        logger.debug("Signal handlers unregistered")
    }
}
