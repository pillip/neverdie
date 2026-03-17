# PRD Digest: Neverdie

## Goals
1. Claude Code 실행 중 시스템 sleep으로 인한 작업 중단을 완전히 방지
2. 프로세스 감지 기반 자동 sleep 방지 관리 + 메뉴바에서 토큰 사용량/프로세스 상태 모니터링
3. 좀비 캐릭터 애니메이션으로 앱 상태를 직관적으로 전달

## Target User
macOS 14+ 개발자로 Claude Code CLI를 사용하며, 장시간 에이전트 작업을 맡겨놓는 사용자

## Must-have Features
1. 메뉴바 상주 앱 (Dock 아이콘 없음, 클릭으로 Neverdie 모드 토글)
2. IOPMAssertion 기반 시스템 sleep 방지 (디스플레이 sleep은 허용)
3. 좀비 애니메이션 아이콘 (OFF: 잠든 좀비, ON: 총알 맞는 좀비)
4. Claude Code 프로세스 감지 & 전부 종료 시 자동 OFF (30초 폴링)
5. Hover popover에 토큰 사용량(Context/Input/Output) 막대그래프 + 프로세스 수

## Key NFRs
1. macOS 14 Sonoma 이상, Universal Binary (arm64 + x86_64)
2. 메모리 50MB 이하, CPU 1% 미만
3. Apple Developer ID 코드 서명 (App Store + Homebrew Cask 배포)
4. VoiceOver 접근성 지원

## Scope Boundaries
- **In**: 메뉴바 토글, sleep 방지, 좀비 애니메이션, Claude Code 프로세스 감지, 토큰 usage 모니터링, Homebrew Cask + App Store 배포
- **Out**: Clamshell mode, Windows/Linux, 범용 프로세스 감지, Anthropic API 직접 호출, 알림/사운드
