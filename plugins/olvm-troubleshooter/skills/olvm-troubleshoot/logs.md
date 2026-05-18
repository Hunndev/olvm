# OLVM 로그 파일 위치 인덱스

문제별로 어느 로그를 봐야 하는지 빠른 참조.

## Engine 측 로그

### 위치: `/var/log/ovirt-engine/`

| 파일 | 내용 | 언제 보나 |
|---|---|---|
| `engine.log` | Engine 메인 로그 (이벤트, 명령, 오류) | 대부분의 문제 |
| `server.log` | JBoss/WildFly 자체 로그 | Engine 서비스 시작 실패 |
| `engine-setup-*.log` | setup/upgrade 로그 | 업그레이드 후 문제 |
| `console.log` | 콘솔(JBoss) 출력 | 시작 시 표준 출력 |
| `notifier/notifier.log` | 알림 발송 로그 | 알림 안 옴 |
| `host-deploy/` 디렉토리 | 호스트 추가 시 로그 | 호스트 등록 실패 |
| `dwh/dwh.log` | Data Warehouse | DWH 동작 문제 |

### Engine DB
- `/var/lib/pgsql/data/log/` — PostgreSQL 로그
- DB 자체 문제 (락, 연결 등)

### 시스템 레벨 (Engine 서버)
```bash
journalctl -u ovirt-engine --since "1 hour ago"
journalctl -u postgresql --since "1 hour ago"
```

## 호스트 측 로그

### 위치: `/var/log/vdsm/`

| 파일 | 내용 |
|---|---|
| `vdsm.log` | vdsm 메인 로그 (Engine 명령 수신, libvirt 호출) |
| `supervdsm.log` | 권한 필요한 작업 (네트워크, 스토리지) |
| `mom.log` | Memory Overcommit Manager |
| `import/` | VM 임포트 작업 |

### 위치: `/var/log/libvirt/`

| 파일 | 내용 |
|---|---|
| `libvirtd.log` | libvirtd 메인 |
| `qemu/<vm-name>.log` | 각 VM의 QEMU 로그 (paused, EIO 등) |
| `virtlogd.log` | virtlogd 동작 |

### SHE 호스트 추가 위치

| 파일 | 내용 |
|---|---|
| `/var/log/ovirt-hosted-engine-ha/agent.log` | ha-agent (HA 결정) |
| `/var/log/ovirt-hosted-engine-ha/broker.log` | ha-broker (호스트 간 통신) |
| `/var/log/sanlock.log` | sanlock (lease 동작) |
| `/var/log/ovirt-hosted-engine-setup/` | SHE 배포 시 |

### 시스템 레벨 (호스트)
```bash
journalctl -u vdsmd --since "1 hour ago"
journalctl -u libvirtd --since "1 hour ago"
journalctl -u ovirt-ha-agent --since "1 hour ago"
journalctl --since "1 hour ago" -p err   # 에러만
dmesg -T | tail -100   # 커널 (하드웨어 이슈)
```

## 증상별 로그 매핑

### 웹 콘솔 접속 불가
```
1순위:
  - /var/log/ovirt-engine/server.log (서비스 시작 문제)
  - journalctl -u ovirt-engine
2순위:
  - /var/log/ovirt-engine/engine.log (실행 중 에러)
  - /var/log/httpd/* (Apache 측, 4.4+ 는 보통 없음)
```

### 호스트 Non-Responsive
```
1순위:
  - 호스트의 journalctl -u vdsmd
  - 호스트의 /var/log/vdsm/vdsm.log
2순위:
  - Engine의 /var/log/ovirt-engine/engine.log (호스트 통신 시도)
  - dmesg (호스트 OS 자체 문제)
  - 인증서 만료 여부 (/etc/pki/vdsm/certs/)
```

### VM 안 켜짐
```
1순위:
  - /var/log/libvirt/qemu/<vm-name>.log
  - /var/log/vdsm/vdsm.log (VM 생성 시도)
2순위:
  - Engine engine.log (스케줄러 결정)
  - 스토리지 도메인 상태 (vdsm-tool list-domains)
```

### VM Paused
```
1순위:
  - /var/log/libvirt/qemu/<vm-name>.log (Pause 사유)
  - virsh domstate <vm> --reason
2순위:
  - /var/log/vdsm/vdsm.log (IO error 처리)
  - 스토리지 측 로그
  - dmesg (HBA 또는 NFS 측 메시지)
```

