"""Tests for ISSUE-011: ProcessMonitor with proc_listpids.

Validates:
- ProcessMonitor class implements ProcessMonitoring protocol
- pollOnce() returns Int (process count)
- startPolling/stopPolling timer management
- Configurable process name matching
- Debug-level logging
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
PM_PATH = ROOT / "Neverdie" / "Sources" / "ProcessMonitor.swift"
PROTO_PATH = ROOT / "Neverdie" / "Sources" / "Protocols.swift"


@pytest.fixture
def pm_source():
    """Load ProcessMonitor.swift source."""
    return PM_PATH.read_text()


@pytest.fixture
def proto_source():
    """Load Protocols.swift source."""
    return PROTO_PATH.read_text()


class TestProtocolConformance:
    """ProcessMonitor must implement ProcessMonitoring protocol."""

    def test_conforms_to_protocol(self, pm_source):
        assert "ProcessMonitoring" in pm_source

    def test_poll_once_method(self, pm_source):
        assert "func pollOnce() -> Int" in pm_source

    def test_start_polling_method(self, pm_source):
        assert "func startPolling(onUpdate:" in pm_source

    def test_stop_polling_method(self, pm_source):
        assert "func stopPolling()" in pm_source


class TestProcessDetection:
    """AC: pollOnce detects processes using libproc APIs."""

    def test_uses_proc_listallpids(self, pm_source):
        """Must use proc_listallpids for process enumeration."""
        assert "proc_listallpids" in pm_source

    def test_uses_proc_name(self, pm_source):
        """Must use proc_name for process name extraction."""
        assert "proc_name" in pm_source

    def test_imports_darwin(self, pm_source):
        """Must import Darwin for libproc APIs."""
        assert "import Darwin" in pm_source

    def test_case_insensitive_match(self, pm_source):
        """Process name matching should be case-insensitive."""
        assert "lowercased()" in pm_source

    def test_default_process_names(self, pm_source):
        """Default process names include 'claude'."""
        assert '"claude"' in pm_source


class TestPollingMechanism:
    """AC: Timer-based polling at configurable interval."""

    def test_uses_timer(self, pm_source):
        assert "Timer.scheduledTimer" in pm_source

    def test_default_interval_30s(self, pm_source):
        """Default polling interval should be 30 seconds."""
        assert "pollingInterval: TimeInterval = 30.0" in pm_source

    def test_timer_tolerance(self, pm_source):
        """Timer should have tolerance for energy efficiency."""
        assert "tolerance" in pm_source

    def test_stop_invalidates_timer(self, pm_source):
        """stopPolling must invalidate the timer."""
        assert "timer?.invalidate()" in pm_source
        assert "timer = nil" in pm_source

    def test_weak_self_in_timer(self, pm_source):
        """Timer closure should capture self weakly to avoid retain cycles."""
        assert "[weak self]" in pm_source

    def test_deinit_stops_polling(self, pm_source):
        """deinit should call stopPolling."""
        assert "deinit" in pm_source
        assert "stopPolling()" in pm_source


class TestLogging:
    """AC: Logging at debug level."""

    def test_uses_process_logger(self, pm_source):
        assert "Logger.process" in pm_source

    def test_debug_level_poll_log(self, pm_source):
        assert "logger.debug" in pm_source


class TestConfigurability:
    """Process names and interval should be configurable."""

    def test_configurable_process_names(self, pm_source):
        assert "processNames: [String]" in pm_source

    def test_configurable_interval(self, pm_source):
        assert "pollingInterval: TimeInterval" in pm_source


class TestBuild:
    """Verify the project still builds with ProcessMonitor."""

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
