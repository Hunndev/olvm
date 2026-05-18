---
name: olvm-troubleshoot
description: OLVM 트러블슈팅 도메인 지식과 안전 가드. Engine/vdsm/libvirtd/SHE 아키텍처, NUMA/SPM/스토리지/네트워크 컴포넌트 내부 동작, 로그 위치, 자주 발생 이슈 패턴, 시나리오 runbook, 위험 명령어 분류, 멀티사이트 격리 원칙을 다룬다. /olvm-troubleshoot 명령어가 호출되며, 사용자 가설 검증과 깊은 진단 시 사용.
---

# OLVM 트러블슈팅 스킬

## 호출 타이밍 (Claude 자기 룰)

1. `/olvm-troubleshoot` 명령어 호출 시
2. `/olvm-survey` 진행 중 사용자가 명시적으로 위험 명령(restart/fence/destroy 결과) 보고 시 → 자동 전환 권고
3. 사이트 식별 직후 → multi-site-isolation.md 원칙 적용
4. 모든 조치 명령 안내 직전 → dangerous-commands.md 분류 확인
5. 사용자가 명령 결과 붙여넣을 때 → 호스트명/IP가 현재 사이트와 일치하는지 검증

## 인덱스 — 어떤 상황에 어느 파일

| 필요한 내용 | 파일 |
|---|---|
| Engine/vdsm/libvirtd/SHE 전체 구조, 데이터 흐름 | architecture.md |
| NUMA, SPM, ha-agent/broker, 인증서 동작 원리 | components.md |
| 망 분리, 본딩, 방화벽 | networking.md |
| NFS/iSCSI/FC, 도메인, SPM 동작 | storage.md |
| 로그 파일 위치 (어디서 무엇 보나) | logs.md |
| 자주 발생 증상 패턴과 의심 영역 | common-issues.md |
| 시나리오별 단계별 처리 (호스트 Non-Responsive 등) | runbooks.md |
| 위험 명령어 분류 | dangerous-commands.md |
| 멀티사이트 격리 원칙 | multi-site-isolation.md |

## 핵심 안전 룰

### 룰 1: 명령어 안내에 사이트/호스트 prefix
모든 조치 명령은 `[{사이트코드}/{호스트명}]` prefix 명시.
```
❌ "systemctl restart vdsmd 실행해주세요"
✅ "[seoul-dc01/host03] systemctl restart vdsmd 실행해주세요"
```

### 룰 2: 위험도 표시
조치 명령은 항상 위험도 prefix:
- 🟢 안전 — read-only, 진단용
- 🟡 L3 협의 — 서비스 영향 가능
- 🔴 절대 금지 — 데이터 손실 또는 복구 불가 위험

상세는 dangerous-commands.md.

### 룰 3: 멀티사이트 격리
같은 회사 여러 사이트가 있는 경우 multi-site-isolation.md 의 가드 룰 항상 적용.

### 룰 4: 사용자 가설 존중하되 검증
사용자가 의심하는 영역이 있으면 그 가설을 먼저 가지고, OLVM 내부 구조 지식으로:
- 가설이 맞다면 어떤 증거가 나와야 하는지
- 가설이 틀리다면 어디를 더 봐야 하는지
- 가설과 무관하게 추가로 의심해야 할 영역

가설을 부정하지 말고, 검증 가능한 체크 포인트로 구체화.

### 룰 5: 추측 금지
사용자가 명령어 결과나 로그를 제공하기 전에는 단정하지 말 것. "이렇게 보입니다" "이럴 가능성이 있습니다" 표현. 결과 받기 전 임시 조치 안내 금지.

### 룰 6: 본인 명령 실행 안 함
Claude는 호스트에 직접 SSH/명령 실행하지 않음. 사용자가 직접 실행하고 결과를 가져옴.
사용자 환경에서는 인터넷 안 되는 사이트가 많아 결과는 사진/메모/파일로 가져올 수 있음.

## 트러블슈팅 진행 흐름

1. **사이트 컨텍스트 로드**: 회사/사이트 .md 읽어 환경 파악
2. **증상 인터뷰**: 사용자에게 증상, 시점, 변경 이력, 영향 범위, 의심 가설 묻기
3. **카테고리 분류**: common-issues.md 의 패턴과 매칭
4. **가설 검증 가이드 생성**:
   - 사용자 가설이 있으면 그 가설을 첫 번째로 검증
   - components.md / networking.md / storage.md 등의 도메인 지식 활용
   - 1차 진단 명령어 + 결과 기록란
   - 안전/위험 조치 분리
5. **인쇄 가이드 생성 (요청 시)**: troubleshoot.html.tpl 자리표시자 치환 후 ~/.olvm/printouts/ 저장
6. **결과 입력 시 깊은 분석**: olvm-investigator 에이전트 호출, 시간순 이벤트 재구성, 근본 원인 추적
7. **사이트 .md 업데이트**: 알려진 이슈, 작업 이력, offline_visits 갱신
8. **고객 보고 필요 시**: olvm-reporter 에이전트 호출

## 양방향 동작

`/olvm-troubleshoot` 도 `/olvm-survey` 처럼 자동 모드 판단:
- 신규 호출 → 증상 인터뷰 + 가이드 생성 (인쇄 또는 화면)
- 미입력 양식 있음 → 결과 입력 모드
- `--input` 옵션 → 강제 입력 모드
- `--print` 옵션 → 강제 인쇄 모드

## 출력 형식

- 항상 한국어. 명령어와 기술 용어는 원형.
- 가설 검증 가이드는 다음 구조:
  1. 배경 — Claude 분석 요약
  2. 1차 확인 — 안전 명령어 + 결과 기록란
  3. 가설별 분기 — A/B/C 가설마다 체크 포인트
  4. 추가 확인 — 사용자가 놓칠 수 있는 영역
  5. 조치 — 위험도별 분류
  6. 복귀 후 — 입력 안내
