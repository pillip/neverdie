# PRD: Neverdie

> macOS 메뉴바 앱 — Claude Code가 잠들지 않게 지켜주는 좀비

---

## Background

macOS 노트북은 사용자 입력이 일정 시간 없으면 자동으로 sleep 모드에 진입한다. Claude Code CLI로 장시간 자율 작업(빌드, 테스트, 대규모 리팩토링 등)을 실행할 때 시스템이 잠들면 작업이 중단되어 시간과 토큰이 낭비된다.

기존 솔루션(`caffeinate` CLI, Amphetamine, KeepingYouAwake)은 범용 sleep 방지 도구로, Claude Code 프로세스를 인식하지 못하고 수동 관리가 필요하다. Neverdie는 Claude Code에 특화된 sleep 방지 + 모니터링 앱으로 이 문제를 해결한다.

---

## Goals

1. Claude Code 실행 중 시스템 sleep으로 인한 작업 중단을 **완전히 방지**한다.
2. Claude Code 프로세스 감지를 통해 **수동 개입 없이** 자동으로 sleep 방지를 관리한다.
3. 메뉴바에서 Claude Code **토큰 사용량과 프로세스 상태**를 한눈에 확인할 수 있게 한다.
4. 재미있는 좀비 캐릭터 애니메이션으로 **앱 상태를 직관적으로** 전달한다.

---

## Target User

- **macOS 개발자** (macOS 14 Sonoma 이상)
- Claude Code CLI를 일상적으로 사용하는 사람
- 장시간 에이전트 작업을 맡겨놓고 다른 일(회의, 외출, 휴식)을 하는 사용자

---

## User Stories

### 핵심

1. **As a** Claude Code 사용자, **I want** 메뉴바 아이콘 클릭으로 sleep 방지를 토글할 수 있게 **so that** 장시간 작업 시 수동으로 시스템 설정을 변경하지 않아도 된다.

2. **As a** Claude Code 사용자, **I want** Neverdie 모드가 켜져 있을 때 디스플레이는 꺼지되 시스템은 깨어있게 **so that** 배터리는 절약하면서 작업은 계속된다.

3. **As a** Claude Code 사용자, **I want** 메뉴바 아이콘이 ON/OFF 상태에 따라 다른 애니메이션을 보여주게 **so that** 현재 상태를 한눈에 파악할 수 있다.

### 자동화

4. **As a** Claude Code 사용자, **I want** 모든 Claude Code 프로세스가 종료되면 Neverdie 모드가 자동으로 꺼지게 **so that** 불필요하게 sleep이 방지되는 것을 막을 수 있다.

5. **As a** Claude Code 사용자, **I want** 메뉴바 아이콘에 hover하면 실행 중인 Claude Code 프로세스 수를 볼 수 있게 **so that** 현재 몇 개의 세션이 돌고 있는지 알 수 있다.

### 모니터링

6. **As a** Claude Code 사용자, **I want** 메뉴바 아이콘에 hover하면 토큰 사용량(Context, Input, Output)을 막대그래프와 수치로 볼 수 있게 **so that** CLI로 전환하지 않고도 사용량을 확인할 수 있다.

---

## Functional Requirements

### FR-1: 메뉴바 앱

| ID | 요구사항 | 우선순위 |
|----|----------|----------|
| FR-1.1 | 앱 실행 시 macOS 메뉴바에 아이콘을 표시한다 (Dock 아이콘 없음, `LSUIElement = true`) | P0 |
| FR-1.2 | 메뉴바 아이콘 클릭 시 Neverdie 모드를 토글한다 (ON ↔ OFF) | P0 |
| FR-1.3 | 메뉴바 드롭다운 메뉴에 "Quit Neverdie" 옵션을 제공한다 | P0 |
| FR-1.4 | Login Items에 등록하여 macOS 시작 시 자동 실행을 지원한다 | P1 |

### FR-2: Sleep 방지

| ID | 요구사항 | 우선순위 |
|----|----------|----------|
| FR-2.1 | Neverdie 모드 ON 시 `IOPMAssertion` API로 시스템 sleep을 방지한다 (`kIOPMAssertionTypePreventUserIdleSystemSleep`) | P0 |
| FR-2.2 | 디스플레이 sleep은 허용한다 (화면은 꺼져도 됨) | P0 |
| FR-2.3 | Neverdie 모드 OFF 시 assertion을 해제하여 정상 sleep 동작을 복원한다 | P0 |
| FR-2.4 | 앱 종료 시에도 assertion을 정리(cleanup)한다 | P0 |

### FR-3: 애니메이션 아이콘

| ID | 요구사항 | 우선순위 |
|----|----------|----------|
| FR-3.1 | OFF 상태: 정적 좀비 아이콘 (잠든/평화로운 좀비) | P0 |
| FR-3.2 | ON 상태: 총알을 맞고 있는 좀비 프레임 애니메이션 (순환) | P0 |
| FR-3.3 | 메뉴바 크기(약 18x18pt)에 맞는 심플한 라인아트/픽셀아트 스타일 | P0 |
| FR-3.4 | 라이트/다크 모드 모두에서 잘 보이는 아이콘 | P1 |

### FR-4: Claude Code 프로세스 감지

