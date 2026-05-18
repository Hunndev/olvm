# OLVM Troubleshooter

Oracle Linux Virtualization Manager (OLVM) 운영 엔지니어를 위한 Claude Code 플러그인.

멀티사이트 회사 환경 관리, Claude 인터뷰 기반 사이트 등록, OLVM 도메인 지식 기반 트러블슈팅, 인쇄 가능한 현장 체크리스트를 제공합니다.

## 핵심 기능

- **사이트 등록 인터뷰**: Claude가 9단계 표준 점검 항목을 한 번에 하나씩 묻고, 모르는 답에는 확인 명령어를 안내하며 사이트 정보를 점진적으로 채웁니다.
- **인쇄 가능한 체크리스트**: HTML+CSS로 A4 인쇄 친화 양식 생성. 인터넷 안 되는 현장에 종이로 들고 갑니다.
- **OLVM 도메인 지식 기반 트러블슈팅**: 사용자의 가설(예: NUMA 의심)을 받아 OLVM 내부 구조 지식으로 체크 포인트를 자동 생성.
- **멀티사이트 격리 가드**: 같은 회사의 여러 지역 거점이 서로 영향 주지 않도록 작업 격리.
- **위험 명령어 분류**: 절대금지 / L3 협의 / 안전 3단계로 모든 조치를 분류.

## 인터페이스 (단순)

명령어 2개만 외우면 됩니다:

```
/olvm-survey {company} {site}
   - 사이트 정보 없으면 인터뷰 모드 (대화로 등록)
   - 인쇄 양식 발급 모드 (현장 가야 할 때)
   - 결과 입력 모드 (현장 다녀온 후, 자동 감지)
   - 정기 점검 모드

/olvm-troubleshoot {company} {site}
   - 증상 인터뷰 후 가설 기반 가이드 생성
   - 인쇄 양식 발급 또는 화면 가이드
   - 결과 입력 후 깊은 분석 (investigator 에이전트)
   - 고객 보고서 작성 (reporter 에이전트)
```

## 데이터/코드 격리

이 플러그인은 **코드만** 담고, 사이트 환경 데이터(IP, 호스트명, 토폴로지)는 **별도 위치**에 둡니다.

```
[플러그인 — 팀 공유, 코드 버전관리]    [사이트 데이터 — 별도 보안 저장소]
~/.claude/plugins/olvm-troubleshooter/  ~/.olvm/
├── commands/                           ├── sites/
├── agents/                             │   ├── company01/
├── skills/                             │   │   ├── _company.md
├── templates/                          │   │   ├── seoul-dc01.md
└── sites/_TEMPLATE/                    │   │   └── busan-dc01.md
   (템플릿만, 실데이터 X)                │   └── company02/...
                                        └── printouts/
                                            (생성된 인쇄 양식)
```

이유: 사이트 데이터는 민감 정보. 플러그인 git 저장소에 한 번 들어가면 사실상 영구 노출.

## 설치

### 1. 플러그인 자체

```bash
# 사내 git remote 사용 권장
git clone <사내 git>/olvm-troubleshooter ~/.claude/plugins/olvm-troubleshooter

# 또는 압축 파일 전달받았으면
tar xzf olvm-troubleshooter.tar.gz -C ~/.claude/plugins/
```

Claude Code 재시작 후 자동 인식. `/olvm-survey`, `/olvm-troubleshoot` 자동완성에서 보입니다.

### 2. 사이트 데이터 디렉토리 (사내 git 사용)

이 프로젝트는 **사내 private git remote 에 사이트 데이터 저장소를 별도 운영**하는 방식을 표준으로 합니다.

```bash
# 사내 git에 olvm-sites 저장소 미리 생성 (private)
# 예: https://git.internal/ops/olvm-sites.git

# 각 엔지니어 노트북:
git clone <사내 git>/olvm-sites ~/.olvm/sites
mkdir -p ~/.olvm/printouts ~/.olvm/reports

# 작업 시작 시 (사무실에서)
cd ~/.olvm/sites && git pull

# Claude 작업 진행
/olvm-survey company01 seoul-dc01

# 변경 후 (사무실 복귀 후 또는 작업 마무리 시)
cd ~/.olvm/sites
git add company01/
git commit -m "company01/seoul-dc01: 초기 등록 (방문: 2026-05-14)"
git push
```

#### 사이내 git remote 권장 설정

- **저장소 가시성**: private. 운영팀 외 접근 금지.
- **접근 권한**: 운영팀 멤버만 read/write.
- **branch 보호**: main 직접 push 가능 (소규모 팀 가정) 또는 PR 워크플로 (대규모).
- **.gitignore**: `printouts/`, `reports/` 추가 (생성물은 commit X)
- **사고 방지**: pre-commit hook 으로 평문 비밀번호 패턴 차단 권장