### 마이그레이션 실패
```
1순위:
  - /var/log/vdsm/vdsm.log (양 호스트 모두)
  - /var/log/libvirt/qemu/<vm-name>.log
2순위:
  - Engine engine.log (마이그레이션 시도)
  - 네트워크 (마이그레이션 망)
```

### 스토리지 도메인 Inactive
```
1순위:
  - 호스트의 vdsm.log (도메인 마운트 시도)
  - mount, multipath -ll
2순위:
  - sanlock.log
  - 스토리지 서버 측 로그
  - dmesg (FC/iSCSI HBA 메시지)
```

### SHE Engine 안 뜸
```
1순위:
  - /var/log/ovirt-hosted-engine-ha/agent.log (모든 SHE 호스트)
  - /var/log/ovirt-hosted-engine-ha/broker.log
  - hosted-engine --vm-status 결과
2순위:
  - /var/log/sanlock.log (lease 획득 실패)
  - /var/log/libvirt/qemu/HostedEngine.log
  - HE 도메인 마운트 상태
```

### 인증서 / 시간 동기 문제
```
1순위:
  - chronyc tracking, chronyc sources
  - openssl x509 ... 로 만료 확인
2순위:
  - vdsm.log (TLS handshake 실패)
  - engine.log (인증 거부)
```

## 로그 빠른 수집 명령

### 최근 1시간 에러만
```bash
# Engine
journalctl -u ovirt-engine --since "1 hour ago" -p err > /tmp/engine-err.log
grep -i "ERROR\|FATAL" /var/log/ovirt-engine/engine.log | tail -50

# 호스트
journalctl -u vdsmd -u libvirtd --since "1 hour ago" -p err
grep -i "ERROR\|FATAL\|Timeout" /var/log/vdsm/vdsm.log | tail -50
```

### 특정 VM 추적
```bash
# VM UUID로 vdsm.log 검색
grep <vm-uuid> /var/log/vdsm/vdsm.log

# VM의 qemu 로그
ls /var/log/libvirt/qemu/ | grep <vm-name>
tail -200 /var/log/libvirt/qemu/<vm-name>.log
```

### 특정 시간대만
```bash
# 2026-04-22 14:00 ~ 15:00
journalctl --since "2026-04-22 14:00" --until "2026-04-22 15:00" -u vdsmd
```

### 로그 보존
- vdsm.log: logrotate 일 1회, 7~14일 보존 (기본)
- engine.log: logrotate 주 1회, 4~8주 보존
- 사고 발생 시 logrotate 전에 로그 보존 권장 (수동 복사)

## sosreport — 대량 정보 수집

문제가 복잡하거나 Oracle Support 케이스 열 때:

### Engine 서버
```bash
sosreport
# 결과: /var/tmp/sosreport-<hostname>-<date>.tar.xz
```

### 호스트
```bash
sosreport -o vdsm,oVirt,libvirt,sanlock,multipath
```

### OLVM 전용 수집기 (deprecated but still works)
```bash
ovirt-log-collector
```

## 로그 분석 팁

### 패턴 검색
```bash
# 시간순 에러만 추출
grep -E "^\d{4}-\d{2}-\d{2}.*ERROR" engine.log | tail -50

# 특정 호스트 추적
grep -E "host01|10\.10\.1\.11" vdsm.log

# 상관관계 찾기 (Engine ↔ vdsm)
# Engine에서 명령 발송 시각 → 같은 시각 vdsm.log 확인
```

### 시간 보정
- Engine과 호스트 로그 시각이 정확히 같아야 분석 쉬움 (NTP 동기 중요)
- 시간대(timezone) 확인: `timedatectl`

### 인터넷 없는 환경
- 로그를 USB로 복사해 사무실에서 분석
- 또는 `tar czf logs.tar.gz /var/log/vdsm/ /var/log/libvirt/` 후 가져옴
- 핵심 로그만 추리려면:
  ```bash
  tar czf /tmp/critical-logs.tar.gz \
    /var/log/vdsm/vdsm.log \
    /var/log/libvirt/libvirtd.log \
    /var/log/libvirt/qemu/<vm-name>.log \
    /var/log/ovirt-hosted-engine-ha/*.log
  ```
