"""Tests for ISSUE-010: Wire AnimationManager to menu bar icon with state transitions.

Validates:
- StatusBarController accepts AnimationManager in init
- Frame observer updates icon from AnimationManager.currentFrame
- Wake-up transition on toggle ON (OFF->ON)
- Fall-asleep transition on toggle OFF (ON->OFF manual)
- Auto-OFF transition support
- App launch fade-in (200ms)
- Error indicator compositing during animation
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SBC_PATH = ROOT / "Neverdie" / "Sources" / "StatusBarController.swift"
APP_PATH = ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
AM_PATH = ROOT / "Neverdie" / "Sources" / "AnimationManager.swift"
PBXPROJ_PATH = ROOT / "Neverdie" / "Neverdie.xcodeproj" / "project.pbxproj"


@pytest.fixture
def sbc_source():
    return SBC_PATH.read_text()


@pytest.fixture
def app_source():
    return APP_PATH.read_text()


@pytest.fixture
def am_source():
    return AM_PATH.read_text()


@pytest.fixture
def pbxproj_source():
    return PBXPROJ_PATH.read_text()


class TestAnimationManagerWiring:
    """AC: StatusBarController uses AnimationManager for icon display."""

    def test_init_accepts_animation_manager(self, sbc_source):
        assert "animationManager: AnimationManager" in sbc_source

    def test_stores_animation_manager(self, sbc_source):
        assert (
            "let animationManager: AnimationManager" in sbc_source
            or "self.animationManager = animationManager" in sbc_source
        )

    def test_app_delegate_creates_animation_manager(self, app_source):
        assert "animationManager = AnimationManager()" in app_source

    def test_app_delegate_passes_to_sbc(self, app_source):
        assert "animationManager: animationManager" in app_source


class TestFrameObserver:
    """AC: Icon updates from AnimationManager.currentFrame."""

    def test_frame_observer_timer(self, sbc_source):
        """Timer observes frame changes at animation fps."""
        assert "frameObserverTimer" in sbc_source

    def test_start_frame_observer(self, sbc_source):
        assert (
            "func startFrameObserver()" in sbc_source
            or "startFrameObserver()" in sbc_source
        )

    def test_stop_frame_observer(self, sbc_source):
        assert (
            "func stopFrameObserver()" in sbc_source
            or "stopFrameObserver()" in sbc_source
        )

    def test_updates_button_image(self, sbc_source):
        """Frame observer updates button.image."""
        assert "button.image" in sbc_source

    def test_uses_current_frame(self, sbc_source):
        """Reads animationManager.currentFrame."""
        assert "animationManager.currentFrame" in sbc_source


class TestWakeUpTransition:
    """AC: OFF->ON plays wake-up transition then starts main loop."""

    def test_plays_wake_up_on_toggle_on(self, sbc_source):
        assert ".wakeUp" in sbc_source

    def test_starts_animation_after_wake_up(self, sbc_source):
        """After wake-up transition, main animation loop starts."""
        assert "startAnimation()" in sbc_source

    def test_starts_frame_observer_on_toggle(self, sbc_source):
        """Frame observer starts when toggling ON."""
        assert "startFrameObserver()" in sbc_source


class TestFallAsleepTransition:
    """AC: ON->OFF (manual) plays fall-asleep transition."""

    def test_plays_fall_asleep_on_toggle_off(self, sbc_source):
        assert ".fallAsleep" in sbc_source

    def test_stops_animation_after_fall_asleep(self, sbc_source):
        """After fall-asleep transition, animation stops."""
        assert "stopAnimation()" in sbc_source

    def test_stops_frame_observer_on_toggle_off(self, sbc_source):
        assert "stopFrameObserver()" in sbc_source


class TestAutoOffTransition:
    """AC: Auto-OFF uses the auto-OFF transition type."""

    def test_auto_off_transition_method(self, sbc_source):
        assert "playAutoOffTransition" in sbc_source

    def test_uses_auto_off_type(self, sbc_source):
        assert ".autoOff" in sbc_source


class TestLaunchFadeIn:
    """AC: App launch fade-in over ~200ms."""

    def test_fade_in_method(self, sbc_source):
        assert "performLaunchFadeIn" in sbc_source

    def test_uses_ns_animation_context(self, sbc_source):
        assert "NSAnimationContext" in sbc_source

    def test_200ms_duration(self, sbc_source):
        assert "0.2" in sbc_source

    def test_alpha_value_animation(self, sbc_source):
        """Alpha value animated from 0 to 1."""
        assert "alphaValue = 0.0" in sbc_source
        assert "alphaValue = 1.0" in sbc_source


class TestErrorDuringAnimation:
    """Error indicator composited onto animated frames."""

    def test_error_dot_during_animation(self, sbc_source):
        """iconWithErrorDot applied to animated frames too."""
        assert "iconWithErrorDot" in sbc_source

    def test_checks_error_in_animated_update(self, sbc_source):
        """Error checked during frame updates."""
        assert "appState.lastError" in sbc_source


class TestAnimationManagerInProject:
    """AnimationManager.swift registered in Xcode project."""

    def test_animation_manager_in_pbxproj(self, pbxproj_source):
        assert "AnimationManager.swift" in pbxproj_source

    def test_animation_manager_file_ref(self, pbxproj_source):
        assert "AnimationManager.swift" in pbxproj_source

    def test_animation_manager_in_sources_phase(self, pbxproj_source):
        """AnimationManager included in Sources build phase."""
        assert "AnimationManager.swift in Sources" in pbxproj_source


class TestIsPlayingTransitionAccess:
    """AnimationManager.isPlayingTransition accessible from StatusBarController."""

    def test_is_playing_transition_readable(self, am_source):
        """isPlayingTransition is private(set) for external read access."""
        assert "private(set) var isPlayingTransition" in am_source

    def test_sbc_checks_is_playing(self, sbc_source):
        """StatusBarController checks isPlayingTransition."""
        assert "isPlayingTransition" in sbc_source


class TestBuild:
    """Verify the project builds with animation wiring."""

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