#### .gitignore 예시 (sites 저장소 안에)

```
# 생성물은 commit 안 함
printouts/
reports/

# 임시
*.swp
*.tmp
.DS_Store
```

#### 권장 commit 메시지 패턴

```
{company}/{site}: {작업 종류} ({날짜})

예시:
- company01/seoul-dc01: 초기 등록 (방문: 2026-05-14)
- company01/seoul-dc01: 호스트 host04 추가 (작업: 2026-05-20)
- company01/seoul-dc01: 장애 처리 INC-2026-0422-01 (해결: 2026-04-22)
- company02: 회사 정보 갱신 (계약 갱신: 2026-06-01)
```

## 시작 가이드

### 신규 사용자

1. **첫 회사 + 첫 사이트 등록**
   ```
   /olvm-survey company01 seoul-dc01
   ```
   사이트가 등록되지 않은 상태라 Claude가 인터뷰 모드로 진입.
   회사 공통 정보부터 9단계 사이트 정보까지 차례로 묻습니다.
   답을 모르겠으면 "모르겠어요" → Claude가 확인 명령어 안내.

2. **현장 가서 채울 거면**
   인터뷰 중 "현장 가서 채울게요" 답하면 인쇄 양식 발급.
   ```
   ~/.olvm/printouts/company01-seoul-dc01-check-20260514.html
   ```
   브라우저로 열려서 Ctrl/Cmd + P로 인쇄.

3. **현장 다녀온 후**
   ```
   /olvm-survey company01 seoul-dc01
   ```
   같은 명령어 호출 → 미입력 양식 감지 → 결과 입력 모드 자동 진입.

4. **사내 git에 push (작업 마무리)**
   ```bash
   cd ~/.olvm/sites
   git add company01/
   git commit -m "company01/seoul-dc01: 초기 등록 (방문: 2026-05-14)"
   git push
   ```

### 장애 발생 시

1. **고객 신고 받음**
   ```
   /olvm-troubleshoot company01 seoul-dc01
   ```
   Claude가 증상/시점/변경이력/영향범위/시도조치/의심가설 차례로 인터뷰.

2. **가설 기반 가이드 생성**
   "VM 마이그레이션 후 NUMA 의심" 같이 가설 말하면 Claude가 OLVM 내부 구조 지식으로 체크 포인트 자동 생성.

3. **현장 가는 경우 인쇄**
   가이드를 인쇄 양식 HTML로 저장. 들고 가서 명령 결과 손으로 적어 옴.

4. **돌아와서 결과 입력**
   같은 명령어 다시 호출 → 결과 입력 → investigator 에이전트가 깊은 분석 → 사이트 .md 자동 갱신.

5. **고객 보고서 필요하면**
   reporter 에이전트 호출 (Claude가 자동 권고).

6. **사내 git push** (작업 이력 동기화)
   ```bash
   cd ~/.olvm/sites
   git add company01/
   git commit -m "company01/seoul-dc01: NUMA 마이그레이션 이슈 처리 (해결: 2026-05-14)"
   git push
   ```

## 디렉토리 구조

```
~/.claude/plugins/olvm-troubleshooter/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── olvm-survey.md          # 사이트 점검 (등록/인쇄/입력/정기점검 통합)
│   └── olvm-troubleshoot.md    # 트러블슈팅 (인터뷰/가이드/분석)
├── agents/
│   ├── olvm-investigator.md    # 로그/명령어 결과 깊은 분석
│   └── olvm-reporter.md        # 고객 보고서 작성
├── skills/
│   ├── olvm-site-survey/       # 사이트 등록 인터뷰 가이드
│   │   ├── SKILL.md
│   │   ├── checklist.md        # 9단계 표준 점검 항목
│   │   ├── baseline.md         # 정상 베이스라인
│   │   └── confirm-commands.md # "모를 때" 확인 명령어
│   └── olvm-troubleshoot/      # 트러블슈팅 도메인 + 안전 가드
│       ├── SKILL.md
│       ├── architecture.md     # Engine/vdsm/libvirtd 전체 구조
│       ├── components.md       # NUMA/SPM/ha-agent/인증서
│       ├── networking.md       # 망 분리/본딩/방화벽
│       ├── storage.md          # NFS/iSCSI/FC/도메인/SPM
│       ├── logs.md             # 로그 파일 위치 인덱스
│       ├── common-issues.md    # 자주 발생 증상 패턴
│       ├── runbooks.md         # 시나리오별 처리 (호스트Non-Resp, SHE다운 등)
│       ├── dangerous-commands.md  # 위험 명령어 분류
│       └── multi-site-isolation.md  # 멀티사이트 격리 원칙
├── templates/
│   ├── check.html.tpl          # 사이트 점검 양식 (인쇄용)
│   ├── troubleshoot.html.tpl   # 트러블슈팅 가이드 양식 (인쇄용)
│   └── print.css               # 인쇄 친화 CSS (A4, 체크박스, 페이지나눔)
└── sites/_TEMPLATE/
    ├── _company.md             # 회사 템플릿
    └── site.md                 # 사이트 템플릿
```

