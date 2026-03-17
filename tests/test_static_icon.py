"""Tests for ISSUE-004: Static zombie icon assets and OFF state display.

Verifies the zombie sleep icon asset catalog, template rendering config,
and fallback behavior in the NeverdieApp.
"""

import json
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"
ASSETS_DIR = PROJECT_ROOT / "Neverdie" / "Resources" / "Assets.xcassets"
ZOMBIE_SLEEP_DIR = ASSETS_DIR / "ZombieSleep.imageset"


def test_zombie_sleep_imageset_exists():
    """ZombieSleep.imageset directory exists in asset catalog."""
    assert ZOMBIE_SLEEP_DIR.exists(), "ZombieSleep.imageset not found"


def test_zombie_sleep_contents_json():
    """ZombieSleep Contents.json is valid with template rendering."""
    contents = ZOMBIE_SLEEP_DIR / "Contents.json"
    assert contents.exists(), "Contents.json not found in ZombieSleep.imageset"
    data = json.loads(contents.read_text())
    assert "images" in data
    assert len(data["images"]) >= 2, "Should have at least @1x and @2x"

    # Check template rendering intent
    props = data.get("properties", {})
    assert props.get("template-rendering-intent") == "template", (
        "Must use template rendering for light/dark mode"
    )


def test_zombie_sleep_1x_exists():
    """@1x zombie sleep PNG exists."""
    pngs = list(ZOMBIE_SLEEP_DIR.glob("*1x*.png"))
    assert len(pngs) >= 1, "No @1x PNG found"
    # Verify it's a valid PNG (starts with PNG signature)
    data = pngs[0].read_bytes()
    assert data[:4] == b"\x89PNG", "File is not a valid PNG"


def test_zombie_sleep_2x_exists():
    """@2x zombie sleep PNG exists."""
    pngs = list(ZOMBIE_SLEEP_DIR.glob("*2x*.png"))
    assert len(pngs) >= 1, "No @2x PNG found"
    data = pngs[0].read_bytes()
    assert data[:4] == b"\x89PNG", "File is not a valid PNG"


def test_neverdie_app_uses_zombie_icon():
    """NeverdieApp.swift references ZombieSleep icon."""
    app_swift = PROJECT_ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
    content = app_swift.read_text()
    assert "ZombieSleep" in content, "NeverdieApp should reference ZombieSleep"


def test_fallback_text_nd():
    """NeverdieApp has fallback to 'ND' text when image is missing."""
    app_swift = PROJECT_ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
    content = app_swift.read_text()
    assert '"ND"' in content, "Should have 'ND' text fallback"


def test_template_image_set():
    """NeverdieApp sets isTemplate=true on the loaded image."""
    app_swift = PROJECT_ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
    content = app_swift.read_text()
    assert "isTemplate" in content, "Should set isTemplate=true on image"


def test_accessibility_label():
    """Menu bar icon has accessibility label."""
    app_swift = PROJECT_ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
    content = app_swift.read_text()
    assert "accessibilityLabel" in content, "Must have accessibility label"
    assert "OFF" in content, "Accessibility label should mention OFF state"


def test_menu_bar_icon_view():
    """MenuBarIconView struct exists."""
    app_swift = PROJECT_ROOT / "Neverdie" / "Sources" / "NeverdieApp.swift"
    content = app_swift.read_text()
    assert "MenuBarIconView" in content, "MenuBarIconView should be defined"


def test_xcodebuild_succeeds():
    """Project builds successfully with icon assets."""
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
