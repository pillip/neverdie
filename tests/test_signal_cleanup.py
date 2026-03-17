"""Tests for ISSUE-007: SIGTERM/SIGINT and applicationWillTerminate cleanup."""

import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
XCODE_PROJECT = PROJECT_ROOT / "Neverdie" / "Neverdie.xcodeproj"
SOURCES = PROJECT_ROOT / "Neverdie" / "Sources"


def test_signal_handler_exists():
    """SignalHandler.swift exists."""
    assert (SOURCES / "SignalHandler.swift").exists()


def test_signal_handler_registers_sigterm():
    """SignalHandler registers SIGTERM handler."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "SIGTERM" in content
    assert "DispatchSource.makeSignalSource" in content


def test_signal_handler_registers_sigint():
    """SignalHandler registers SIGINT handler."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "SIGINT" in content


def test_signal_handler_calls_cleanup():
    """Signal handlers call cleanup closure."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "cleanup()" in content


def test_signal_handler_exits_after_cleanup():
    """Signal handlers exit(0) after cleanup."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "exit(0)" in content


def test_signal_handler_ignores_default():
    """Default signal handling is ignored before DispatchSource."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "SIG_IGN" in content


def test_signal_handler_unregister():
    """SignalHandler.unregister() cancels sources."""
    content = (SOURCES / "SignalHandler.swift").read_text()
    assert "func unregister()" in content
    assert "cancel()" in content


def test_app_delegate_registers_signals():
    """AppDelegate registers signal handlers on launch."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "SignalHandler.register" in content


def test_app_delegate_unregisters_on_terminate():
    """AppDelegate unregisters signal handlers on terminate."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "SignalHandler.unregister" in content
    assert "applicationWillTerminate" in content


def test_cleanup_called_on_terminate():
    """applicationWillTerminate calls cleanup."""
    content = (SOURCES / "NeverdieApp.swift").read_text()
    assert "cleanup()" in content


def test_xcodebuild_succeeds():
    """Project builds with signal handling."""
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
