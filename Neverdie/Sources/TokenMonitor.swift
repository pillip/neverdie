import Foundation
import os

/// Monitors Claude Code token usage by reading local session files.
///
/// TokenMonitor scans `~/.claude/projects/` for JSON files containing
/// token usage data. It supports both aggregate and per-session reads.
/// All reads are on-demand (no polling timer) and gracefully degrade
/// to nil when data is unavailable, malformed, or inaccessible.
final class TokenMonitor: TokenMonitoring {
    private let logger = Logger.token
    private let fileManager: FileManager
    private let claudeBasePath: String

    /// JSON structure for a Claude Code session's token usage.
    private struct SessionData: Decodable {
        let tokenUsage: TokenData?

        struct TokenData: Decodable {
            let context: Int?
            let input: Int?
            let output: Int?
        }

        enum CodingKeys: String, CodingKey {
            case tokenUsage = "token_usage"
        }
    }

    /// Create a TokenMonitor.
    /// - Parameters:
    ///   - fileManager: FileManager instance for testability. Default: .default.
    ///   - claudeBasePath: Base path for Claude data. Default: ~/.claude.
    init(fileManager: FileManager = .default, claudeBasePath: String? = nil) {
        self.fileManager = fileManager
        self.claudeBasePath = claudeBasePath ?? {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            return "\(home)/.claude"
        }()
        logger.info("TokenMonitor initialized with base path: \(self.claudeBasePath)")
    }

    // MARK: - TokenMonitoring Protocol

    /// Read aggregate token usage across all sessions.
    /// - Returns: Aggregate TokenUsage, or nil if no data is available.
    func readUsage() -> TokenUsage? {
        let sessions = readPerSessionUsage()
        guard !sessions.isEmpty else {
            return nil
        }

        let totalContext = sessions.reduce(0) { $0 + $1.usage.context }
        let totalInput = sessions.reduce(0) { $0 + $1.usage.input }
        let totalOutput = sessions.reduce(0) { $0 + $1.usage.output }

        return TokenUsage(context: totalContext, input: totalInput, output: totalOutput)
    }

    /// Read per-session token usage data.
    /// - Returns: Array of per-session usage data, or empty if unavailable.
    func readPerSessionUsage() -> [SessionTokenUsage] {
        let projectsPath = "\(claudeBasePath)/projects"

        guard fileManager.fileExists(atPath: projectsPath) else {
            logger.info("Claude projects directory not found at \(projectsPath)")
            return []
        }

        var sessions: [SessionTokenUsage] = []

        do {
            let projectDirs = try fileManager.contentsOfDirectory(atPath: projectsPath)

            for projectDir in projectDirs {
                let projectPath = "\(projectsPath)/\(projectDir)"
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDir),
                      isDir.boolValue else {
                    continue
                }

                if let session = readSession(at: projectPath, label: projectDir) {
                    sessions.append(session)
                }
            }
        } catch {
            logger.info("Failed to read projects directory: \(error.localizedDescription)")
            return []
        }

        return sessions
    }

    // MARK: - Private

    /// Read a single session's token usage from a project directory.
    private func readSession(at path: String, label: String) -> SessionTokenUsage? {
        // Look for JSON files in the project directory
        do {
            let files = try fileManager.contentsOfDirectory(atPath: path)
            let jsonFiles = files.filter { $0.hasSuffix(".json") }

            for jsonFile in jsonFiles {
                let filePath = "\(path)/\(jsonFile)"
                guard let data = fileManager.contents(atPath: filePath) else {
                    continue
                }

                let decoder = JSONDecoder()
                do {
                    let sessionData = try decoder.decode(SessionData.self, from: data)
                    if let tokenData = sessionData.tokenUsage {
                        let usage = TokenUsage(
                            context: tokenData.context ?? 0,
                            input: tokenData.input ?? 0,
                            output: tokenData.output ?? 0
                        )
                        return SessionTokenUsage(
                            id: label,
                            label: label,
                            usage: usage
                        )
                    }
                } catch {
                    // Try next file -- this one may not have token data
                    logger.debug("Could not parse \(jsonFile): \(error.localizedDescription)")
                    continue
                }
            }
        } catch {
            logger.info("Failed to read session at \(path): \(error.localizedDescription)")
        }

        return nil
    }
}
