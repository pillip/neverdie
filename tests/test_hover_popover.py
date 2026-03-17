"""Tests for ISSUE-013: Hover popover shell with NSTrackingArea.

Validates:
- PopoverView renders correct text for processCount=0, 1, N
- PopoverManager uses NSTrackingArea with hover delay and grace period
- Popover wired into StatusBarController
- Accessibility labels present
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
PV_PATH = ROOT / "Neverdie" / "Sources" / "PopoverView.swift"
PM_PATH = ROOT / "Neverdie" / "Sources" / "PopoverManager.swift"
SBC_PATH = ROOT / "Neverdie" / "Sources" / "StatusBarController.swift"


@pytest.fixture
def pv_source():
    return PV_PATH.read_text()


@pytest.fixture
def pm_source():
    return PM_PATH.read_text()


@pytest.fixture
def sbc_source():
    return SBC_PATH.read_text()


class TestPopoverView:
    """AC: Correct text for different process counts."""

    def test_no_active_sessions_text(self, pv_source):
        assert '"No active sessions"' in pv_source

    def test_singular_session_text(self, pv_source):
        assert '"1 active session"' in pv_source

    def test_plural_sessions_text(self, pv_source):
        assert "active sessions" in pv_source

    def test_width_240(self, pv_source):
        """Popover width ~240pt."""
        assert "width: 240" in pv_source

    def test_accessibility_label(self, pv_source):
        assert "accessibilityLabel" in pv_source

    def test_process_count_property(self, pv_source):
        assert "let processCount: Int" in pv_source


class TestPopoverManager:
    """AC: NSTrackingArea with hover delay and grace period."""

    def test_tracking_area_setup(self, pm_source):
        assert "NSTrackingArea" in pm_source

    def test_mouse_entered_and_exited(self, pm_source):
        assert "mouseEnteredAndExited" in pm_source

    def test_hover_delay_200ms(self, pm_source):
        """200ms hover delay before showing."""
        assert "hoverDelay: TimeInterval = 0.2" in pm_source

    def test_dismiss_grace_100ms(self, pm_source):
        """100ms grace period before dismissing."""
        assert "dismissGrace: TimeInterval = 0.1" in pm_source

    def test_mouse_entered_handler(self, pm_source):
        assert "func mouseEntered" in pm_source

    def test_mouse_exited_handler(self, pm_source):
        assert "func mouseExited" in pm_source

    def test_uses_dispatch_work_item(self, pm_source):
        """Uses DispatchWorkItem for cancellable timers."""
        assert "DispatchWorkItem" in pm_source

    def test_cancel_dismiss_on_enter(self, pm_source):
        """Cancels pending dismiss when mouse re-enters."""
        assert "dismissTimer?.cancel()" in pm_source

    def test_cancel_show_on_exit(self, pm_source):
        """Cancels pending show when mouse exits."""
        assert "hoverTimer?.cancel()" in pm_source

    def test_uses_ns_popover(self, pm_source):
        assert "NSPopover" in pm_source

    def test_uses_ns_hosting_controller(self, pm_source):
        assert "NSHostingController" in pm_source

    def test_transient_behavior(self, pm_source):
        """Popover behavior is transient (auto-dismiss on click outside)."""
        assert ".transient" in pm_source

    def test_refreshes_token_data(self, pm_source):
        """Refreshes token data when popover opens."""
        assert "refreshTokenUsage" in pm_source

    def test_weak_app_state(self, pm_source):
        """AppState held weakly to avoid retain cycles."""
        assert "weak var appState" in pm_source


class TestStatusBarIntegration:
    """PopoverManager wired into StatusBarController."""

    def test_popover_manager_property(self, sbc_source):
        assert "popoverManager" in sbc_source

    def test_setup_popover_called(self, sbc_source):
        assert "setupPopover()" in sbc_source

    def test_dismiss_on_click(self, sbc_source):
        """Popover dismissed on any click."""
        assert "popoverManager?.dismissPopover()" in sbc_source


class TestBuild:
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
