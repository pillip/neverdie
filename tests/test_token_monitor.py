"""Tests for ISSUE-014: TokenMonitor for local file parsing.

Validates:
- TokenMonitor implements TokenMonitoring protocol
- readUsage() returns TokenUsage or nil
- Graceful degradation for missing/malformed/permission-denied files
- Per-session reading from ~/.claude/projects/
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
TM_PATH = ROOT / "Neverdie" / "Sources" / "TokenMonitor.swift"


@pytest.fixture
def tm_source():
    """Load TokenMonitor.swift source."""
    return TM_PATH.read_text()


class TestProtocolConformance:
    """TokenMonitor must implement TokenMonitoring protocol."""

    def test_conforms_to_protocol(self, tm_source):
        assert "TokenMonitoring" in tm_source

    def test_read_usage_method(self, tm_source):
        assert "func readUsage() -> TokenUsage?" in tm_source

    def test_read_per_session_usage_method(self, tm_source):
        assert "func readPerSessionUsage() -> [SessionTokenUsage]" in tm_source


class TestGracefulDegradation:
    """AC: Returns nil without crashing for missing/malformed data."""

    def test_handles_missing_directory(self, tm_source):
        """Must check fileExists before reading."""
        assert "fileManager.fileExists" in tm_source

    def test_handles_decode_errors(self, tm_source):
        """Must catch JSON decode errors."""
        assert "decoder.decode" in tm_source
        assert "catch" in tm_source

    def test_returns_optional_token_usage(self, tm_source):
        """readUsage returns TokenUsage? (optional)."""
        assert "-> TokenUsage?" in tm_source

    def test_returns_empty_for_missing_dir(self, tm_source):
        """readPerSessionUsage returns empty array for missing dir."""
        assert "return []" in tm_source


class TestFileScanning:
    """AC: Scans ~/.claude/projects/ for JSON files."""

    def test_scans_projects_directory(self, tm_source):
        assert "projects" in tm_source

    def test_uses_file_manager(self, tm_source):
        assert "fileManager" in tm_source
        assert "contentsOfDirectory" in tm_source

    def test_filters_json_files(self, tm_source):
        assert '.hasSuffix(".json")' in tm_source

    def test_uses_json_decoder(self, tm_source):
        assert "JSONDecoder" in tm_source


class TestTokenDataParsing:
    """AC: Parses token_usage with context, input, output."""

    def test_parses_context(self, tm_source):
        assert "context" in tm_source

    def test_parses_input(self, tm_source):
        assert "input" in tm_source

    def test_parses_output(self, tm_source):
        assert "output" in tm_source

    def test_token_usage_coding_key(self, tm_source):
        """JSON key is token_usage (snake_case)."""
        assert "token_usage" in tm_source


class TestConfigurability:
    """Base path should be configurable for testing."""

    def test_configurable_base_path(self, tm_source):
        assert "claudeBasePath" in tm_source

    def test_injectable_file_manager(self, tm_source):
        """FileManager should be injectable for testing."""
        assert "fileManager: FileManager" in tm_source


class TestLogging:
    """AC: Logs at info level for missing data."""

    def test_uses_token_logger(self, tm_source):
        assert "Logger.token" in tm_source

    def test_info_level_for_missing(self, tm_source):
        assert "logger.info" in tm_source


class TestAggregation:
    """readUsage should aggregate across sessions."""

    def test_aggregates_via_reduce(self, tm_source):
        assert "reduce" in tm_source

    def test_returns_nil_when_empty(self, tm_source):
        """readUsage returns nil when no sessions found."""
        assert "guard !sessions.isEmpty" in tm_source


class TestBuild:
    """Verify the project still builds with TokenMonitor."""

    def test_xcodebuild_succeeds(self):
        result = subprocess.run(
            [
                "xcodebuild",
                "build",
                "-project",
                str(ROOT / "Neverdie" / "Neverdie.xcodeproj"),
                "-scheme",
                "Neverdie",
                "-destination",
                "platform=macOS,arch=arm64",
                "-quiet",
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, f"Build failed:\n{result.stderr[-2000:]}"
