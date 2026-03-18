# Neverdie

> macOS 메뉴바 앱 -- 총맞아도 안 죽는 좀비가 맥북 sleep을 막아줍니다.

Neverdie는 macOS 시스템 sleep을 방지하는 가벼운 메뉴바 유틸리티입니다. Claude Code 같은 AI 코딩 도구가 장시간 작업 중일 때 노트북이 잠들어 작업이 중단되는 문제를 해결합니다.

## Features

- **Sleep 방지** -- IOPMAssertion API로 시스템 sleep을 차단 (디스플레이는 꺼짐)
- **원클릭 토글** -- 메뉴바 아이콘 클릭으로 ON/OFF
- **Launch at Login** -- 로그인 시 자동 실행
- **좀비 애니메이션** -- ON: 총알 맞아도 살아나는 좀비 / OFF: 잠자는 좀비 (Zzz)

## Install

### Homebrew
```bash
brew tap pillip/neverdie
brew install --cask neverdie
```

### 직접 빌드
```bash
git clone https://github.com/pillip/neverdie.git
cd neverdie
open Neverdie/Neverdie.xcodeproj
# Xcode에서 Cmd+R로 실행
```

## Requirements

- macOS 14.0 (Sonoma) 이상
- Xcode 15+ (빌드 시)

## How It Works

1. 메뉴바에 좀비 아이콘이 나타남
2. 클릭하면 팝오버: ON/OFF 토글, Launch at Login, Quit
3. ON 상태에서는 `IOPMAssertionCreateWithName`으로 시스템 sleep 차단
4. 디스플레이는 꺼지지만 CPU는 계속 동작

> **참고**: 노트북 뚜껑을 닫으면 하드웨어 레벨에서 sleep이 강제되므로 소프트웨어로 막을 수 없습니다. 뚜껑은 열어두세요.

## Architecture

| 모듈 | 역할 |
|------|------|
| AppState | 중앙 상태 관리 (`@Observable`) |
| SleepManager | IOPMAssertion 기반 sleep 방지 |
| AnimationManager | 프레임 기반 메뉴바 아이콘 애니메이션 |
| StatusBarController | NSStatusItem + NSPopover 관리 |
| ControlPopoverView | SwiftUI 팝오버 UI |

- **언어**: Swift 5.9+
- **UI**: SwiftUI + AppKit
- **외부 의존성**: 없음

## License

MIT
