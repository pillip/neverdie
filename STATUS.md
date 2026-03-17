# STATUS: Neverdie

> Last updated: 2026-03-18

## Current Milestone

**Kickoff 완료** -- 모든 planning 문서 생성 완료, 구현 대기 중.

## Issue Summary

| 항목 | 수 |
|------|-----|
| 총 이슈 | 23 |
| P0 (Must) | 7 (ISSUE-001 ~ 007) |
| P1 (Should) | 12 (ISSUE-008 ~ 019) |
| P2 (Could) | 4 (ISSUE-020 ~ 023) |
| 총 예상 공수 | 18.5d |

### Phase별 진행

| Phase | Issues | 예상 | 상태 |
|-------|--------|------|------|
| Phase 1: MVP | ISSUE-001 ~ 007 | 5d | Backlog |
| Phase 2: Personality | ISSUE-008 ~ 010 | 3d | Backlog |
| Phase 3: Intelligence | ISSUE-011 ~ 012 | 1.5d | Backlog |
| Phase 4: Monitoring | ISSUE-013 ~ 016 | 4d | Backlog |
| Phase 4.5: Polish | ISSUE-017 ~ 019 | 1.5d | Backlog |
| Phase 5: Distribution | ISSUE-020 ~ 023 | 3.5d | Backlog |

## Next Issues to Implement

1. **ISSUE-001** (P0, 0.5d): Scaffold Xcode project -- 모든 후속 이슈의 선행 조건
2. **ISSUE-002** (P0, 1d): AppState ViewModel + state machine -- ISSUE-001 이후
3. **ISSUE-003** (P0, 1d): SleepManager IOPMAssertion -- ISSUE-001 이후 (002와 병렬 가능)

## Key Risks

| 리스크 | 가능성 | 영향 | 완화 |
|--------|--------|------|------|
| Claude Code 토큰 데이터 소스 불안정 | High | High | 그레이스풀 디그레이데이션 (nil 반환) |
| 프로세스 이름 불일치 | Medium | High | 설정 가능한 매칭 리스트 |
| macOS hover popover 비표준 | Medium | Medium | 클릭 기반 팝오버 폴백 |
| App Store 샌드박스 + IOPMAssertion | Medium | Medium | Homebrew Cask 기본 배포 |

## Generated Documents

- [x] `docs/prd_digest.md` -- PRD 요약
- [x] `docs/requirements.md` -- 18 FRs, 8 NFRs, 9 User Stories
- [x] `docs/ux_spec.md` -- 7 flows, 5 screens, copy guidelines, accessibility
- [x] `docs/architecture.md` -- MVVM, 5 modules, zero dependencies
- [x] `docs/data_model.md` -- In-memory entities, state machine, data flow
- [x] `docs/test_plan.md` -- Risk-based prioritization, 50+ test cases
- [x] `issues.md` -- 23 issues across 6 phases
