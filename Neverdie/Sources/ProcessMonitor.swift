import Darwin
import Foundation
import os

/// Monitors running processes for Claude Code instances using libproc APIs.
///
/// Uses `proc_listallpids()` to enumerate all PIDs and `proc_name()` to match
/// against known Claude Code process names. Polling is Timer-based at 30-second
/// intervals for minimal CPU overhead (NFR-004).
final class ProcessMonitor: ProcessMonitoring {
    /// Known process names for Claude Code (exact match only).
    static let targetNames: Set<String> = ["claude", "claude-code"]

    /// Polling interval in seconds.
    let pollInterval: TimeInterval = 30.0

    /// Timer tolerance for energy efficiency.
    let pollTolerance: TimeInterval = 5.0

    private var timer: Timer?
    private var onUpdate: ((Int) -> Void)?
    private let logger = Logger.process

    // MARK: - ProcessMonitoring

    func pollOnce() -> Int {
        // Get the number of processes
        var pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else {
            logger.error("proc_listallpids failed to get process count (returned \(pidCount))")
            return 0
        }

        // Allocate buffer with margin for processes spawned between the two calls
        var pids = [pid_t](repeating: 0, count: Int(pidCount) + 16)
        pidCount = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.size))
        }

        guard pidCount > 0 else {
            logger.error("proc_listallpids failed to list processes (returned \(pidCount))")
            return 0
        }

        let actualCount = Int(pidCount)
        var matchCount = 0
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)

        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            guard nameLength > 0 else { continue }

            let name = String(cString: nameBuffer)
            if Self.targetNames.contains(name) {
                matchCount += 1
            }
        }

        logger.debug("Process poll: \(matchCount) claude processes found")
        return matchCount
    }

    func startPolling(onUpdate: @escaping (Int) -> Void) {
        stopPolling()
        self.onUpdate = onUpdate

        // Fire immediately on start
        let count = pollOnce()
        onUpdate(count)

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let count = self.pollOnce()
            self.onUpdate?(count)
        }
        timer?.tolerance = pollTolerance

        logger.info("Process polling started (interval: \(self.pollInterval)s)")
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        onUpdate = nil
        logger.info("Process polling stopped")
    }

    deinit {
        stopPolling()
    }
}