| ID | 요구사항 | 우선순위 |
|----|----------|----------|
| FR-4.1 | `claude` 프로세스 존재 여부를 주기적으로 폴링한다 (기본 30초) | P0 |
| FR-4.2 | Neverdie 모드가 ON인 상태에서 모든 Claude Code 프로세스가 종료되면 자동으로 OFF 전환 | P0 |
| FR-4.3 | 메뉴바 아이콘 hover 시 popover에 현재 Claude Code 프로세스 수를 표시한다 | P1 |

### FR-5: 토큰 사용량 모니터링

| ID | 요구사항 | 우선순위 |
|----|----------|----------|
| FR-5.1 | Claude Code의 토큰 사용량 데이터(Context, Input, Output)를 수집한다 | P1 |
| FR-5.2 | 메뉴바 아이콘 hover 시 popover에 3개 막대그래프 + 수치를 표시한다 | P1 |
| FR-5.3 | 여러 Claude Code 세션이 있으면 각각의 사용량을 구분하여 표시한다 | P2 |

---

## Non-functional Requirements

| ID | 요구사항 |
|----|----------|
| NFR-1 | **플랫폼**: macOS 14 (Sonoma) 이상 |
| NFR-2 | **아키텍처**: Apple Silicon (arm64) + Intel (x86_64) Universal Binary |
| NFR-3 | **메모리**: 유휴 시 50MB 이하 |
| NFR-4 | **CPU**: 프로세스 폴링 시에도 CPU 사용률 1% 미만 |
| NFR-5 | **배터리**: sleep 방지 외에 추가적인 배터리 소모를 최소화 |
| NFR-6 | **코드 서명**: Apple Developer ID로 서명 (App Store + Homebrew 배포 모두 필요) |
| NFR-7 | **접근성**: VoiceOver에서 현재 상태(ON/OFF)를 읽을 수 있어야 함 |

---

## Out of Scope

- **Clamshell mode (덮개 닫힌 상태) 지원** — 외부 전원 없이는 OS 레벨에서 불가
- **Windows / Linux 지원** — macOS 네이티브 전용
- **Claude Code 외 프로세스 감지** — 범용 sleep 방지 도구가 아님
- **Anthropic API 직접 호출** — 토큰 사용량은 로컬 데이터 기반으로 수집
- **알림/사운드** — 메뉴바 아이콘 상태 변화로만 전달

---

## Success Metrics

| 지표 | 목표 |
|------|------|
| Sleep으로 인한 Claude Code 작업 중단 | 0건 (Neverdie ON 상태에서) |
| 앱 메모리 사용량 | 유휴 시 50MB 이하 |
| 프로세스 감지 → 자동 OFF 전환 지연 | 폴링 주기(30초) 이내 |
| Homebrew Cask 설치 성공률 | 99% 이상 |
| App Store 심사 통과 | 1차 제출로 통과 |

---

## Technical Notes

### 기술 스택
- **언어**: Swift
- **UI**: SwiftUI (메뉴바 popover)
- **최소 타겟**: macOS 14.0
- **빌드**: Xcode + Swift Package Manager

### Sleep 방지 구현
- `IOPMAssertionCreateWithName` / `IOPMAssertionRelease` 사용
- Assertion 타입: `kIOPMAssertionTypePreventUserIdleSystemSleep`
- 디스플레이 assertion은 생성하지 않음 (화면 꺼짐 허용)

### 프로세스 감지
- `Process` / `NSRunningApplication` 또는 `proc_listpids()` 로 `claude` 프로세스 탐색
- Timer 기반 주기적 폴링 (30초 간격)

### 토큰 사용량 데이터 접근
- **1차 접근**: Claude Code 로컬 상태 파일/DB 파싱 (`~/.claude/` 디렉토리 조사)
- **2차 접근**: `claude` CLI 명령 실행 후 출력 파싱
- 데이터 접근 방법은 구현 단계에서 기술 조사(spike) 필요

### 애니메이션 아이콘
- 프레임 기반 `NSImage` 배열로 구현
- `Timer`로 프레임 전환 (약 4-8fps)
- 에셋: 18x18pt @1x, 36x36pt @2x (Retina)
- 라이트/다크 모드 대응: `template` 렌더링 모드 또는 별도 에셋

### 배포
- **Homebrew Cask**: GitHub Releases에 `.dmg` 업로드 → Cask formula 등록
- **App Store**: Xcode Archive → App Store Connect 제출
- App Sandbox 규칙 준수 필요 (App Store 배포 시)

---

## Milestones

### Phase 1: MVP (Core)
- 메뉴바 앱 기본 구조 (FR-1)
- Sleep 방지 토글 (FR-2)
- 정적 아이콘 (ON/OFF 구분)

### Phase 2: Personality
- 좀비 애니메이션 아이콘 (FR-3)
- 라이트/다크 모드 대응

### Phase 3: Intelligence
- Claude Code 프로세스 감지 & 자동 OFF (FR-4)
- Hover popover에 프로세스 수 표시

### Phase 4: Monitoring
- 토큰 사용량 데이터 수집 (기술 조사)
- Hover popover에 막대그래프 + 수치 (FR-5)

### Phase 5: Distribution
- Homebrew Cask 배포
- App Store 제출
- Login Items 자동 실행 지원
