"""Tests for ISSUE-005: Wire left-click toggle to AppState and SleepManager.

Verifies the StatusBarController, AppDelegate, and toggle wiring.
"""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"
SOURCES = PROJECT_ROOT / "Neverdie" / "Sources"


def test_status_bar_controller_exists():
    """StatusBarController.swift exists."""
    sbc = SOURCES / "StatusBarController.swift"
    assert sbc.exists(), "StatusBarController.swift not found"


def test_status_bar_controller_interface():
    """StatusBarController has required methods."""
    content = (SOURCES / "StatusBarController.swift").read_text()
    assert "class StatusBarController" in content
    assert "handleClick" in content, "Must handle left-click"
    assert "updateIcon" in content, "Must update icon on state change"
    assert "announceStateChange" in content, "Must announce for VoiceOver"


def test_left_click_toggle_wired():
    """Left click is wired to AppState.toggle()."""
    content = (SOURCES / "StatusBarController.swift").read_text()
    assert "appState.toggle()" in content, "Click must call appState.toggle()"
    assert "leftMouseUp" in content, "Must handle left mouse up"


def test_icon_switching():
    """Icon switches between OFF and ON states via AnimationManager."""
    content = (SOURCES / "StatusBarController.swift").read_text()
    assert "staticOffIcon" in content or "animationManager" in content, (
        "Must reference OFF icon via AnimationManager"
    )
    assert "currentFrame" in content, "Must use currentFrame for ON icon"
    assert "updateIcon" in content, "Must have updateIcon method"


def test_voiceover_announcement():
    """VoiceOver announcement is posted on toggle."""
    content = (SOURCES / "StatusBarController.swift").read_text()
    assert "announcementRequested" in content, "Must post VoiceOver announcement"
    assert "Neverdie" in content


def test_accessibility_label():
    """Accessibility label updates with state."""
    content = (SOURCES / "StatusBarController.swift").read_text()
    assert "setAccessibilityLabel" in content or "accessibilityLabel" in content
    assert "sleep_prevention" in content or "sleep prevention" in content


def test_app_delegate_exists():
    """AppDelegate class exists in NeverdieApp.swift."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "class AppDelegate" in content
    assert "NSApplicationDelegate" in content


def test_app_delegate_creates_appstate():
    """AppDelegate creates AppState with SleepManager."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "SleepManager()" in content, "Must create SleepManager"
    assert "AppState(" in content, "Must create AppState"
    assert "StatusBarController(" in content, "Must create StatusBarController"


def test_app_delegate_cleanup():
    """applicationWillTerminate calls cleanup."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "applicationWillTerminate" in content
    assert "cleanup()" in content


def test_neverdie_app_uses_delegate():
    """NeverdieApp uses NSApplicationDelegateAdaptor."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "NSApplicationDelegateAdaptor" in content


def test_xcodebuild_succeeds():
    """Project builds with toggle wiring."""
    result = subprocess.run(
        [
            "xcodebuild",
            "build",
            "-project",
            str(XCODE_PROJECT),
            "-scheme",
            "Neverdie",
            "-configuration",
            "Debug",
            "-arch",
            "arm64",
            "CODE_SIGN_IDENTITY=-",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGNING_ALLOWED=NO",
        ],
        capture_output=True,
        text=True,
        timeout=120,
    )
    assert result.returncode == 0, f"xcodebuild failed:\n{result.stderr[-1000:]}"
