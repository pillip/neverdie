"""Tests for ISSUE-009: AnimationManager with frame cycling.

Validates:
- AnimationManager loads frames and cycles at 6fps
- startAnimation/stopAnimation lifecycle
- Reduced motion support (static frame)
- Transition animations (wake-up, fall-asleep, auto-OFF)
- Fallback to SF Symbol if assets missing
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
AM_PATH = ROOT / "Neverdie" / "Sources" / "AnimationManager.swift"


@pytest.fixture
def am_source():
    return AM_PATH.read_text()


class TestAnimationManagerExists:
    """AnimationManager.swift must exist with required class."""

    def test_file_exists(self):
        assert AM_PATH.exists(), "AnimationManager.swift not found"

    def test_class_defined(self, am_source):
        assert "final class AnimationManager" in am_source


class TestFrameLoading:
    """AC: Pre-load all frames at init."""

    def test_preloads_loop_frames(self, am_source):
        assert "ZombieOn_01" in am_source
        assert "ZombieOn_02" in am_source
        assert "ZombieOn_03" in am_source
        assert "ZombieOn_04" in am_source

    def test_preloads_wake_frames(self, am_source):
        assert "ZombieWake_01" in am_source
        assert "ZombieWake_02" in am_source

    def test_preloads_sleep_frames(self, am_source):
        assert "ZombieSleepTrans_01" in am_source
        assert "ZombieSleepTrans_02" in am_source
        assert "ZombieSleepTrans_03" in am_source

    def test_preloads_autooff_frames(self, am_source):
        assert "ZombieAutoOff_01" in am_source
        assert "ZombieAutoOff_02" in am_source
        assert "ZombieAutoOff_03" in am_source
        assert "ZombieAutoOff_04" in am_source

    def test_nsimage_array(self, am_source):
        """Frames stored as [NSImage]."""
        assert "[NSImage]" in am_source

    def test_template_rendering(self, am_source):
        """All frames set as template images."""
        assert "isTemplate = true" in am_source


class TestTimerSetup:
    """AC: Timer at ~166ms (6fps) with 50ms tolerance."""

    def test_fps_constant(self, am_source):
        assert "fps: Double = 6.0" in am_source

    def test_timer_interval(self, am_source):
        """Timer interval derived from fps."""
        assert "1.0 / fps" in am_source

    def test_timer_tolerance(self, am_source):
        """50ms tolerance for energy efficiency."""
        assert "tolerance = 0.05" in am_source


class TestStartAnimation:
    """AC: startAnimation() cycles through loop frames."""

    def test_start_animation_method(self, am_source):
        assert "func startAnimation()" in am_source

    def test_sets_is_animating(self, am_source):
        assert "isAnimating = true" in am_source

    def test_starts_timer(self, am_source):
        assert "startTimer()" in am_source


class TestStopAnimation:
    """AC: stopAnimation() invalidates timer, returns static OFF icon."""

    def test_stop_animation_method(self, am_source):
        assert "func stopAnimation()" in am_source

    def test_invalidates_timer(self, am_source):
        """Timer must be invalidated on stop."""
        assert "timer?.invalidate()" in am_source

    def test_returns_static_off_icon(self, am_source):
        """currentFrame set to staticOffIcon on stop."""
        assert "currentFrame = staticOffIcon" in am_source

    def test_static_off_icon_property(self, am_source):
        assert "staticOffIcon" in am_source


class TestReducedMotion:
    """AC: Reduced motion -> static ON frame."""

    def test_checks_reduced_motion(self, am_source):
        assert "accessibilityDisplayShouldReduceMotion" in am_source

    def test_observes_accessibility_changes(self, am_source):
        assert "accessibilityDisplayOptionsDidChangeNotification" in am_source

    def test_reduced_motion_static_frame(self, am_source):
        """When reduced motion enabled, uses static frame."""
        assert "reducedMotionEnabled" in am_source


class TestTransitions:
    """AC: playTransition(.wakeUp) plays wake-up frames before main loop."""

    def test_play_transition_method(self, am_source):
        assert "func playTransition(type:" in am_source

    def test_wake_up_transition(self, am_source):
        assert "wakeUp" in am_source

    def test_fall_asleep_transition(self, am_source):
        assert "fallAsleep" in am_source

    def test_auto_off_transition(self, am_source):
        assert "autoOff" in am_source

    def test_transition_completion(self, am_source):
        """Completion handler called after transition."""
        assert "completion" in am_source

    def test_transition_enum(self, am_source):
        assert "enum AnimationTransition" in am_source


class TestFallbackIcon:
    """AC: Fallback to SF Symbol if assets missing."""

    def test_fallback_sf_symbol(self, am_source):
        assert "bolt.fill" in am_source

    def test_fallback_icon_property(self, am_source):
        assert "fallbackIcon" in am_source


class TestCurrentFrame:
    """currentFrame property for StatusBarController to observe."""

    def test_current_frame_property(self, am_source):
        assert "currentFrame" in am_source

    def test_current_frame_is_nsimage(self, am_source):
        assert "var currentFrame: NSImage" in am_source


class TestBuild:
    """Verify the project builds with AnimationManager."""

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
