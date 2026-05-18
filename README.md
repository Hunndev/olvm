# OLVM Marketplace

Oracle Linux Virtualization Manager (OLVM) 운영을 위한 Claude Code 플러그인 모음.

## 포함된 플러그인

| 플러그인 | 버전 | 설명 |
|---|---|---|
| [olvm-troubleshooter](./plugins/olvm-troubleshooter) | 0.1.0 | OLVM 사이트 등록 인터뷰, 멀티사이트 관리, 트러블슈팅 가이드, 인쇄 양식 |

## 설치

### 1단계: 마켓플레이스 등록

Claude Code 채팅에서:
```
/plugin marketplace add Hunndev/olvm
```

또는 `~/.claude/settings.json` 직접 편집:
```json
{
  "extraKnownMarketplaces": {
    "olvm": {
      "source": {
        "source": "github",
        "repo": "Hunndev/olvm"
      }
    }
  }
}
```

### 2단계: 플러그인 설치

Claude Code 채팅에서:
```
/plugin install olvm-troubleshooter@olvm
```

또는 `~/.claude/settings.json` 의 `enabledPlugins` 에 추가:
```json
{
  "enabledPlugins": {
    "olvm-troubleshooter@olvm": true
  }
}
```

### 3단계: Claude Code 재시작

재시작 후 `/olvm-survey`, `/olvm-troubleshoot` 명령어가 자동완성에 보입니다.

### 4단계: 사이트 데이터 디렉토리 준비

사이트 데이터는 플러그인과 분리된 곳(`~/.olvm/`)에 보관합니다.

```bash
# 사내 git remote 사용 권장
git clone <사내 git>/olvm-sites ~/.olvm/sites
mkdir -p ~/.olvm/printouts ~/.olvm/reports

# 사내 git remote 없으면 임시로
mkdir -p ~/.olvm/sites ~/.olvm/printouts ~/.olvm/reports
```

## 사용 시작

```
/olvm-survey 회사ID 사이트코드
```

자세한 사용법은 [olvm-troubleshooter README](./plugins/olvm-troubleshooter/README.md) 참조.

## 업데이트

```
/plugin update olvm-troubleshooter@olvm
```

또는 직접:
```bash
# Claude Code 가 마켓플레이스에서 자동으로 최신 가져옴
```

## 디렉토리 구조

```
olvm/                                       # 이 git 저장소 (마켓플레이스)
├── .claude-plugin/
│   └── marketplace.json                    # 마켓플레이스 메타
├── README.md                                # 이 파일
└── plugins/
    └── olvm-troubleshooter/                 # 플러그인 1개 (앞으로 더 추가 가능)
        ├── .claude-plugin/plugin.json
        ├── README.md
        ├── commands/
        ├── agents/
        ├── skills/
        ├── templates/
        └── sites/_TEMPLATE/
```

## 기여 / 의견

이 저장소에 이슈 등록 또는 PR.

## 라이선스

MIT
