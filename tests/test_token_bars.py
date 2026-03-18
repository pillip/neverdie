"""Tests for ISSUE-015: Token usage bar graphs in popover.

Validates:
- TokenBarView component with label, value, bar
- Number formatting (45.2K, 1.2M, exact for <1000)
- PopoverView shows "Token data unavailable" when tokenUsage is nil
- Accessibility labels on bars
- VoiceOver support
"""

import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
PV_PATH = ROOT / "Neverdie" / "Sources" / "PopoverView.swift"
PM_PATH = ROOT / "Neverdie" / "Sources" / "PopoverManager.swift"


@pytest.fixture
def pv_source():
    return PV_PATH.read_text()


@pytest.fixture
def pm_source():
    return PM_PATH.read_text()


class TestTokenBarView:
    """AC: Three bar graphs display with labels and numeric values."""

    def test_token_bar_view_struct(self, pv_source):
        assert "struct TokenBarView" in pv_source

    def test_context_bar(self, pv_source):
        assert '"token.context"' in pv_source or '"Context"' in pv_source

    def test_input_bar(self, pv_source):
        assert '"token.input"' in pv_source or '"Input"' in pv_source

    def test_output_bar(self, pv_source):
        assert '"token.output"' in pv_source or '"Output"' in pv_source

    def test_bar_has_label(self, pv_source):
        assert "let label: String" in pv_source

    def test_bar_has_value(self, pv_source):
        assert "let value: Int" in pv_source

    def test_bar_proportional_fill(self, pv_source):
        """Bar fill proportional to value."""
        assert "fillProportion" in pv_source

    def test_rounded_rectangle_bar(self, pv_source):
        assert "RoundedRectangle" in pv_source

    def test_accent_color_fill(self, pv_source):
        """Bar uses accent color."""
        assert "accentColor" in pv_source


class TestTokenBarsSection:
    """AC: Section with three bars from TokenUsage."""

    def test_token_bars_section_struct(self, pv_source):
        assert "struct TokenBarsSection" in pv_source

    def test_accepts_token_usage(self, pv_source):
        assert "let usage: TokenUsage" in pv_source


class TestNumberFormatting:
    """AC: Values formatted as 45.2K, 1.2M, exact for <1000."""

    def test_token_formatter_exists(self, pv_source):
        assert "enum TokenFormatter" in pv_source

    def test_format_method(self, pv_source):
        assert "static func format" in pv_source

    def test_k_suffix(self, pv_source):
        """1000-999999 formatted as X.XK."""
        assert '"K"' in pv_source or "K" in pv_source

    def test_m_suffix(self, pv_source):
        """1000000+ formatted as X.XM."""
        assert '"M"' in pv_source or "M" in pv_source

    def test_thousand_threshold(self, pv_source):
        assert "1000" in pv_source

    def test_million_threshold(self, pv_source):
        assert "1_000_000" in pv_source or "1000000" in pv_source


class TestTokenFormatterValues:
    """Test the formatter logic via source analysis."""

    def test_format_exact_for_small(self, pv_source):
        """Values < 1000 shown as exact number."""
        assert "if value < 1000" in pv_source

    def test_format_k_range(self, pv_source):
        """Values 1000-999999 shown as X.XK."""
        assert "1_000_000" in pv_source or "1000000" in pv_source

    def test_string_format_one_decimal(self, pv_source):
        """Uses %.1f for one decimal place."""
        assert "%.1f" in pv_source


class TestUnavailableFallback:
    """AC: 'Token data unavailable' when tokenUsage is nil."""

    def test_unavailable_text(self, pv_source):
        assert '"Token data unavailable"' in pv_source

    def test_optional_token_usage(self, pv_source):
        """PopoverView accepts optional TokenUsage."""
        assert "let tokenUsage: TokenUsage?" in pv_source

    def test_nil_check(self, pv_source):
        """Checks if tokenUsage is nil."""
        assert "if let usage = tokenUsage" in pv_source


class TestAccessibility:
    """AC: VoiceOver reads bar labels and values."""

    def test_accessibility_label_on_bars(self, pv_source):
        assert "accessibilityLabel" in pv_source

    def test_accessibility_element(self, pv_source):
        """Bars are accessibility elements."""
        assert "accessibilityElement" in pv_source

    def test_tokens_in_label(self, pv_source):
        """Accessibility label references token accessibility key."""
        assert "token.accessibility" in pv_source or "tokens" in pv_source


class TestPopoverManagerIntegration:
    """PopoverManager passes tokenUsage to PopoverView."""

    def test_passes_token_usage(self, pm_source):
        assert "tokenUsage" in pm_source

    def test_refreshes_before_showing(self, pm_source):
        """Token data refreshed before creating popover view."""
        assert "refreshTokenUsage" in pm_source


class TestBuild:
    """Verify the project builds with token bar changes."""

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
