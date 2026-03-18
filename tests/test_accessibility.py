"""Tests for ISSUE-019: Accessibility labels and keyboard navigation.

Validates:
- VoiceOver labels on status item button
- Keyboard toggle support (Space/Enter)
- Popover content accessibility
- Localizable.strings with all user-facing strings
- NSLocalizedString usage in source files
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SBC_PATH = ROOT / "Neverdie" / "Sources" / "StatusBarController.swift"
PV_PATH = ROOT / "Neverdie" / "Sources" / "PopoverView.swift"
STRINGS_PATH = ROOT / "Neverdie" / "Resources" / "en.lproj" / "Localizable.strings"
PBXPROJ_PATH = ROOT / "Neverdie" / "Neverdie.xcodeproj" / "project.pbxproj"


@pytest.fixture
def sbc_source():
    return SBC_PATH.read_text()


@pytest.fixture
def pv_source():
    return PV_PATH.read_text()


@pytest.fixture
def strings_content():
    return STRINGS_PATH.read_text()


@pytest.fixture
def pbxproj_source():
    return PBXPROJ_PATH.read_text()


class TestLocalizableStringsExists:
    """AC: All user-facing strings externalized in Localizable.strings."""

    def test_file_exists(self):
        assert STRINGS_PATH.exists(), "Localizable.strings not found"

    def test_en_lproj_directory(self):
        assert STRINGS_PATH.parent.name == "en.lproj"


class TestLocalizableStringsContent:
    """All expected keys exist in Localizable.strings."""

    def test_status_on_key(self, strings_content):
        assert "status.sleep_prevention_on" in strings_content

    def test_status_off_key(self, strings_content):
        assert "status.sleep_prevention_off" in strings_content

    def test_status_error_key(self, strings_content):
        assert "status.error" in strings_content

    def test_announce_on_key(self, strings_content):
        assert "announce.on" in strings_content

    def test_announce_off_key(self, strings_content):
        assert "announce.off" in strings_content

    def test_announce_error_key(self, strings_content):
        assert "announce.error" in strings_content

    def test_menu_status_on_key(self, strings_content):
        assert "menu.status_on" in strings_content

    def test_menu_status_off_key(self, strings_content):
        assert "menu.status_off" in strings_content

    def test_menu_status_error_key(self, strings_content):
        assert "menu.status_error" in strings_content

    def test_menu_quit_key(self, strings_content):
        assert "menu.quit" in strings_content

    def test_popover_no_sessions_key(self, strings_content):
        assert "popover.no_sessions" in strings_content

    def test_popover_one_session_key(self, strings_content):
        assert "popover.one_session" in strings_content

    def test_popover_n_sessions_key(self, strings_content):
        assert "popover.n_sessions" in strings_content

    def test_popover_token_unavailable_key(self, strings_content):
        assert "popover.token_unavailable" in strings_content

    def test_token_context_key(self, strings_content):
        assert "token.context" in strings_content

    def test_token_input_key(self, strings_content):
        assert "token.input" in strings_content

    def test_token_output_key(self, strings_content):
        assert "token.output" in strings_content

    def test_token_accessibility_key(self, strings_content):
        assert "token.accessibility" in strings_content


class TestStatusBarAccessibility:
    """AC: VoiceOver reads 'Neverdie -- sleep prevention [ON/OFF]'."""

    def test_uses_nslocalized_string(self, sbc_source):
        assert "NSLocalizedString" in sbc_source

    def test_accessibility_label_on(self, sbc_source):
        assert "status.sleep_prevention_on" in sbc_source

    def test_accessibility_label_off(self, sbc_source):
        assert "status.sleep_prevention_off" in sbc_source

    def test_accessibility_label_error(self, sbc_source):
        assert "status.error" in sbc_source

    def test_set_accessibility_label(self, sbc_source):
        assert "setAccessibilityLabel" in sbc_source

    def test_accessibility_role_button(self, sbc_source):
        """Button has accessibility role for keyboard activation."""
        assert "setAccessibilityRole" in sbc_source or "accessibilityRole" in sbc_source


class TestKeyboardToggle:
    """AC: Space/Enter on focused status item triggers toggle."""

    def test_button_action_set(self, sbc_source):
        """Button has action for keyboard activation."""
        assert "button.action" in sbc_source

    def test_accessibility_role(self, sbc_source):
        """Button set as accessibility button role."""
        assert "setAccessibilityRole(.button)" in sbc_source


class TestVoiceOverAnnouncements:
    """AC: VoiceOver announces state changes."""

    def test_announcement_localized(self, sbc_source):
        assert "announce.on" in sbc_source
        assert "announce.off" in sbc_source
        assert "announce.error" in sbc_source

    def test_announcement_posted(self, sbc_source):
        assert "announcementRequested" in sbc_source


class TestMenuLocalization:
    """Menu items use localized strings."""

    def test_menu_status_localized(self, sbc_source):
        assert "menu.status_on" in sbc_source
        assert "menu.status_off" in sbc_source
        assert "menu.status_error" in sbc_source

    def test_quit_localized(self, sbc_source):
        assert "menu.quit" in sbc_source


class TestPopoverLocalization:
    """Popover uses localized strings."""

    def test_session_text_localized(self, pv_source):
        assert "popover.no_sessions" in pv_source
        assert "popover.one_session" in pv_source
        assert "popover.n_sessions" in pv_source

    def test_token_unavailable_localized(self, pv_source):
        assert "popover.token_unavailable" in pv_source

    def test_token_labels_localized(self, pv_source):
        assert "token.context" in pv_source
        assert "token.input" in pv_source
        assert "token.output" in pv_source

    def test_token_accessibility_localized(self, pv_source):
        assert "token.accessibility" in pv_source


class TestPopoverContentAccessibility:
    """AC: Popover content readable by VoiceOver."""

    def test_session_text_accessible(self, pv_source):
        assert "accessibilityLabel" in pv_source

    def test_token_bars_accessible(self, pv_source):
        assert "accessibilityElement" in pv_source

    def test_session_accessible(self, pv_source):
        assert "popover.session_label" in pv_source


class TestXcodeProjectIntegration:
    """Localizable.strings registered in Xcode project."""

    def test_localizable_in_pbxproj(self, pbxproj_source):
        assert "Localizable.strings" in pbxproj_source

    def test_variant_group(self, pbxproj_source):
        assert "PBXVariantGroup" in pbxproj_source

    def test_in_resources_phase(self, pbxproj_source):
        assert "Localizable.strings in Resources" in pbxproj_source


class TestBuild:
    """Verify the project builds with accessibility changes."""

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
