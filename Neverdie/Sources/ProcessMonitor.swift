import Darwin
import Darwin.POSIX
import Foundation
import os

/// Monitors running processes for Claude Code instances using libproc APIs.
///
/// Uses `proc_listallpids()` to enumerate all PIDs and `proc_pidinfo(PROC_PIDTBSDINFO)`
/// to read each process's comm name. `proc_name()` silently returns 0 for certain
/// native binaries (including Claude Code installed via Homebrew), so we use
/// `proc_pidinfo` which reliably returns the kernel comm field.
/// Polling is Timer-based with two intervals: 30s when active (for responsive
/// auto-OFF) and 90s when inactive (to reduce timer wake-ups and allow App Nap).
final class ProcessMonitor: ProcessMonitoring {
    /// Known process names for Claude Code (exact match only).
    static let targetNames: Set<String> = ["claude", "claude-code"]

    /// Polling interval when Neverdie is active (ON).
    let pollIntervalActive: TimeInterval = 30.0

    /// Polling interval when Neverdie is inactive (OFF).
    /// Longer interval reduces timer wake-ups and allows macOS App Nap.
    let pollIntervalInactive: TimeInterval = 90.0

    /// Whether the monitor is currently using the active (short) polling interval.
    private(set) var isActivePolling: Bool = false

    /// Current effective polling interval.
    var currentInterval: TimeInterval {
        isActivePolling ? pollIntervalActive : pollIntervalInactive
    }

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
        var info = proc_bsdinfo()

        for i in 0..<actualCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
            let ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize)
            guard ret > 0 else { continue }

            let name = withUnsafePointer(to: info.pbi_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cStr in
                    String(cString: cStr)
                }
            }
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

        scheduleTimer()

        logger.info("Process polling started (interval: \(self.currentInterval)s, active: \(self.isActivePolling))")
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        onUpdate = nil
        logger.info("Process polling stopped")
    }

    func setActivePolling(_ active: Bool) {
        guard isActivePolling != active else { return }
        isActivePolling = active

        // Reschedule the timer only if polling is currently running
        if timer != nil, onUpdate != nil {
            timer?.invalidate()
            timer = nil
            scheduleTimer()
            logger.info("Polling interval switched to \(self.currentInterval)s (active: \(active))")
        }
    }

    // MARK: - Private

    private func scheduleTimer() {
        let interval = currentInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let count = self.pollOnce()
            self.onUpdate?(count)
        }
        timer?.tolerance = interval * 0.15
    }

    deinit {
        stopPolling()
    }
}
