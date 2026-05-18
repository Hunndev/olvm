# OLVM 시나리오별 Runbook

각 시나리오는 # 헤딩으로 분리. Claude는 증상 매칭 시 해당 섹션만 발췌해 활용.

---

# Host Non-Responsive

## 증상 확인
- OLVM 콘솔에서 호스트 "Non Responsive" 또는 "Connecting" 표시
- 그 호스트의 VM은 동작 중일 수도, 끊겼을 수도

## 1차 진단 (안전, 모두 read-only)

```
🟢 [{site}/{host}] 다음 명령 결과 받기:

1. systemctl status vdsmd supervdsmd
2. journalctl -u vdsmd --since "30 min ago" -p err
3. date
4. chronyc tracking
5. ping <engine-fqdn>
6. nc -zv <engine-ip> 443
7. free -h
8. uptime
9. dmesg -T | tail -30
```

Engine 측에서:
```
🟢 [Engine] 다음 명령:
1. ping <host-ip>
2. nc -zv <host-ip> 54321
3. grep <host-fqdn> /var/log/ovirt-engine/engine.log | tail -50
```

## 의사결정 트리

```
호스트 응답하나?
├─ ping 가능
│  ├─ vdsmd active
│  │  ├─ 인증서 정상 + 시간 동기 정상
│  │  │  └─ engine.log 에 통신 에러 → 네트워크 (방화벽, 라우팅)
│  │  └─ 시간 차이 큼 → NTP 동기 후 vdsm 재기동
│  └─ vdsmd inactive/failed
│     └─ journalctl 로 사유 확인 → 재기동 또는 의존성 점검
└─ ping 불가
   ├─ 콘솔/iLO 접근 가능 → 호스트 OS 레벨 점검
   ├─ 콘솔도 불가 → 물리적 다운 (전원, NIC)
   └─ 운영 VM 다른 호스트로 이전 (가능 시) 또는 fence (위험)
```

## 조치

### vdsmd 재기동 (🟡 L3 협의 후)
- 영향: VM은 동작 유지, OLVM에서 1-2분 Non-Responsive
- 사전: 진행 중 마이그레이션 없는지
- 명령: `systemctl restart vdsmd`
- 결과 확인: `systemctl status vdsmd`, 콘솔에서 호스트 Up 복귀

### 호스트 fence (🔴 위험)
- 영향: 호스트 전원 차단, 그 호스트 VM 전부 다운
- 사전: 다른 호스트로 VM 이전 불가능한 경우만
- 정상 호스트인데 OLVM 표시만 이상하면 fence 절대 금지

## 복구 후
- 사이트 .md 의 "작업 이력" 에 추가
- 자주 발생하면 frontmatter `risk_level` 'high' 검토
- "알려진 이슈" 에 패턴 기록

---

# SHE Engine VM Down

## 증상 확인
- OLVM 웹 콘솔 접속 불가 (또는 매우 느림)
- `hosted-engine --vm-status` 가 EngineDown / EngineStarting / EngineUnexpectedlyDown

## 1차 진단

```
🟢 [{site}/모든 SHE 호스트에서]:

1. hosted-engine --vm-status
2. systemctl status ovirt-ha-agent ovirt-ha-broker sanlock
3. tail -100 /var/log/ovirt-hosted-engine-ha/agent.log
4. tail -100 /var/log/ovirt-hosted-engine-ha/broker.log
5. tail -100 /var/log/sanlock.log
6. hosted-engine --get-shared-config maintenance --type=he_local
7. mount | grep -i he   (HE 도메인 마운트)
8. df -h <HE 마운트 경로>
```

## 의사결정 트리

```
hosted-engine --vm-status 결과
├─ Maintenance Mode == Global
│  └─ Global 해제: hosted-engine --set-maintenance --mode=none (🟡)
├─ 모든 호스트 score 0
│  ├─ HE 도메인 접근 불가 → 스토리지 처리
│  ├─ Sanlock 분쟁 → 모든 호스트 sanlock 재기동 (🔴 위험, L3 협의)
│  └─ ha-agent 다운 → 재기동 (🟡)
├─ 한 호스트만 EngineUp 인데 응답 X
│  ├─ Engine VM 콘솔 접근 (hosted-engine --console)
│  ├─ Engine VM 내부 점검 (디스크 풀, OOM, postgresql 다운)
│  └─ 정상 종료 후 재부팅 (hosted-engine --vm-shutdown / --vm-start)
└─ EngineStarting 무한 반복
   ├─ Engine VM 디스크 손상 확인
   ├─ HE 도메인 lease 분쟁 (sanlock)
   └─ 백업 복원 검토 (최후)
```

## 핵심 명령

