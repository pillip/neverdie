"""Tests for ISSUE-003: SleepManager with IOPMAssertion.

Verifies the SleepManager Swift implementation including IOKit imports,
protocol conformance, and assertion management.
"""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"
SLEEP_MANAGER = PROJECT_ROOT / "Neverdie" / "Sources" / "SleepManager.swift"


def test_sleep_manager_exists():
    """SleepManager.swift source file exists."""
    assert SLEEP_MANAGER.exists(), "SleepManager.swift not found"


def test_iokit_imports():
    """SleepManager imports IOKit frameworks."""
    content = SLEEP_MANAGER.read_text()
    assert "import IOKit" in content, "Must import IOKit"
    assert "IOKit.pwr_mgt" in content, "Must import IOKit.pwr_mgt for IOPMAssertion"


def test_conforms_to_sleep_managing():
    """SleepManager conforms to SleepManaging protocol."""
    content = SLEEP_MANAGER.read_text()
    assert "SleepManaging" in content, "Must conform to SleepManaging protocol"
    assert "final class SleepManager" in content


def test_prevent_sleep_method():
    """preventSleep() method exists and uses correct assertion type."""
    content = SLEEP_MANAGER.read_text()
    assert "func preventSleep() -> Bool" in content
    assert "kIOPMAssertionTypePreventUserIdleSystemSleep" in content, (
        "Must use PreventUserIdleSystemSleep (not display sleep)"
    )


def test_allow_sleep_method():
    """allowSleep() method exists."""
    content = SLEEP_MANAGER.read_text()
    assert "func allowSleep()" in content


def test_assertion_id_tracked():
    """Assertion ID is tracked for release."""
    content = SLEEP_MANAGER.read_text()
    assert "assertionID" in content
    assert "IOPMAssertionID" in content
    assert "kIOPMNullAssertionID" in content


def test_is_assertion_held_property():
    """isAssertionHeld property exists."""
    content = SLEEP_MANAGER.read_text()
    assert "isAssertionHeld" in content
    assert "Bool" in content


def test_deinit_releases_assertion():
    """deinit releases held assertion."""
    content = SLEEP_MANAGER.read_text()
    assert "deinit" in content
    assert "isAssertionHeld" in content


def test_allow_sleep_noop_when_no_assertion():
    """allowSleep() guards against no held assertion (no crash)."""
    content = SLEEP_MANAGER.read_text()
    assert "guard isAssertionHeld" in content, (
        "allowSleep should guard against no assertion"
    )


def test_assertion_name_configurable():
    """Assertion name is configurable with a default."""
    content = SLEEP_MANAGER.read_text()
    assert "assertionName" in content
    assert "Neverdie" in content


def test_logging_present():
    """Sleep events are logged."""
    content = SLEEP_MANAGER.read_text()
    assert "Logger.sleep" in content or "logger" in content


def test_iopm_assertion_create_call():
    """IOPMAssertionCreateWithName is called in preventSleep."""
    content = SLEEP_MANAGER.read_text()
    assert "IOPMAssertionCreateWithName" in content


def test_iopm_assertion_release_call():
    """IOPMAssertionRelease is called for cleanup."""
    content = SLEEP_MANAGER.read_text()
    assert "IOPMAssertionRelease" in content


def test_xcodebuild_succeeds():
    """Project builds successfully with SleepManager."""
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
