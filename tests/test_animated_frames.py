"""Tests for ISSUE-008: Animated zombie frame assets for ON state.

Validates:
- All required frame imagesets exist in asset catalog
- Each imageset has @1x (18x18) and @2x (36x36) PNGs
- Template rendering intent is set on all imagesets
- Correct number of frames per animation type
"""

import json
import pathlib
import struct
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "Neverdie" / "Resources" / "Assets.xcassets"

# Expected frame names per AC
LOOP_FRAMES = ["ZombieOn_01", "ZombieOn_02", "ZombieOn_03", "ZombieOn_04"]
WAKE_FRAMES = ["ZombieWake_01", "ZombieWake_02"]
SLEEP_FRAMES = ["ZombieSleepTrans_01", "ZombieSleepTrans_02", "ZombieSleepTrans_03"]
AUTOOFF_FRAMES = [
    "ZombieAutoOff_01",
    "ZombieAutoOff_02",
    "ZombieAutoOff_03",
    "ZombieAutoOff_04",
]
ALL_FRAMES = LOOP_FRAMES + WAKE_FRAMES + SLEEP_FRAMES + AUTOOFF_FRAMES


def read_png_dimensions(png_path):
    """Read width and height from PNG IHDR chunk."""
    with open(png_path, "rb") as f:
        sig = f.read(8)
        assert sig == b"\x89PNG\r\n\x1a\n", f"Not a valid PNG: {png_path}"
        struct.unpack(">I", f.read(4))  # skip chunk length
        chunk_type = f.read(4)
        assert chunk_type == b"IHDR"
        width, height = struct.unpack(">II", f.read(8))
    return width, height


class TestFrameExistence:
    """AC: At least 4 loop frames exist."""

    @pytest.mark.parametrize("frame_name", ALL_FRAMES)
    def test_imageset_exists(self, frame_name):
        imageset = ASSETS / f"{frame_name}.imageset"
        assert imageset.is_dir(), f"Missing imageset: {frame_name}"

    def test_loop_frame_count(self):
        """At least 4 loop frames."""
        existing = [f for f in LOOP_FRAMES if (ASSETS / f"{f}.imageset").is_dir()]
        assert len(existing) >= 4

    def test_wake_frame_count(self):
        """Wake-up has 2 frames."""
        existing = [f for f in WAKE_FRAMES if (ASSETS / f"{f}.imageset").is_dir()]
        assert len(existing) == 2

    def test_sleep_frame_count(self):
        """Fall-asleep has 3 frames."""
        existing = [f for f in SLEEP_FRAMES if (ASSETS / f"{f}.imageset").is_dir()]
        assert len(existing) == 3

    def test_autooff_frame_count(self):
        """Auto-OFF has 4 frames."""
        existing = [f for f in AUTOOFF_FRAMES if (ASSETS / f"{f}.imageset").is_dir()]
        assert len(existing) == 4


class TestImageDimensions:
    """All frames must be 18x18 @1x and 36x36 @2x."""

    @pytest.mark.parametrize("frame_name", ALL_FRAMES)
    def test_1x_dimensions(self, frame_name):
        png_path = ASSETS / f"{frame_name}.imageset" / f"{frame_name.lower()}_1x.png"
        assert png_path.exists(), f"Missing @1x PNG for {frame_name}"
        w, h = read_png_dimensions(png_path)
        assert (w, h) == (18, 18), f"@1x should be 18x18, got {w}x{h}"

    @pytest.mark.parametrize("frame_name", ALL_FRAMES)
    def test_2x_dimensions(self, frame_name):
        png_path = ASSETS / f"{frame_name}.imageset" / f"{frame_name.lower()}_2x.png"
        assert png_path.exists(), f"Missing @2x PNG for {frame_name}"
        w, h = read_png_dimensions(png_path)
        assert (w, h) == (36, 36), f"@2x should be 36x36, got {w}x{h}"


class TestTemplateRendering:
    """AC: All frames have isTemplate == true (via asset catalog)."""

    @pytest.mark.parametrize("frame_name", ALL_FRAMES)
    def test_template_rendering_intent(self, frame_name):
        contents_path = ASSETS / f"{frame_name}.imageset" / "Contents.json"
        assert contents_path.exists()
        contents = json.loads(contents_path.read_text())
        assert (
            contents.get("properties", {}).get("template-rendering-intent")
            == "template"
        )


class TestBuild:
    """Verify the project still builds with animation assets."""

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
