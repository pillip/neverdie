# Neverdie

> macOS 메뉴바 앱 -- Claude Code가 잠들지 않게 지켜주는 좀비

## Prerequisites

- macOS 14.0 (Sonoma) 이상
- Xcode 15+ (빌드용)
- Apple Developer ID 인증서 (배포용, 선택)

## Setup

```bash
# 1. 저장소 클론
git clone https://github.com/<your-org>/neverdie.git
cd neverdie

# 2. Xcode 프로젝트 열기
open Neverdie.xcodeproj

# 3. 빌드 (Universal Binary)
xcodebuild build -scheme Neverdie -destination 'platform=macOS'

# 4. 실행
# Xcode에서 Run (Cmd+R) 또는 빌드된 .app 직접 실행
```

## Architecture

- **언어**: Swift 5.9+
- **UI**: SwiftUI (MenuBarExtra) + AppKit (NSStatusItem)
- **패턴**: MVVM (`@Observable` AppState)
- **외부 의존성**: 없음 (Apple 프레임워크만 사용)

### 모듈 구성

| 모듈 | 역할 |
|------|------|
| AppState | 중앙 상태 관리 (ViewModel) |
| SleepManager | IOPMAssertion 기반 sleep 방지 |
| ProcessMonitor | libproc 기반 Claude Code 프로세스 감지 |
| TokenMonitor | ~/.claude/ 로컬 파일 파싱 |
| AnimationManager | 프레임 기반 메뉴바 아이콘 애니메이션 |

## Test

```bash
# 단위 테스트 실행
xcodebuild test -scheme Neverdie -destination 'platform=macOS'
```

## Distribution

- **Homebrew Cask**: `brew install --cask neverdie`
- **App Store**: (심사 후 배포 예정)
- **직접 다운로드**: GitHub Releases에서 `.dmg` 다운로드

## Project Structure

```
neverdie/
  PRD.md                    # 제품 요구사항 정의서
  issues.md                 # 구현 이슈 목록
  STATUS.md                 # 프로젝트 현재 상태
  docs/
    requirements.md         # 상세 요구사항
    ux_spec.md              # UX 사양서
    architecture.md         # 아키텍처 설계
    data_model.md           # 데이터 모델
    test_plan.md            # 테스트 전략
    brainstorm_notes.md     # 브레인스톰 노트
    prd_digest.md           # PRD 요약
```
