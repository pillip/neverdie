"""Tests for ISSUE-016: Launch at Login toggle in dropdown menu.

Verifies:
- SMAppService import and usage in StatusBarController
- "Launch at Login" menu item exists in buildMenu()
- Checkmark state reflects SMAppService.mainApp.status
- Toggle action calls register()/unregister()
- Error handling shows NSAlert on failure
- Menu structure: status line, separator, Launch at Login, separator, Quit
"""

import os
import re
import subprocess

import pytest

# Path to the worktree (or main repo)
WORKTREE = os.environ.get(
    "NEVERDIE_WORKTREE",
    os.path.join(os.path.dirname(__file__), ".."),
)
SBC_PATH = os.path.join(WORKTREE, "Neverdie", "Sources", "StatusBarController.swift")


@pytest.fixture
def sbc_source():
    """Read StatusBarController.swift source code."""
    with open(SBC_PATH, "r") as f:
        return f.read()


# ---------------------------------------------------------------------------
# AC1: Menu item exists with checkmark state
# ---------------------------------------------------------------------------


class TestLaunchAtLoginMenuItem:
    """Menu contains 'Launch at Login' item with correct state wiring."""

    def test_import_service_management(self, sbc_source):
        """ServiceManagement framework is imported."""
        assert "import ServiceManagement" in sbc_source

    def test_menu_contains_launch_at_login_item(self, sbc_source):
        """buildMenu() creates a 'Launch at Login' menu item."""
        assert '"Launch at Login"' in sbc_source

    def test_login_item_has_action(self, sbc_source):
        """The Launch at Login menu item has a selector action."""
        assert "handleLaunchAtLogin" in sbc_source

    def test_login_item_has_checkmark_state(self, sbc_source):
        """Menu item state is set based on isLaunchAtLoginEnabled."""
        assert "isLaunchAtLoginEnabled" in sbc_source
        # Checkmark wiring: .on or .off
        assert ".on" in sbc_source
        assert ".off" in sbc_source


# ---------------------------------------------------------------------------
# AC2 & AC3: Toggle register/unregister
# ---------------------------------------------------------------------------


class TestLaunchAtLoginToggle:
    """Toggle calls SMAppService register/unregister."""

    def test_handler_calls_register(self, sbc_source):
        """handleLaunchAtLogin calls SMAppService.mainApp.register()."""
        assert "service.register()" in sbc_source or "register()" in sbc_source

    def test_handler_calls_unregister(self, sbc_source):
        """handleLaunchAtLogin calls SMAppService.mainApp.unregister()."""
        assert "service.unregister()" in sbc_source or "unregister()" in sbc_source

    def test_uses_smappservice_mainapp(self, sbc_source):
        """Uses SMAppService.mainApp for the login item service."""
        assert "SMAppService.mainApp" in sbc_source


# ---------------------------------------------------------------------------
# AC4: Error handling with NSAlert
# ---------------------------------------------------------------------------


class TestLaunchAtLoginErrorHandling:
    """Registration failure shows NSAlert."""

    def test_error_handling_exists(self, sbc_source):
        """handleLaunchAtLogin has try/catch error handling."""
        assert "} catch" in sbc_source

    def test_nsalert_on_failure(self, sbc_source):
        """An NSAlert is shown when registration fails."""
        assert "NSAlert()" in sbc_source

    def test_alert_message_text(self, sbc_source):
        """Alert message says 'Could not enable Launch at Login'."""
        assert "Could not enable Launch at Login" in sbc_source

    def test_alert_shows_error_description(self, sbc_source):
        """Alert informative text includes the error description."""
        assert "error.localizedDescription" in sbc_source


# ---------------------------------------------------------------------------
# Menu structure
# ---------------------------------------------------------------------------


class TestMenuStructure:
    """Menu has correct item ordering with login toggle."""

    def test_menu_has_two_separators(self, sbc_source):
        """buildMenu has at least two separators (before login item and before quit)."""
        build_menu_match = re.search(
            r"func buildMenu\(\).*?\n    \}", sbc_source, re.DOTALL
        )
        assert build_menu_match is not None, "buildMenu() not found"
        build_menu_body = build_menu_match.group(0)
        separator_count = build_menu_body.count("NSMenuItem.separator()")
        assert separator_count >= 2, f"Expected >= 2 separators, got {separator_count}"

    def test_login_item_before_quit(self, sbc_source):
        """'Launch at Login' appears before 'Quit Neverdie' in the source."""
        login_pos = sbc_source.index("Launch at Login")
        quit_pos = sbc_source.index("Quit Neverdie")
        assert login_pos < quit_pos


# ---------------------------------------------------------------------------
# isLaunchAtLoginEnabled property
# ---------------------------------------------------------------------------


class TestIsLaunchAtLoginEnabled:
    """isLaunchAtLoginEnabled property queries SMAppService status."""

    def test_property_exists(self, sbc_source):
        """isLaunchAtLoginEnabled property is defined."""
        assert "var isLaunchAtLoginEnabled: Bool" in sbc_source

    def test_queries_smappservice_status(self, sbc_source):
        """Property checks SMAppService.mainApp.status."""
        assert ".status == .enabled" in sbc_source


# ---------------------------------------------------------------------------
# Build verification
# ---------------------------------------------------------------------------


class TestBuildVerification:
    """Project builds successfully with Launch at Login changes."""

    def test_xcode_build_succeeds(self):
        """xcodebuild compiles without errors."""
        result = subprocess.run(
            [
                "xcodebuild",
                "build",
                "-project",
                os.path.join(WORKTREE, "Neverdie", "Neverdie.xcodeproj"),
                "-scheme",
                "Neverdie",
                "-configuration",
                "Debug",
                "-arch",
                "arm64",
                "CODE_SIGNING_ALLOWED=NO",
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, f"Build failed:\n{result.stderr[-2000:]}"
