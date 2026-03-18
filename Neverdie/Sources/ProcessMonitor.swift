import Darwin
import Foundation
import os

/// Monitors the system process table for running Claude Code processes.
///
/// ProcessMonitor uses `proc_pidpath` (not `proc_name`, which returns empty
/// for Node.js-based CLI tools like Claude Code) to enumerate running
/// processes and count those matching Claude Code executable paths.
final class ProcessMonitor: ProcessMonitoring {
    private let logger = Logger.process
    private var timer: Timer?
    private var onUpdateCallback: ((Int) -> Void)?

    /// Process name patterns to match in executable path (case-insensitive).
    let processPatterns: [String]

    /// Polling interval in seconds.
    let pollingInterval: TimeInterval

    /// Create a ProcessMonitor.
    /// - Parameters:
    ///   - processPatterns: Patterns to match in process paths. Default: ["claude"].
    ///   - pollingInterval: Seconds between polls. Default: 30.
    init(processPatterns: [String] = ["claude"], pollingInterval: TimeInterval = 30.0) {
        self.processPatterns = processPatterns.map { $0.lowercased() }
        self.pollingInterval = pollingInterval
        logger.info("ProcessMonitor initialized with patterns: \(processPatterns), interval: \(pollingInterval)s")
    }

    deinit {
        stopPolling()
    }

    // MARK: - ProcessMonitoring Protocol

    func pollOnce() -> Int {
        let count = countMatchingProcesses()
        logger.debug("Process poll: \(count) claude process(es) found")
        return count
    }

    func startPolling(onUpdate: @escaping (Int) -> Void) {
        stopPolling()
        onUpdateCallback = onUpdate

        let count = pollOnce()
        onUpdate(count)

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let count = self.pollOnce()
            self.onUpdateCallback?(count)
        }
        timer?.tolerance = pollingInterval * 0.1

        logger.info("Process polling started at \(self.pollingInterval)s interval")
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        onUpdateCallback = nil
        logger.info("Process polling stopped")
    }

    // MARK: - Private

    /// Count processes whose executable path contains any of the process patterns.
    /// Uses proc_pidpath instead of proc_name because Claude Code (Node.js-based)
    /// returns empty string from proc_name.
    private func countMatchingProcesses() -> Int {
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else {
            logger.warning("proc_listallpids returned \(pidCount)")
            return 0
        }

        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        let actualCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * Int(pidCount)))
        guard actualCount > 0 else {
            logger.warning("proc_listallpids fill returned \(actualCount)")
            return 0
        }

        var matchCount = 0
        let pathBufferSize = Int(MAXPATHLEN)
        var pathBuffer = [CChar](repeating: 0, count: pathBufferSize)

        for i in 0..<Int(actualCount) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(pathBufferSize))
            guard pathLen > 0 else { continue }

            let path = String(cString: pathBuffer).lowercased()
            guard !path.isEmpty else { continue }

            // Match against patterns - look for "claude" in the executable path
            // but exclude Claude.app (desktop app) and Neverdie itself
            for pattern in processPatterns {
                if path.contains(pattern) &&
                   !path.contains("claude.app") &&
                   !path.contains("neverdie") {
                    matchCount += 1
                    break
                }
            }
        }

        return matchCount
    }
}