사용자 데이터 (별도, 플러그인 외부, 사내 git):
```
~/.olvm/                       # = 사내 git 'olvm-sites' 의 clone
├── sites/{company}/_company.md
├── sites/{company}/{site}.md
├── printouts/                  # 생성된 인쇄 양식 (gitignore)
└── reports/                    # 고객 보고서 (gitignore)
```

## 안전 원칙

1. **비밀번호 금지**: 플러그인은 사이트 .md 에 비밀번호 절대 저장 안 함. 사용자가 입력해도 거부.
2. **Claude는 명령 직접 실행 X**: 항상 사용자가 호스트에서 실행하고 결과를 Claude에 전달.
3. **위험 명령어 분류**: 모든 조치 명령은 🟢/🟡/🔴 분류 후 안내.
4. **멀티사이트 격리**: 같은 회사 여러 사이트면 잘못된 사이트에 명령 안 가도록 가드.
5. **사이트 식별 prefix**: 모든 명령에 `[{site}/{host}]` 표기.
6. **git 권한 분리**: 사이트 데이터 저장소는 운영팀만 접근. 플러그인 저장소와 분리.

## 환경 변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `OLVM_DATA_DIR` | `~/.olvm` | 사이트 데이터 디렉토리 |

## 인쇄 출력 사용법

1. 명령어가 인쇄 모드로 동작하면 `~/.olvm/printouts/...html` 파일 생성
2. 자동으로 브라우저 열림 (`open` 명령)
3. 브라우저에서 Ctrl/Cmd + P (인쇄)
4. **"배경 그래픽" 옵션 체크 권장** (경고 박스 색상 보존)
5. PDF 저장 또는 직접 인쇄

브라우저가 자동 안 열리면 파일 더블클릭.

## 데이터 보안 권고

- 사이트 .md 파일을 공개 git 또는 잘못된 저장소에 push 금지 (가시성 private 확인)
- 사내 private git에서도 접근 권한 운영팀에만 부여
- 외부 USB 사용 시 작업 종료 후 데이터 삭제
- 고객사 정보가 노출되는 회사 정식 명칭은 이니셜/약칭 사용 검토
- `printouts/`, `reports/` 디렉토리는 git에 commit 안 함 (.gitignore)

## 트러블슈팅 (플러그인 자체)

### `/olvm-survey` 자동완성에 안 보임
- Claude Code 재시작
- `~/.claude/plugins/olvm-troubleshooter/.claude-plugin/plugin.json` 존재 확인
- `~/.claude/plugins/olvm-troubleshooter/commands/olvm-survey.md` 존재 확인

### 인쇄 양식이 빈 페이지로 나옴
- 브라우저에서 "배경 그래픽" 옵션 켜기
- print.css 가 인라인 임베드 되었는지 HTML 소스 확인

### 사이트 디렉토리 없다는 에러
- `mkdir -p ~/.olvm/sites ~/.olvm/printouts`
- 또는 `git clone <사내 git>/olvm-sites ~/.olvm/sites`
- 또는 `OLVM_DATA_DIR` 환경변수 다른 경로로 설정

### git pull 충돌
- 다른 엔지니어가 같은 사이트 .md 수정한 경우
- 작업 시작 시 항상 `git pull` 먼저
- 충돌 발생 시 수동 머지 (사이트 .md 의 어느 섹션을 살릴지 판단)

## 버전 관리

- 플러그인: `.claude-plugin/plugin.json` 의 `version` 필드 (semver)
- 사이트 템플릿: 각 .md 파일의 frontmatter `schema_version` 필드

major 변경 시 (호환 깨짐) 마이그레이션 안내 포함.

## 기여 / 의견

- 사내 git 이슈 트래커
- 새 runbook 추가는 `skills/olvm-troubleshoot/runbooks.md` 에 # 헤딩으로 섹션 추가
- 새 정상 베이스라인은 `skills/olvm-site-survey/baseline.md` 에 추가
- 새 확인 명령어는 `skills/olvm-site-survey/confirm-commands.md` 에 추가

## 라이선스

MIT
