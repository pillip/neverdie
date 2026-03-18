# STATUS: Neverdie

> Last updated: 2026-03-18

## Current Milestone

**All Issues Complete** -- All 23 issues across all 6 phases have been shipped. The project is feature-complete and ready for its first tagged release.

## Issue Summary

| Category | Count |
|----------|-------|
| Total issues | 23 |
| Shipped | 23 (all issues) |
| Remaining | 0 |

### Phase Progress

| Phase | Issues | Status |
|-------|--------|--------|
| Phase 1: MVP | ISSUE-001 ~ 007 | COMPLETE |
| Phase 2: Personality | ISSUE-008 ~ 010 | COMPLETE |
| Phase 3: Intelligence | ISSUE-011 ~ 012 | COMPLETE |
| Phase 4: Monitoring | ISSUE-013 ~ 016 | COMPLETE |
| Phase 4.5: Polish | ISSUE-017 ~ 019 | COMPLETE |
| Phase 5: Distribution | ISSUE-020 ~ 023 | COMPLETE |

## Distribution

### Release Workflow
- GitHub Actions workflow at `.github/workflows/release.yml` builds, signs, notarizes, and creates a DMG on tagged releases (`v*`)
- Required GitHub Secrets: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_NOTARIZE_PASSWORD`

### Homebrew Cask
- Formula at `Cask/neverdie.rb` (copy to a homebrew-neverdie tap repo for distribution)
- After first release: update SHA256 hash in the formula from `:no_check` to the actual hash

### Next Steps to Release
1. Configure GitHub Secrets for Apple signing/notarization
2. Push a tag (e.g., `git tag v1.0.0 && git push origin v1.0.0`) to trigger the release workflow
3. After the release is published, update the Cask formula SHA256

## Key Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Claude Code token data source instability | High | High | Graceful degradation (nil return) |
| Process name mismatch | Medium | High | Configurable matching list |
| macOS hover popover non-standard | Medium | Medium | Click-based popover fallback |
| App Store sandbox + IOPMAssertion | Medium | Medium | Homebrew Cask primary distribution |

## Generated Documents

- [x] `docs/prd_digest.md` -- PRD summary
- [x] `docs/requirements.md` -- 18 FRs, 8 NFRs, 9 User Stories
- [x] `docs/ux_spec.md` -- 7 flows, 5 screens, copy guidelines, accessibility
- [x] `docs/architecture.md` -- MVVM, 5 modules, zero dependencies
- [x] `docs/data_model.md` -- In-memory entities, state machine, data flow
- [x] `docs/test_plan.md` -- Risk-based prioritization, 50+ test cases
- [x] `issues.md` -- 23 issues across 6 phases
