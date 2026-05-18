# OLVM 자주 발생 이슈 패턴

증상 → 의심 영역 → 1차 진단 → 후속 분기.

## A. 호스트 Non-Responsive

### 증상
- OLVM 콘솔에서 호스트가 "Non Responsive" 또는 "Connecting"
- Engine이 vdsm에 명령 못 보냄

### 가장 흔한 원인
1. **시간 동기 깨짐** → 인증서 검증 실패
2. **vdsm 데몬 다운**
3. **Engine ↔ 호스트 네트워크 단절**
4. **호스트 hung** (스토리지 IO blocking, 부하)
5. **인증서 만료**

### 1차 진단
```
[호스트에서]
□ systemctl status vdsmd supervdsmd
□ date / chronyc tracking
□ ping <engine-fqdn> / nc -zv <engine-ip> 443
□ free -h, df -h
□ uptime, load average

[Engine에서]
□ ping <host-ip>
□ nc -zv <host-ip> 54321
□ engine.log 에 해당 호스트 키워드 검색
```

### 분기
- vdsmd 다운 → 재기동 시도 (🟡 L3)
- 시간 차이 큼 → NTP 재동기, vdsm 재기동
- 네트워크 단절 → 스위치/방화벽 확인
- IO blocking → 스토리지 점검
- 인증서 만료 → 별도 갱신 절차

## B. VM Paused (EIO)

### 증상
- VM 콘솔에서 "Paused"
- 디스크 IO 에러 메시지

### 흔한 원인
1. 스토리지 도메인 일시 단절
2. 스토리지 측 LUN 장애
3. NFS 서버 응답 끊김
4. 멀티패스 모든 path 장애

### 1차 진단
```
[해당 호스트에서]
□ virsh list --all (VM 상태)
□ virsh domstate <vm> --reason
□ tail -100 /var/log/libvirt/qemu/<vm-name>.log
□ vdsm-tool list-domains (도메인 상태)
□ multipath -ll (FC/iSCSI)
□ mount | grep nfs
□ dmesg -T | tail -50
```

### 분기
- 도메인 inactive → 스토리지 도메인 처리
- multipath 일부 fail → HBA/케이블/스위치 점검
- 모든 path fail → 스토리지 서버 측 처리 필요
- 스토리지 복귀 후 VM 자동 resume 안 됨 → 콘솔에서 resume

## C. SHE Engine VM 다운

### 증상
- OLVM 웹 콘솔 접속 불가
- `hosted-engine --vm-status` 결과 EngineDown 또는 EngineStarting

### 흔한 원인
1. Engine VM 자체 OS 문제 (디스크 풀, 메모리)
2. HE 도메인 마운트 실패
3. Sanlock lease 획득 실패
4. ha-agent 다운
5. Maintenance Mode 잘못 켜짐

### 1차 진단
```
[모든 SHE 호스트에서]
□ hosted-engine --vm-status
□ systemctl status ovirt-ha-agent ovirt-ha-broker sanlock
□ tail -100 /var/log/ovirt-hosted-engine-ha/agent.log
□ tail -100 /var/log/sanlock.log
□ hosted-engine --get-shared-config maintenance --type=he_local
□ HE 도메인 마운트 확인 (mount | grep he)
```

### 분기
- Maintenance: Global → 정상 해제 (`hosted-engine --set-maintenance --mode=none`)
- 모든 호스트 score 0 → ha-agent 재시작
- Engine VM이 한 호스트에 떠 있는데 응답 X → Engine VM 콘솔 접속 (`hosted-engine --console`)
- HE 도메인 마운트 실패 → 스토리지 처리
- Sanlock 락 분쟁 → 모든 호스트 sanlock 재시작 (위험, L3)

## D. 스토리지 도메인 Inactive

### 증상
- OLVM 콘솔에서 도메인 "Inactive"
- 해당 도메인의 VM 모두 Paused

### 흔한 원인
1. 스토리지 서버 일시 단절
2. 호스트 측 마운트 끊김 (stale handle)
3. iSCSI/FC path 장애
4. 스토리지 서버 정전/재기동
5. 방화벽 정책 변경

### 1차 진단
```
[영향 호스트에서]
□ vdsm-tool list-domains
□ mount | grep -E 'nfs|iscsi'
□ ping <storage-ip>, nc -zv <storage-ip> 2049 (NFS) / 3260 (iSCSI)
□ multipath -ll
□ iscsiadm -m session (iSCSI)
□ tail -100 /var/log/vdsm/vdsm.log | grep -i 'domain\|storage\|mount'
□ dmesg -T | tail -50
```

### 분기
- 스토리지 서버 다운 → 스토리지팀 협의
- 마운트 stale → 호스트 maintenance 모드 후 재마운트
- 일부 호스트만 영향 → 그 호스트 네트워크/방화벽
- 다 영향 → 스토리지 측 또는 공통 네트워크 문제

## E. 마이그레이션 실패

### 증상
- VM 마이그레이션이 시작했다가 실패
- engine.log 에 "Migration failed" 메시지

### 흔한 원인
1. **CPU Type 비호환** — 대상 호스트가 더 낮은 모델
2. 마이그레이션 네트워크 단절 또는 대역폭 부족
3. 양쪽 호스트의 스토리지 도메인 접근 차이
4. 대상 호스트 메모리 부족
5. VM의 SR-IOV / PCI passthrough 사용
6. NUMA 설정 불일치
7. VM의 디스크 type/format 호환성

