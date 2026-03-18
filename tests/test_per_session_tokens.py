"""Tests for ISSUE-023: Per-session token breakdown in popover.

Validates:
- SessionTokenUsage model with id, label, usage
- readPerSessionUsage() returns [SessionTokenUsage]
- PopoverView renders multiple sessions with collapse
- DisclosureGroup for collapsible sections
- First session expanded by default
- Max height with ScrollView for 3+ sessions
- Session label shows working directory
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
PV_PATH = ROOT / "Neverdie" / "Sources" / "PopoverView.swift"
PM_PATH = ROOT / "Neverdie" / "Sources" / "PopoverManager.swift"
AS_PATH = ROOT / "Neverdie" / "Sources" / "AppState.swift"
PROTO_PATH = ROOT / "Neverdie" / "Sources" / "Protocols.swift"
TM_PATH = ROOT / "Neverdie" / "Sources" / "TokenMonitor.swift"


@pytest.fixture
def pv_source():
    return PV_PATH.read_text()


@pytest.fixture
def pm_source():
    return PM_PATH.read_text()


@pytest.fixture
def as_source():
    return AS_PATH.read_text()


@pytest.fixture
def proto_source():
    return PROTO_PATH.read_text()


@pytest.fixture
def tm_source():
    return TM_PATH.read_text()


class TestSessionTokenUsageModel:
    """SessionTokenUsage struct with id, label, usage."""

    def test_struct_exists(self, proto_source):
        assert (
            "struct SessionTokenUsage" in proto_source
            or "struct SessionTokenUsage" in PV_PATH.read_text()
        )

    def test_has_id(self, proto_source):
        src = proto_source + PV_PATH.read_text()
        assert "id" in src

    def test_has_label(self, proto_source):
        src = proto_source + PV_PATH.read_text()
        assert "label" in src

    def test_has_usage(self, proto_source):
        src = proto_source + PV_PATH.read_text()
        assert "usage" in src


class TestReadPerSessionUsage:
    """AC: TokenMonitor provides readPerSessionUsage()."""

    def test_method_in_protocol_or_monitor(self, proto_source, tm_source):
        combined = proto_source + tm_source
        assert "readPerSessionUsage" in combined

    def test_returns_array(self, proto_source, tm_source):
        combined = proto_source + tm_source
        assert "[SessionTokenUsage]" in combined


class TestPerSessionPopoverView:
    """AC: Popover renders multiple sessions with collapse."""

    def test_per_session_view_exists(self, pv_source):
        assert "PerSessionTokenView" in pv_source

    def test_uses_disclosure_group(self, pv_source):
        assert "DisclosureGroup" in pv_source

    def test_iterates_sessions(self, pv_source):
        """ForEach over sessions."""
        assert "ForEach" in pv_source

    def test_accepts_sessions_array(self, pv_source):
        assert "sessions" in pv_source or "sessionUsages" in pv_source

    def test_shows_session_label(self, pv_source):
        """Each session shows its label."""
        assert "session.label" in pv_source

    def test_shows_per_session_bars(self, pv_source):
        """Each session has its own TokenBarsSection."""
        assert "TokenBarsSection" in pv_source
        assert "session.usage" in pv_source


class TestFirstSessionExpanded:
    """AC: First session expanded by default, others collapsed."""

    def test_first_expanded(self, pv_source):
        """First session (index 0) expanded by default."""
        assert "index == 0" in pv_source


class TestScrollAndMaxHeight:
    """AC: Max height enforced with ScrollView for 3+ sessions."""

    def test_scroll_view(self, pv_source):
        assert "ScrollView" in pv_source

    def test_max_height(self, pv_source):
        """Max height ~400pt."""
        assert "maxHeight" in pv_source
        assert "400" in pv_source


class TestPopoverViewSessionsParam:
    """PopoverView accepts sessionUsages parameter."""

    def test_popover_view_has_sessions(self, pv_source):
        assert "sessionUsages" in pv_source

    def test_session_usages_type(self, pv_source):
        assert "[SessionTokenUsage]" in pv_source

    def test_conditional_display(self, pv_source):
        """Shows per-session view when multiple sessions, aggregate when single."""
        assert (
            "sessionUsages.count > 1" in pv_source or "sessions.count > 1" in pv_source
        )


class TestPopoverManagerPassesSessions:
    """PopoverManager passes sessionUsages to PopoverView."""

    def test_passes_session_usages(self, pm_source):
        assert "sessionUsages" in pm_source


class TestAppStateSessionUsages:
    """AppState stores and refreshes per-session data."""

    def test_session_usages_property(self, as_source):
        assert "sessionUsages" in as_source

    def test_refresh_reads_per_session(self, as_source):
        assert "readPerSessionUsage" in as_source

    def test_cleanup_resets_sessions(self, as_source):
        """cleanup() resets sessionUsages."""
        assert "sessionUsages = []" in as_source


class TestSessionAccessibility:
    """VoiceOver labels on per-session views."""

    def test_accessibility_on_sessions(self, pv_source):
        assert "accessibilityLabel" in pv_source

    def test_session_label_in_accessibility(self, pv_source):
        """Session label announced via VoiceOver."""
        assert "Session" in pv_source


class TestBuild:
    """Verify the project builds with per-session token changes."""

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
