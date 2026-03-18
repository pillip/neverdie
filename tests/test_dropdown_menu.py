"""Tests for ISSUE-006: Dropdown menu with Quit and status display.

Validates:
- Right-click menu structure (status line + separator + Quit)
- Status line reflects current state (ON/OFF)
- Quit handler triggers cleanup then terminate
- Left-click still toggles (no regression)
- Menu event handling distinguishes left vs right click
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SBC_PATH = ROOT / "Neverdie" / "Sources" / "StatusBarController.swift"


@pytest.fixture
def sbc_source():
    """Load StatusBarController.swift source."""
    return SBC_PATH.read_text()


class TestMenuStructure:
    """AC: Right-click opens NSMenu with status and Quit items."""

    def test_build_menu_method_exists(self, sbc_source):
        assert "func buildMenu() -> NSMenu" in sbc_source

    def test_menu_contains_status_item(self, sbc_source):
        """Status line uses localized status strings."""
        assert "menu.status_on" in sbc_source or "Neverdie: \\(state)" in sbc_source

    def test_status_item_is_disabled(self, sbc_source):
        """Status line is informational (not clickable)."""
        assert "statusItem.isEnabled = false" in sbc_source

    def test_menu_contains_separator(self, sbc_source):
        assert "NSMenuItem.separator()" in sbc_source

    def test_menu_contains_quit_item(self, sbc_source):
        assert '"menu.quit"' in sbc_source or '"Quit Neverdie"' in sbc_source

    def test_quit_item_has_keyboard_shortcut(self, sbc_source):
        """Quit item has Cmd+Q shortcut."""
        assert 'keyEquivalent: "q"' in sbc_source


class TestClickHandling:
    """AC: Left-click toggles, right-click shows menu."""

    def test_handles_right_mouse_up(self, sbc_source):
        assert ".rightMouseUp" in sbc_source

    def test_handles_left_mouse_up(self, sbc_source):
        assert ".leftMouseUp" in sbc_source

    def test_right_click_shows_menu(self, sbc_source):
        """Right-click builds and displays menu."""
        assert "event?.type == .rightMouseUp" in sbc_source
        assert "buildMenu()" in sbc_source

    def test_left_click_toggles(self, sbc_source):
        """Left-click still calls toggle (no regression from ISSUE-005)."""
        assert "appState.toggle()" in sbc_source

    def test_menu_cleared_after_display(self, sbc_source):
        """Menu is set to nil after display so left-click works again."""
        # After setting menu and performing click, menu must be cleared
        assert "statusItem.menu = nil" in sbc_source


class TestQuitHandler:
    """AC: Quit triggers cleanup then terminate."""

    def test_handle_quit_exists(self, sbc_source):
        assert "func handleQuit" in sbc_source

    def test_quit_calls_cleanup(self, sbc_source):
        """Quit calls appState.cleanup() before terminate."""
        assert "appState.cleanup()" in sbc_source

    def test_quit_calls_terminate(self, sbc_source):
        """Quit terminates the application."""
        assert "NSApplication.shared.terminate(nil)" in sbc_source

    def test_cleanup_before_terminate(self, sbc_source):
        """cleanup() must be called BEFORE terminate()."""
        # Find terminate in handleQuit context
        quit_fn_start = sbc_source.index("func handleQuit")
        quit_section = sbc_source[quit_fn_start:]
        cleanup_in_quit = quit_section.index("appState.cleanup()")
        terminate_in_quit = quit_section.index("NSApplication.shared.terminate(nil)")
        assert cleanup_in_quit < terminate_in_quit, (
            "cleanup must be called before terminate"
        )


class TestStatusDisplay:
    """AC: Status line text reflects current isActive state."""

    def test_status_reads_is_active(self, sbc_source):
        """Status text is derived from appState.isActive."""
        assert "appState.isActive" in sbc_source

    def test_on_state_label(self, sbc_source):
        """ON state shows localized status string."""
        assert '"menu.status_on"' in sbc_source or '"ON"' in sbc_source

    def test_off_state_label(self, sbc_source):
        """OFF state shows localized status string."""
        assert '"menu.status_off"' in sbc_source or '"OFF"' in sbc_source


class TestBuild:
    """Verify the project still builds with menu changes."""

    def test_xcodebuild_succeeds(self):
        """xcodebuild must succeed with the modified StatusBarController."""
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
