# Business Analysis: Neverdie

> Created: 2026-03-18

---

## Executive Summary

Claude Code 사용자를 위한 macOS sleep 방지 무료 오픈소스 유틸리티. **Go — 오픈소스 프로젝트로서 진행.**

---

## Market Analysis

### AI 코딩 도구 시장
- 시장 규모: USD 4.7B (2025) → USD 14.6B (2033), CAGR 15.3%
- 개발자 84%가 AI 도구 사용 중 또는 도입 예정
- 전체 코드의 41%가 AI 도구로 작성/보조 (2025)

### Claude Code 사용자 기반
- 115,000+ 개발자 (2025년 7월)
- Fortune 100 기업의 70%가 Claude 사용
- GitHub Copilot, Cursor를 제치고 AI 코딩 도구 1위
- Anthropic 매출 런레이트 $2.5B (2026 초)

### TAM / SAM / SOM
| 구분 | 규모 | 정의 |
|------|------|------|
| TAM | 432K+ | macOS sleep 방지 앱 사용자 (Amphetamine 다운로드 기준) |
| SAM | ~50K | macOS에서 Claude Code CLI를 사용하는 개발자 (추정) |
| SOM | ~5K | 초기 채택 가능 사용자 (Homebrew Cask + GitHub 유입) |

> SAM/SOM은 공개 데이터 부재로 러프 추정치.

---

## Competitive Landscape

| 앱 | 가격 | 프로세스 감지 | 자동 ON/OFF | Claude 특화 | UX 차별점 | GitHub Stars |
|---|---|---|---|---|---|---|
| **Neverdie** | 무료 | O | O | O | 좀비 애니메이션 | 신규 |
| Amphetamine | 무료 | X (트리거 기반) | 부분적 | X | 범용 | N/A |
| KeepingYouAwake | 무료 | X | X | X | 심플 | 6,000+ |
| Caffeine | 무료 | X | X | X | 최소 | 유지보수 중단 |
| `caffeinate` CLI | 내장 | X | X | X | 없음 | N/A |

### Neverdie 차별화 포인트
1. **Claude Code 프로세스 자동 감지** — 유일한 AI 코딩 도구 연동 sleep 방지 앱
2. **자동 OFF** — 모든 Claude Code 세션 종료 시 자동 해제
3. **캐릭터 UX** — 총맞아도 안 죽는 좀비 애니메이션 (기능적 피드백 + 재미)

---

## Business Model

### 포지셔닝: 무료 오픈소스 유틸리티

| 모델 | 채택 | 비고 |
|------|------|------|
| **무료 오픈소스 (MIT)** | **채택** | 경쟁 앱 모두 무료, 진입 장벽 제거 |
| App Store 유료 | 미채택 | 기능 단순, 유료화 정당성 부족 |
| Freemium | 미채택 | 프리미엄 기능 차별화 어려움 |
| 후원 (GitHub Sponsors) | 선택적 | 커뮤니티 성장 후 고려 가능 |

### 프로젝트 가치 (비금전적)
- **개발자 포트폴리오**: Swift/SwiftUI macOS 네이티브 앱 역량 증명
- **커뮤니티 기여**: Claude Code 생태계 최초 보조 도구
- **Dogfooding**: 실제 문제를 해결하는 도구
- **기술 학습**: IOKit, proc_pidpath, NSStatusItem 등 macOS 시스템 API 실전 경험

---

## Risks & Mitigations

| 리스크 | 심각도 | 확률 | 완화 전략 |
|--------|--------|------|-----------|
| Anthropic이 Claude Code에 sleep 방지 내장 | 높음 | 중간 | 범용 AI 에이전트 도구로 확장 (Cursor, Copilot 등) |
| macOS API 변경 (IOPMAssertion 등) | 중간 | 낮음 | Apple 공식 API 사용, WWDC 변경사항 추적 |
| `caffeinate` 한 줄로 충분하다는 인식 | 중간 | 높음 | 자동 감지/해제 + 캐릭터 UX로 차별화 강조 |
| 경쟁 앱이 Claude 연동 추가 | 낮음 | 낮음 | Amphetamine은 범용 유지 경향, 니치 선점 |
| 뚜껑 닫으면 소프트웨어로 sleep 방지 불가 | 낮음 | 확정 | README에 제한사항 명시, 외부 모니터 사용 안내 |

---

## Sources
- [Claude Code reaches 115,000 developers](https://ppc.land/claude-code-reaches-115-000-developers-processes-195-million-lines-weekly/)
- [Claude AI Statistics 2026](https://www.getpanto.ai/blog/claude-ai-statistics)
- [AI Code Assistant Market — SNS Insider](https://www.snsinsider.com/reports/ai-code-assistant-market-9087)
- [Amphetamine — App Store](https://apps.apple.com/us/app/amphetamine/id937984704?mt=12)
- [KeepingYouAwake — GitHub](https://github.com/newmarcel/KeepingYouAwake)
- [Amphetamine Alternatives — AlternativeTo](https://alternativeto.net/software/amphetamine/)
