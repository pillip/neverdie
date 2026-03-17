import Darwin
import Foundation
import os

/// Monitors the system process table for running Claude Code processes.
///
/// ProcessMonitor uses libproc APIs (`proc_listallpids`, `proc_name`) to
/// enumerate running processes and count those matching Claude Code process
/// names. It supports both one-shot polling via `pollOnce()` and continuous
/// polling via `startPolling(onUpdate:)` at a configurable interval.
final class ProcessMonitor: ProcessMonitoring {
    private let logger = Logger.process
    private var timer: Timer?
    private var onUpdateCallback: ((Int) -> Void)?

    /// Process names to match (case-insensitive prefix match).
    let processNames: [String]

    /// Polling interval in seconds.
    let pollingInterval: TimeInterval

    /// Create a ProcessMonitor.
    /// - Parameters:
    ///   - processNames: Names to match against running processes. Default: ["claude"].
    ///   - pollingInterval: Seconds between polls. Default: 30.
    init(processNames: [String] = ["claude"], pollingInterval: TimeInterval = 30.0) {
        self.processNames = processNames.map { $0.lowercased() }
        self.pollingInterval = pollingInterval
        logger.info("ProcessMonitor initialized with names: \(processNames), interval: \(pollingInterval)s")
    }

    deinit {
        stopPolling()
    }

    // MARK: - ProcessMonitoring Protocol

    /// Perform a single poll and return the count of matching processes.
    func pollOnce() -> Int {
        let count = countMatchingProcesses()
        logger.debug("Process poll: \(count) claude process(es) found")
        return count
    }

    /// Begin polling at the configured interval.
    /// - Parameter onUpdate: Called with the current process count on each poll.
    func startPolling(onUpdate: @escaping (Int) -> Void) {
        stopPolling()
        onUpdateCallback = onUpdate

        // Fire immediately, then on interval
        let count = pollOnce()
        onUpdate(count)

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let count = self.pollOnce()
            self.onUpdateCallback?(count)
        }
        timer?.tolerance = pollingInterval * 0.1 // 10% tolerance for energy efficiency

        logger.info("Process polling started at \(self.pollingInterval)s interval")
    }

    /// Stop polling. No further callbacks will fire.
    func stopPolling() {
        timer?.invalidate()
        timer = nil
        onUpdateCallback = nil
        logger.info("Process polling stopped")
    }

    // MARK: - Private

    /// Count processes whose name matches any entry in processNames.
    private func countMatchingProcesses() -> Int {
        // Get the number of PIDs
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else {
            logger.warning("proc_listallpids returned \(pidCount)")
            return 0
        }

        // Allocate buffer and get PIDs
        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * Int(pidCount)))
        guard actualCount > 0 else {
            logger.warning("proc_listallpids fill returned \(actualCount)")
            return 0
        }

        var matchCount = 0
        let nameBufferSize = Int(MAXCOMLEN) + 1
        var nameBuffer = [CChar](repeating: 0, count: nameBufferSize)

        for i in 0..<Int(actualCount) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            nameBuffer.withUnsafeMutableBufferPointer { buffer in
                // Reset buffer
                buffer.baseAddress?.initialize(repeating: 0, count: nameBufferSize)
                proc_name(pid, buffer.baseAddress, UInt32(nameBufferSize))
            }

            let name = String(cString: nameBuffer).lowercased()
            guard !name.isEmpty else { continue }

            for processName in processNames {
                if name.hasPrefix(processName) || name.contains(processName) {
                    matchCount += 1
                    break
                }
            }
        }

        return matchCount
    }
}