```
# Maintenance 해제
🟡 [{site}] hosted-engine --set-maintenance --mode=none

# ha-agent 재기동 (해당 호스트만)
🟡 [{site}/{host}] systemctl restart ovirt-ha-agent ovirt-ha-broker

# Engine VM 강제 종료 (정상 종료 안 될 때)
🟡 [{site}/{host}] hosted-engine --vm-poweroff

# Engine VM 시작
🟡 [{site}/{host}] hosted-engine --vm-start

# Engine VM 콘솔 (내부 진단)
🟢 [{site}/{host}] hosted-engine --console
   (ESC + ] 로 종료)
```

## 절대 금지
- Engine VM 디스크 강제 삭제
- HE 도메인 강제 마운트 해제
- 여러 호스트에서 동시에 Engine VM start 시도 (sanlock 분쟁 유발)

---

# Storage Domain Inactive

## 증상
- 콘솔에서 도메인 "Inactive"
- 해당 도메인의 VM 전부 Paused

## 1차 진단

```
🟢 [{site}/영향 호스트에서]:

1. vdsm-tool list-domains
2. mount | grep -E 'nfs|iscsi|gluster'
3. df -h
4. multipath -ll   (FC/iSCSI인 경우)
5. iscsiadm -m session   (iSCSI인 경우)
6. ping <storage-ip>
7. nc -zv <storage-ip> 2049   (NFS)
8. nc -zv <storage-ip> 3260   (iSCSI)
9. tail -100 /var/log/vdsm/vdsm.log | grep -i 'domain\|storage\|mount'
10. dmesg -T | tail -50
```

## 의사결정 트리

```
얼마나 영향?
├─ 한 호스트만 inactive
│  ├─ 그 호스트의 마운트만 끊김 → 호스트 measurement 후 재마운트
│  ├─ 그 호스트의 네트워크/방화벽 → 네트워크 처리
│  └─ 그 호스트의 multipath path 장애 → HBA 점검
└─ 모든 호스트 inactive
   ├─ 스토리지 서버 다운 → 스토리지팀
   ├─ 공통 네트워크 (스위치, 방화벽) → 네트워크팀
   └─ 스토리지 서버 응답 느림 (timeout) → 부하 점검
```

## 조치 순서

```
1단계: 스토리지 서버 측 정상화 (담당팀)

2단계: 영향 호스트들 정상화
   - 마운트 stale 한 호스트는 maintenance 모드 전환
   - 마운트 재시도 (자동)
   - 도메인 activate (콘솔 또는 vdsm)

3단계: VM 정상화
   - 스토리지 복귀 후 VM 자동 resume
   - 자동 안 되면: virsh resume <vm> 또는 콘솔에서 resume
```

## 절대 금지
- inactive 상태에서 도메인 강제 삭제
- 호스트의 /rhev/data-center 디렉토리 강제 삭제
- 마운트 점유 중인 디렉토리 강제 umount -f (운영 중)

---

# VM Paused (EIO / ENOSPC)

## 증상
- VM 콘솔/상태가 "Paused"
- 이유: paused (io-error) 또는 paused (out-of-space)

## 1차 진단

```
🟢 [{site}/{host} VM 있는 호스트에서]:

1. virsh list --all
2. virsh domstate <vm> --reason
3. tail -100 /var/log/libvirt/qemu/<vm-name>.log
4. vdsm-tool list-domains   (도메인 상태)
5. df -h   (호스트 디스크 / NFS 마운트)
6. multipath -ll   (FC/iSCSI)
7. dmesg -T | tail -50
```

## 분기

```
Pause 이유:
├─ io-error
│  ├─ 도메인 inactive → "Storage Domain Inactive" runbook
│  └─ 일시 정상화 후 자동 resume 안 됨 → virsh resume <vm>
├─ out-of-space
│  └─ 도메인 용량 확보 (스냅샷 정리, 디스크 확장) → 자동 resume
└─ user / migration
   └─ 정상 동작 또는 의도된 일시 정지
```

## 조치

```
# 스토리지 정상화 후 자동 resume 안 되면
🟡 [{site}/{host}] virsh resume <vm>

# 또는 Engine 콘솔에서 VM > Resume

# 안 되면 정지 후 재기동 (데이터 손상 가능)
🟡 콘솔에서 VM > Shutdown → 정지 확인 → Start
```

---

# SPM Contention

## 증상
- SPM 호스트가 자주 바뀜 (몇 분 단위)
- 스토리지 작업 실패 (디스크 생성, 스냅샷)
- vdsm.log 에 `SpmStatus`, `spmStop`, `spmStart` 반복

## 1차 진단

```
🟢 [{site}/모든 호스트에서]:

1. vdsm-client Host getVdsCapabilities | grep -i spm
2. systemctl status sanlock vdsmd
3. tail -100 /var/log/sanlock.log
4. vdsm-tool list-domains
5. tail -200 /var/log/vdsm/vdsm.log | grep -iE 'spm|sanlock'
6. ping <storage-ip>의 latency (10회)
7. multipath -ll
```

## 의사결정 트리

