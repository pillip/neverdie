# typed: false
# frozen_string_literal: true

# Homebrew Cask formula for Neverdie
#
# To use this formula with a custom tap:
#   1. Create a repo: github.com/pillip/homebrew-neverdie
#   2. Copy this file to Casks/neverdie.rb in that repo
#   3. Users install via: brew tap pillip/neverdie && brew install --cask neverdie
#
# To update after a new release:
#   1. Update the `version` field to the new version number
#   2. Update the `sha256` field with the SHA256 hash from the GitHub Release notes
#   3. The URL will auto-update based on the version interpolation

cask "neverdie" do
  version "1.0.0"
  sha256 :no_check # Replace with actual SHA256 after first release

  url "https://github.com/pillip/neverdie/releases/download/v#{version}/Neverdie.dmg"
  name "Neverdie"
  desc "macOS menu bar app that prevents system sleep while Claude Code is running"
  homepage "https://github.com/pillip/neverdie"

  # Only supports macOS 14.0 (Sonoma) and later
  depends_on macos: ">= :sonoma"

  app "Neverdie.app"

  # Accessibility: the app requires no special permissions beyond standard menu bar access
  caveats <<~EOS
    Neverdie is a menu bar app that prevents your Mac from sleeping
    while Claude Code sessions are active.

    After installation:
    - Neverdie will appear in your menu bar
    - Left-click the icon to toggle sleep prevention
    - Right-click for the dropdown menu (Quit, Launch at Login)

    To enable Launch at Login, right-click the menu bar icon
    and select "Launch at Login".
  EOS

  zap trash: [
    "~/Library/Caches/com.neverdie.app",
    "~/Library/Preferences/com.neverdie.app.plist",
  ]
end
