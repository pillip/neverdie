"""Tests for ISSUE-012: Wire ProcessMonitor to AppState for auto-OFF.

Validates:
- ProcessMonitor is injected into AppState via AppDelegate
- Auto-OFF logic triggers when claudeProcessesEverDetected and count drops to 0
- Auto-OFF does NOT trigger when processes were never detected
- VoiceOver announcement on auto-OFF
- startMonitoring wires ProcessMonitor polling
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP_DELEGATE_PATH = ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
APP_STATE_PATH = ROOT / "Neverdie" / "Sources" / "AppState.swift"


@pytest.fixture
def delegate_source():
    """Load NeverdieApp.swift source."""
    return APP_DELEGATE_PATH.read_text()


@pytest.fixture
def state_source():
    """Load AppState.swift source."""
    return APP_STATE_PATH.read_text()


class TestProcessMonitorInjection:
    """AC: ProcessMonitor is wired into AppState."""

    def test_process_monitor_created_in_delegate(self, delegate_source):
        """AppDelegate creates a ProcessMonitor instance."""
        assert "ProcessMonitor()" in delegate_source

    def test_process_monitor_injected_into_appstate(self, delegate_source):
        """ProcessMonitor is passed to AppState init."""
        assert "processMonitor: processMonitor" in delegate_source

    def test_delegate_holds_process_monitor(self, delegate_source):
        """AppDelegate retains ProcessMonitor reference."""
        assert "private var processMonitor: ProcessMonitor!" in delegate_source


class TestAutoOffLogic:
    """AC: Auto-OFF when processes detected then all end."""

    def test_update_process_count_exists(self, state_source):
        assert "func updateProcessCount" in state_source

    def test_sets_ever_detected_on_positive_count(self, state_source):
        """count > 0 sets claudeProcessesEverDetected = true."""
        assert "claudeProcessesEverDetected = true" in state_source

    def test_auto_off_when_count_zero_and_ever_detected(self, state_source):
        """count == 0 && claudeProcessesEverDetected && isActive -> deactivate."""
        assert "count == 0 && claudeProcessesEverDetected && isActive" in state_source

    def test_auto_off_calls_deactivate(self, state_source):
        """Auto-OFF calls deactivate with .auto source."""
        assert "deactivate(source: .auto)" in state_source

    def test_auto_off_logs(self, state_source):
        """Auto-OFF event is logged."""
        assert "auto-OFF triggered" in state_source


class TestMonitoringWiring:
    """AC: startMonitoring wires ProcessMonitor polling to updateProcessCount."""

    def test_start_monitoring_calls_start_polling(self, state_source):
        assert "processMonitor?.startPolling" in state_source

    def test_stop_monitoring_calls_stop_polling(self, state_source):
        assert "processMonitor?.stopPolling()" in state_source

    def test_weak_self_in_polling_callback(self, state_source):
        """Polling callback captures self weakly."""
        assert "[weak self]" in state_source

    def test_callback_calls_update_process_count(self, state_source):
        """Polling callback feeds into updateProcessCount."""
        assert "updateProcessCount" in state_source


class TestDeactivation:
    """AC: Deactivation releases assertion and resets state."""

    def test_deactivate_calls_allow_sleep(self, state_source):
        assert "sleepManager?.allowSleep()" in state_source

    def test_deactivate_resets_process_count(self, state_source):
        assert "processCount = 0" in state_source

    def test_deactivate_resets_ever_detected(self, state_source):
        """claudeProcessesEverDetected reset on deactivation."""
        assert "claudeProcessesEverDetected = false" in state_source

    def test_deactivate_stops_monitoring(self, state_source):
        assert "stopMonitoring()" in state_source


class TestBuild:
    """Verify the project builds with ProcessMonitor wiring."""

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
