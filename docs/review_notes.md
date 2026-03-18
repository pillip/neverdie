# Review Notes: ISSUE-022 -- Homebrew Cask Formula

## Code Review

### Findings
- **Ruby syntax**: Validated via `ruby -c`, syntax is correct.
- **Cask structure**: Follows standard Homebrew Cask conventions (version, sha256, url, name, desc, homepage, depends_on, app, caveats, zap).
- **URL interpolation**: Uses `#{version}` in URL template, which auto-updates when version field is changed.
- **SHA256**: Set to `:no_check` as placeholder until first release. This is standard practice for initial formula creation.
- **macOS dependency**: Correctly requires Sonoma (14.0+) matching the app's deployment target.
- **Zap stanza**: Includes cleanup for Caches and Preferences directories matching the bundle ID.
- **Caveats**: Clear usage instructions for menu bar app interaction.

### Changes Made
None required.

### Follow-ups
- After first release: update SHA256 from `:no_check` to actual hash from release notes.
- Set up homebrew-neverdie tap repo for custom tap distribution.
- Consider submitting to homebrew/homebrew-cask for wider distribution later.

## Security Findings

### Severity: None
- Formula downloads from GitHub Releases (HTTPS).
- No scripts or post-install hooks that could execute arbitrary code.
- SHA256 verification will be enforced after first release.
