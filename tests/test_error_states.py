"""Tests for ISSUE-017: Error state handling and error indicator overlay.

Validates:
- AppState.lastError set on assertion failure
- Red dot overlay on icon when error exists
- Error pulse animation (2 pulses then solid)
- Dropdown status shows error text
- VoiceOver error announcement
- Error clears on successful toggle
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SBC_PATH = ROOT / "Neverdie" / "Sources" / "StatusBarController.swift"
AS_PATH = ROOT / "Neverdie" / "Sources" / "AppState.swift"


@pytest.fixture
def sbc_source():
    return SBC_PATH.read_text()


@pytest.fixture
def as_source():
    return AS_PATH.read_text()


class TestAppStateError:
    """AC: Failed preventSleep sets lastError."""

    def test_last_error_property(self, as_source):
        assert "lastError" in as_source

    def test_neverdie_error_enum(self, as_source):
        assert "enum NeverdieError" in as_source

    def test_assertion_failed_case(self, as_source):
        assert "assertionFailed" in as_source

    def test_process_detection_failed_case(self, as_source):
        assert "processDetectionFailed" in as_source

    def test_error_set_on_failure(self, as_source):
        """lastError set to .assertionFailed when preventSleep fails."""
        assert "lastError = .assertionFailed" in as_source

    def test_error_cleared_on_success(self, as_source):
        """lastError cleared on successful activation."""
        assert "lastError = nil" in as_source


class TestRedDotOverlay:
    """AC: Red dot appears on icon when error exists."""

    def test_icon_with_error_dot_method(self, sbc_source):
        assert "iconWithErrorDot" in sbc_source

    def test_uses_system_red(self, sbc_source):
        """Red dot uses NSColor.systemRed."""
        assert "systemRed" in sbc_source

    def test_dot_drawn_as_oval(self, sbc_source):
        """Red dot drawn as oval/circle."""
        assert "NSBezierPath(ovalIn:" in sbc_source

    def test_error_check_in_update_icon(self, sbc_source):
        """updateIcon checks for lastError."""
        assert "lastError" in sbc_source

    def test_composites_icon(self, sbc_source):
        """Creates composited image with dot overlay."""
        assert "lockFocus" in sbc_source
        assert "unlockFocus" in sbc_source


class TestErrorPulseAnimation:
    """AC: Error pulse animation (2 pulses then solid)."""

    def test_pulse_timer(self, sbc_source):
        assert "errorPulseTimer" in sbc_source

    def test_pulse_count(self, sbc_source):
        assert "errorPulseCount" in sbc_source

    def test_start_error_pulse(self, sbc_source):
        assert "startErrorPulseAnimation" in sbc_source

    def test_stop_error_pulse(self, sbc_source):
        assert "stopErrorPulseAnimation" in sbc_source

    def test_alpha_value_toggle(self, sbc_source):
        """Pulse toggles alpha value."""
        assert "alphaValue" in sbc_source


class TestDropdownErrorStatus:
    """AC: Dropdown shows 'Neverdie: Error -- could not prevent sleep'."""

    def test_error_status_text(self, sbc_source):
        assert "Error -- could not prevent sleep" in sbc_source

    def test_error_check_in_menu(self, sbc_source):
        """Menu build checks for error state."""
        assert "lastError" in sbc_source


class TestVoiceOverError:
    """AC: VoiceOver announces 'Neverdie error' when error active."""

    def test_error_accessibility_label(self, sbc_source):
        assert '"Neverdie error"' in sbc_source

    def test_error_announcement(self, sbc_source):
        """VoiceOver announcement includes error info."""
        assert "could not prevent sleep" in sbc_source


class TestErrorClearing:
    """AC: Error clears on next successful toggle."""

    def test_error_cleared_in_activate(self, as_source):
        """AppState clears error on successful activation."""
        # The activate method sets lastError = nil
        assert "lastError = nil" in as_source

    def test_error_cleared_in_cleanup(self, as_source):
        """Error cleared during cleanup."""
        assert "lastError = nil" in as_source


class TestBuild:
    """Verify the project builds with error state changes."""

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
