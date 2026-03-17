"""Tests for ISSUE-018: Single-instance guard.

Validates:
- Second instance detection via NSRunningApplication
- Quit on duplicate detection
- Normal launch when no other instance
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_PATH = ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"


@pytest.fixture
def app_source():
    """Load NeverdieApp.swift source."""
    return APP_PATH.read_text()


class TestSingleInstanceGuard:
    """AC: Second instance quits if first is running."""

    def test_checks_running_applications(self, app_source):
        """Uses NSRunningApplication to detect duplicates."""
        assert "NSRunningApplication.runningApplications" in app_source

    def test_uses_bundle_identifier(self, app_source):
        """Checks against app's own bundle identifier."""
        assert "bundleIdentifier" in app_source

    def test_count_check(self, app_source):
        """Quits if count > 1 (self + existing)."""
        assert "runningInstances.count > 1" in app_source

    def test_terminates_on_duplicate(self, app_source):
        """Calls terminate when duplicate detected."""
        assert "NSApplication.shared.terminate(nil)" in app_source

    def test_guard_before_initialization(self, app_source):
        """Guard runs before SleepManager creation."""
        guard_pos = app_source.index("runningInstances.count > 1")
        sleep_mgr_pos = app_source.index("SleepManager()")
        assert guard_pos < sleep_mgr_pos, "Guard must run before initialization"

    def test_logs_duplicate_warning(self, app_source):
        """Logs a warning when duplicate detected."""
        assert "already running" in app_source


class TestBuild:
    """Verify the project builds with single-instance guard."""

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
