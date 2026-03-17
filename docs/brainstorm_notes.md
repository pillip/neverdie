# Brainstorm Notes: Neverdie

> Created: 2026-03-18

---

## Problem Space

### 핵심 문제
- macOS 노트북에서 사용자 입력이 없으면 시스템이 sleep 모드로 진입
- Claude Code가 장시간 자율적으로 작업 중일 때 sleep으로 인해 동작이 중단됨
- 특히 빌드, 테스트, 대규모 리팩토링 등 오래 걸리는 작업에서 치명적

### 대상 사용자
- Claude Code CLI를 사용하는 macOS 개발자
- 장시간 에이전트 작업을 맡겨놓고 다른 일을 하는 사용자

### 제약 조건
- 덮개(lid)는 열어둔 상태 전제 (clamshell mode 미지원)
- 디스플레이는 꺼져도 됨, 시스템 sleep만 방지
- macOS 네이티브 앱 (Swift + SwiftUI)

---

## Existing Landscape

### 기존 솔루션
| 도구 | 방식 | 한계 |
|------|------|------|
| `caffeinate` CLI | 터미널 명령 | GUI 없음, 수동 관리, 상태 확인 불편 |
| Amphetamine (App Store) | 메뉴바 앱 | 범용 도구, Claude Code 연동 없음 |
| KeepingYouAwake | 오픈소스 메뉴바 앱 | 단순 토글, 프로세스 감지 없음 |

### Neverdie 차별점
- **Claude Code 특화**: 프로세스 감지로 자동 ON/OFF
- **토큰 사용량 모니터링**: hover 시 usage 정보 확인
- **재미있는 UX**: 좀비 캐릭터 애니메이션 아이콘

---

## Idea Candidates

### 핵심 기능 (MVP)

1. **메뉴바 상주 앱**
   - macOS 메뉴바에 아이콘 표시
   - 클릭으로 Neverdie 모드 토글 (ON/OFF)

2. **Sleep 방지 메커니즘**
   - `IOPMAssertion` API 사용 (또는 내부적으로 `caffeinate` 활용)
   - 디스플레이는 꺼지되 시스템 sleep은 방지
   - `kIOPMAssertionTypePreventUserIdleSystemSleep` assertion 타입 활용

3. **애니메이션 메뉴바 아이콘**
   - **OFF 상태**: 정적 좀비 아이콘 (평화로운/잠든 상태)
   - **ON 상태**: 총알을 맞고 있는 좀비 애니메이션 (프레임 순환)
     - SF Symbols 커스텀 또는 프레임별 이미지 에셋으로 구현
     - 메뉴바 아이콘 크기(약 18x18pt)에 맞는 심플한 픽셀/라인아트 스타일

### 확장 기능

4. **Claude Code 프로세스 감지 & 자동 제어**
   - `claude` 프로세스 존재 여부를 주기적으로 체크
   - 모든 Claude Code 프로세스가 종료되면 자동으로 Neverdie 모드 OFF
   - hover 시 현재 실행 중인 Claude Code 프로세스 수 표시

5. **토큰 사용량 표시 (hover popover)**
   - Claude Code의 usage 정보 (Context / Input / Output 토큰) 읽기
   - 메뉴바 아이콘 hover 시 팝오버로 3개 막대그래프 + 수치 표시
   - Claude Code CLI 내부 데이터 접근 방법 조사 필요
     - 옵션 A: Claude Code의 로컬 상태 파일/DB 파싱
     - 옵션 B: `claude` CLI 명령 실행하여 usage 출력 파싱
     - 옵션 C: Anthropic API 직접 호출 (API key 필요)

---

## Decisions

| 항목 | 결정 | 비고 |
|------|------|------|
| 언어/프레임워크 | Swift + SwiftUI | macOS 네이티브 |
| 앱 유형 | 메뉴바 전용 (Dock 아이콘 없음) | `LSUIElement = true` |
| Sleep 방지 | IOPMAssertion API | 디스플레이 sleep은 허용 |
| 아이콘 스타일 | 좀비 캐릭터 (ON: 총알 맞는 애니메이션) | 프레임 기반 애니메이션 |
| 자동 OFF | Claude Code 프로세스 전부 종료 시 | 주기적 폴링 |
| 모니터링 | hover popover에 토큰 usage + 프로세스 수 | 데이터 소스 조사 필요 |

---

## Open Questions

- [ ] Claude Code의 토큰 사용량 데이터를 외부에서 읽을 수 있는 방법 확인 필요
- [ ] 애니메이션 프레임 에셋 제작 방식 (직접 그리기 vs AI 생성 vs 픽셀아트 도구)
- [ ] 배포 방식: App Store vs 직접 배포 (`.dmg` / Homebrew Cask)
- [ ] 프로세스 감지 주기 (예: 30초? 1분?)

---

## Next Steps

1. `/bizanalysis` — 사업적 타당성 분석 (오픈소스 프로젝트로서의 가치 등)
2. `/prd` — PRD 작성 (이 노트를 기반으로 상세 요구사항 정의)