### 1차 진단
```
[양 호스트에서]
□ lscpu | grep "Model name"
□ free -h
□ vdsm-tool list-domains (양쪽 같은 도메인 마운트?)
□ ip a show ovirtmgmt
□ ping <other-host>

[VM 측]
□ virsh dumpxml <vm-uuid> | grep -E 'cpu|numa|hostdev'
□ Engine UI에서 VM > Host > NUMA / Pinning 설정

[Engine]
□ engine.log 마이그레이션 시점 grep
```

### 분기
- CPU 비호환 → 클러스터 CPU Type 낮추거나 호스트 분리
- 메모리 부족 → 다른 호스트로 마이그레이션 또는 메모리 추가
- SR-IOV/PCI passthrough → 마이그레이션 불가, 정지 후 이동
- 네트워크 문제 → 마이그레이션 망 점검

## F. NUMA 의심 (VM 성능 저하)

### 증상
- VM 마이그레이션 후 성능 떨어짐
- VM이 특정 호스트에서만 느림

### 1차 진단
```
[양 호스트에서]
□ numactl --hardware (NUMA 토폴로지)
□ cat /proc/cpuinfo | grep "Model name"
□ free -h (총 메모리, NUMA별)

[현재 VM 위치 호스트에서]
□ ps -ef | grep <vm-uuid>  → qemu pid 확인
□ numastat -p <qemu-pid>   → other_node 비율
□ taskset -pc <qemu-pid>   → CPU pin
□ virsh dumpxml <vm-uuid> | grep -A 5 numa

[Engine]
□ VM > Host > NUMA Pinning, CPU Pinning 설정
□ Cluster > CPU Type (Lowest Common Denominator?)
```

### 분기
- 양 호스트 NUMA 비대칭 → VM NUMA pin 권고
- cross-NUMA 메모리 접근 많음 → 메모리 strict mode 또는 호스트 분리
- 클러스터 CPU Type 다운그레이드 → 호스트 분리 고려

## G. SPM Contention

### 증상
- SPM 호스트가 자주 바뀜
- 스토리지 작업 (디스크 생성, 스냅샷) 실패
- vdsm.log 에 `SpmStatus` 반복

### 1차 진단
```
[모든 호스트에서]
□ vdsm-client Host getVdsCapabilities | grep -i spm
□ systemctl status sanlock vdsmd
□ tail -100 /var/log/sanlock.log
□ vdsm-tool list-domains

[Engine]
□ engine.log 에 'spm' 키워드 grep
```

### 분기
- sanlock 불안정 → 스토리지 네트워크/latency 점검
- 한 호스트만 SPM 못 잡음 → 그 호스트 스토리지 접근 문제
- 자주 변경됨 → 스토리지 서버 측 응답 시간 점검

## H. vdsm Timeout (자주 발생)

### 증상
- 호스트가 가끔 Non-Responsive 되었다 복귀
- vdsm.log 에 `Timeout` 빈발

### 흔한 원인
1. 스토리지 latency (NFS 응답 느림)
2. DNS 응답 느림
3. 호스트 부하 (CPU 100%, swap)
4. Oracle 버그 (특정 버전)

### 진단
- vdsm.log timeout 빈도, 어느 작업에서 발생
- 시간대 패턴 (백업 시간? 야간 작업 시간?)
- Oracle Support 케이스 검색

## I. 인증서 만료

### 증상
- 호스트가 갑자기 Non-Operational
- engine.log 에 SSL/TLS 에러
- 시간 차이 없는데 인증서 검증 실패

### 진단
```
[Engine]
□ /etc/pki/ovirt-engine/certs/ 인증서 만료일

[호스트]
□ openssl x509 -in /etc/pki/vdsm/certs/vdsmcert.pem -enddate -noout
```

### 분기
- Engine CA 만료 임박 → 갱신 절차 (engine-setup으로 가능)
- 호스트 인증서 만료 → 호스트 재등록 또는 vdsm cert 재발급

## J. PostgreSQL 문제 (Engine DB)

### 증상
- Engine 서비스 시작 실패
- 콘솔이 매우 느림
- 일부 작업 후 무한 대기

### 진단
```
[Engine 서버]
□ systemctl status postgresql
□ /var/lib/pgsql/data/log/ 의 최근 로그
□ pg_isready
□ df -h /var/lib/pgsql
```

## 자주 보는 에러 메시지 사전

### vdsm.log
| 메시지 | 의미 | 의심 |
|---|---|---|
| `Connection refused` | 데몬 다운 또는 포트 막힘 | 서비스 상태, 방화벽 |
| `Timeout` (jsonrpc) | Engine ↔ vdsm 통신 timeout | 네트워크 / 호스트 부하 |
| `SSL handshake failed` | 인증서 또는 시간 동기 | NTP, 인증서 만료 |
| `StorageDomainDoesNotExist` | 도메인 메타 불일치 | 도메인 마운트, SPM |
| `NoSpaceLeft` | 스토리지 도메인 용량 부족 | 도메인 정리 |
| `EIO` | 디스크 IO 에러 | 스토리지 측 |
| `SpmStop`/`SpmStart` 반복 | SPM contention | 스토리지 latency |

### engine.log
| 메시지 | 의미 |
|---|---|
| `VDS_NOT_RESPONDING` | 호스트가 vdsm 응답 안 함 |
| `MIGRATION_FAILED` | 마이그레이션 실패 |
| `VM_PAUSED_EIO` | VM이 IO 에러로 paused |
| `STORAGE_DOMAIN_DEACTIVATED` | 스토리지 도메인 inactive |
| `IRSAlgorithm: SPM not found` | SPM 호스트 없음 |

### qemu 로그 (VM)
| 메시지 | 의미 |
|---|---|
| `Block I/O error on device` | 디스크 접근 실패 |
| `qemu-system-x86_64: terminating on signal` | VM 종료됨 |
| `Out of memory` | 호스트 메모리 부족, OOM killer |
