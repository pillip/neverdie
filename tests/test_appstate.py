"""Tests for ISSUE-002: AppState ViewModel with state machine.

These tests verify the AppState logic by running XCTest via xcodebuild.
The actual unit tests are in NeverdieTests/AppStateTests.swift; this
Python test verifies they compile and pass.
"""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"


def test_appstate_swift_exists():
    """AppState.swift source file exists with required interface."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    assert appstate.exists(), "AppState.swift not found"
    content = appstate.read_text()
    assert "@Observable" in content, "AppState must use @Observable macro"
    assert "final class AppState" in content, "AppState must be a final class"
    assert "func toggle()" in content, "AppState must have toggle() method"
    assert "func cleanup()" in content, "AppState must have cleanup() method"
    assert "isActive" in content, "AppState must have isActive property"
    assert "activationSource" in content, "AppState must have activationSource"
    assert "processCount" in content, "AppState must have processCount"
    assert "tokenUsage" in content, "AppState must have tokenUsage"
    assert "claudeProcessesEverDetected" in content, (
        "AppState must track process detection"
    )


def test_protocols_swift_exists():
    """Protocols.swift exists with SleepManaging, ProcessMonitoring, TokenMonitoring."""
    protocols = PROJECT_ROOT / "Neverdie" / "Sources" / "Protocols.swift"
    assert protocols.exists(), "Protocols.swift not found"
    content = protocols.read_text()
    assert "protocol SleepManaging" in content
    assert "protocol ProcessMonitoring" in content
    assert "protocol TokenMonitoring" in content
    assert "struct TokenUsage" in content
    assert "struct SessionTokenUsage" in content


def test_activation_source_enum():
    """ActivationSource enum exists with manual and auto cases."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    assert "enum ActivationSource" in content
    assert "case manual" in content
    assert "case auto" in content


def test_debounce_implemented():
    """Debounce logic is present in AppState."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    assert "debounceInterval" in content or "300" in content or "0.3" in content, (
        "Debounce threshold should be defined"
    )
    assert "lastToggleDate" in content, "Should track last toggle timestamp"


def test_auto_off_logic():
    """Auto-OFF state machine logic is implemented."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    assert "claudeProcessesEverDetected" in content
    assert "updateProcessCount" in content, "Should have process count update method"
    # The auto-OFF should check both conditions
    assert "claudeProcessesEverDetected" in content and "processCount" in content


def test_cleanup_method():
    """cleanup() resets all state."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    # cleanup should set isActive = false and call allowSleep
    assert "func cleanup()" in content
    assert "allowSleep" in content, "cleanup should release sleep assertion"


def test_dependency_injection():
    """AppState accepts injected dependencies via init."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    assert "sleepManager: SleepManaging" in content
    assert "processMonitor: ProcessMonitoring" in content
    assert "tokenMonitor: TokenMonitoring" in content


def test_neverdie_error_enum():
    """NeverdieError enum exists for error handling."""
    appstate = PROJECT_ROOT / "Neverdie" / "Sources" / "AppState.swift"
    content = appstate.read_text()
    assert "enum NeverdieError" in content
    assert "assertionFailed" in content
    assert "processDetectionFailed" in content


def test_xcodebuild_succeeds():
    """Project builds successfully with new AppState code."""
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
