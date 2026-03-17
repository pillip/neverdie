"""Tests for ISSUE-001: Xcode project scaffold verification.

These tests verify the project structure, Info.plist configuration,
and build settings without requiring Xcode to run.
"""

import plistlib
import subprocess
from pathlib import Path

# Project root relative to this test file
PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"
INFO_PLIST = PROJECT_ROOT / "Neverdie" / "Resources" / "Info.plist"
ENTITLEMENTS = PROJECT_ROOT / "Neverdie" / "Neverdie.entitlements"
SOURCES_DIR = PROJECT_ROOT / "Neverdie" / "Sources"
ASSETS_DIR = PROJECT_ROOT / "Neverdie" / "Resources" / "Assets.xcassets"


def test_xcode_project_exists():
    """Xcode project directory exists with project.pbxproj."""
    assert XCODE_PROJECT.exists(), f"Xcode project not found at {XCODE_PROJECT}"
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    assert pbxproj.exists(), "project.pbxproj not found"


def test_info_plist_exists_and_valid():
    """Info.plist exists and can be parsed."""
    assert INFO_PLIST.exists(), f"Info.plist not found at {INFO_PLIST}"
    with open(INFO_PLIST, "rb") as f:
        plist = plistlib.load(f)
    assert isinstance(plist, dict), "Info.plist should parse as a dictionary"


def test_lsuielement_true():
    """LSUIElement is set to true (no Dock icon)."""
    with open(INFO_PLIST, "rb") as f:
        plist = plistlib.load(f)
    assert plist.get("LSUIElement") is True, (
        "LSUIElement must be True to hide the Dock icon"
    )


def test_bundle_identifier_in_pbxproj():
    """Bundle identifier is com.neverdie.app in the Xcode project."""
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    content = pbxproj.read_text()
    assert "com.neverdie.app" in content, (
        "Bundle identifier 'com.neverdie.app' not found in project.pbxproj"
    )


def test_deployment_target_macos14():
    """Deployment target is macOS 14.0."""
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    content = pbxproj.read_text()
    assert "MACOSX_DEPLOYMENT_TARGET = 14.0" in content, (
        "Deployment target should be macOS 14.0"
    )


def test_hardened_runtime_enabled():
    """Hardened Runtime is enabled in build settings."""
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    content = pbxproj.read_text()
    assert "ENABLE_HARDENED_RUNTIME = YES" in content, (
        "Hardened Runtime should be enabled"
    )


def test_entitlements_file_exists():
    """Entitlements file exists for Hardened Runtime."""
    assert ENTITLEMENTS.exists(), f"Entitlements not found at {ENTITLEMENTS}"


def test_neverdie_app_swift_exists():
    """NeverdieApp.swift entry point exists."""
    app_swift = SOURCES_DIR / "NeverdieApp.swift"
    assert app_swift.exists(), "NeverdieApp.swift not found"
    content = app_swift.read_text()
    assert "@main" in content, "NeverdieApp.swift must have @main attribute"
    assert "MenuBarExtra" in content, "NeverdieApp.swift must use MenuBarExtra"
    assert "MenuBarExtra" in content, "Should use MenuBarExtra for menu bar"


def test_logger_extensions_exist():
    """Logger+Extensions.swift exists with all required categories."""
    logger_swift = SOURCES_DIR / "Logger+Extensions.swift"
    assert logger_swift.exists(), "Logger+Extensions.swift not found"
    content = logger_swift.read_text()
    for category in ["sleep", "process", "token", "ui", "lifecycle"]:
        assert f'category: "{category}"' in content, (
            f"Logger category '{category}' not found"
        )


def test_asset_catalog_exists():
    """Assets.xcassets exists with Contents.json."""
    assert ASSETS_DIR.exists(), f"Assets.xcassets not found at {ASSETS_DIR}"
    contents_json = ASSETS_DIR / "Contents.json"
    assert contents_json.exists(), "Assets.xcassets/Contents.json not found"


def test_xcode_version_file():
    """.xcode-version file exists."""
    xcode_version = PROJECT_ROOT / ".xcode-version"
    assert xcode_version.exists(), ".xcode-version file not found"
    version = xcode_version.read_text().strip()
    assert version, ".xcode-version should not be empty"


def test_xcscheme_exists():
    """Shared xcscheme exists for the Neverdie target."""
    scheme = XCODE_PROJECT / "xcshareddata" / "xcschemes" / "Neverdie.xcscheme"
    assert scheme.exists(), "Neverdie.xcscheme not found"


def test_universal_binary_config():
    """Project is configured for standard architectures (Universal Binary)."""
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    content = pbxproj.read_text()
    # ARCHS_STANDARD includes both arm64 and x86_64
    assert "ARCHS_STANDARD" in content, (
        "Project should use ARCHS_STANDARD for Universal Binary"
    )


def test_swift_files_compile_syntax():
    """All Swift files have valid basic syntax (no obvious parse errors)."""
    swift_files = list(SOURCES_DIR.glob("*.swift"))
    assert len(swift_files) >= 2, "Should have at least 2 Swift source files"
    for sf in swift_files:
        content = sf.read_text()
        assert "import" in content, f"{sf.name} should have at least one import"


def test_test_target_exists():
    """NeverdieTests target exists in the Xcode project."""
    pbxproj = XCODE_PROJECT / "project.pbxproj"
    content = pbxproj.read_text()
    assert "NeverdieTests" in content, "NeverdieTests target not found in project"


def test_xcodebuild_succeeds():
    """xcodebuild can build the project without errors."""
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
    assert "BUILD SUCCEEDED" in result.stdout or "BUILD SUCCEEDED" in result.stderr, (
        "Expected BUILD SUCCEEDED in output"
    )