```
원인 영역
├─ sanlock lease 갱신 실패
│  ├─ 스토리지 latency 큼 → 스토리지 측 처리
│  ├─ 호스트 시간 동기 깨짐 → NTP
│  └─ 도메인 메타 손상 → 백업 복원 검토 (L3+)
├─ 특정 호스트만 SPM 못 잡음
│  ├─ 그 호스트 스토리지 접근 문제 → multipath, mount
│  └─ 그 호스트 sanlock 다운 → 재기동
└─ 자주 변경
   └─ 스토리지 서버 응답 시간 점검
```

## 조치
- 즉시 안정화: 콘솔에서 SPM 우선 호스트 지정 (정상인 호스트로)
- 근본 원인: 스토리지 latency, sanlock 점검
- 마지막 수단: 모든 호스트 sanlock 재기동 (🔴 위험, L3+)

---

# Engine Service Down

## 증상
- OLVM 웹 콘솔 접속 불가
- (Standalone Engine 시) Engine 서버 직접 접속해 진단

## 1차 진단

```
🟢 [Engine 서버에서]:

1. systemctl status ovirt-engine
2. journalctl -u ovirt-engine --since "1 hour ago"
3. tail -100 /var/log/ovirt-engine/server.log
4. tail -100 /var/log/ovirt-engine/engine.log
5. systemctl status postgresql
6. pg_isready
7. df -h
8. free -h
9. ss -tlnp | grep -E ':80|:443|:5432'
```

## 분기

```
Engine 서비스 상태:
├─ failed
│  ├─ server.log 에 시작 실패 사유
│  ├─ /var 풀 → 공간 확보
│  ├─ Java OOM → JVM 메모리 설정
│  └─ DB 연결 실패 → postgresql 점검
├─ activating (계속 시작 중)
│  └─ DB 응답 느림 또는 자원 부족
└─ active 인데 콘솔 접속 안 됨
   ├─ Apache/Reverse proxy 측 (4.4+ 보통 직접 JBoss)
   ├─ 인증서 만료
   └─ 방화벽 / 외부 LB
```

## 조치

```
# Engine 재기동 (1-2분 콘솔 다운)
🟡 [Engine] systemctl restart ovirt-engine

# PostgreSQL 재기동 (Engine 의존)
🟡 [Engine] systemctl restart postgresql && sleep 5 && systemctl restart ovirt-engine

# 로그 정리 (디스크 풀인 경우)
🟢 [Engine] find /var/log/ovirt-engine -name "*.gz" -mtime +14 -delete
```

---

# Certificate Expired / Time Sync Issue

## 증상
- 호스트 갑자기 Non-Operational
- SSL handshake 에러
- 시간 차이 명확함 (분 단위)

## 1차 진단

```
🟢 [Engine + 모든 호스트]:

1. date
2. chronyc tracking
3. chronyc sources

🟢 [Engine]:
4. for cert in /etc/pki/ovirt-engine/certs/*.cer; do
     echo "$cert: $(openssl x509 -in $cert -enddate -noout)"
   done

🟢 [각 호스트]:
5. openssl x509 -in /etc/pki/vdsm/certs/vdsmcert.pem -enddate -noout
```

## 분기

```
원인:
├─ 시간 차이 5초 이상
│  ├─ NTP 미동작 → chronyd 재시작 + 소스 확인
│  └─ chronyd 동작 중인데도 차이 → 소스 응답 안 됨
└─ 인증서 만료 임박/만료
   ├─ Engine 인증서 → engine-setup --offline 으로 갱신 절차
   └─ 호스트 인증서 → 호스트 재등록 또는 vdsm cert 재발급
```

## 조치

```
# NTP 즉시 동기
🟡 [{host}] chronyc makestep
   (큰 시간 점프 - vdsm 재기동 권장)

🟡 [{host}] systemctl restart vdsmd

# 인증서 갱신은 별도 절차 (L3, 백업 후)
```

---

# Maintenance 작업 워크플로우

운영 중 작업이 필요한 일반 패턴:

## 호스트 재부팅 (점검/펌웨어 등)

```
1. 사전:
   - 변경 윈도우 확인
   - 운영 VM 다른 호스트로 마이그레이션 가능한지
   - SHE 호스트면 추가 주의 (HE 영향)

2. 절차:
   - OLVM 콘솔 > Hosts > {host} > Maintenance
   - VM 자동 마이그레이션 진행 확인
   - 모든 VM 이전 완료 후
   - OS에서 reboot 또는 펌웨어 작업
   - 부팅 후 Activate
   - vdsm 정상 등록 확인

3. 검증:
   - 호스트 Up 상태
   - vdsm.log 에 에러 없음
   - 다른 호스트와 통신 정상
```

## Engine 업그레이드

별도 절차. 항상 백업 후, 점검 윈도우에. Oracle 공식 문서 참조.

## 스토리지 도메인 작업 (LUN 추가/삭제)

항상 maintenance 모드 후 작업. 콘솔에서 도메인 관리.
