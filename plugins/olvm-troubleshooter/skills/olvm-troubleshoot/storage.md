# OLVM 스토리지 — NFS / iSCSI / FC / 도메인 / SPM

## 스토리지 도메인 종류

| 종류 | 용도 | 비고 |
|---|---|---|
| Data | VM 디스크, 스냅샷 | 1개 이상 필수. 클러스터별 |
| ISO | 설치 이미지 | deprecated (4.4+ 통합) |
| Export | VM 백업/이전 | deprecated |
| Hosted Engine (HE) | SHE Engine VM 디스크, HA 메타 | SHE 전용 |

## 스토리지 종류별 특성

### NFS
- 가장 단순. NFSv3 vs NFSv4 차이 주의.
- 권장: NFSv4 (lock 동작 안정)
- 마운트: `<server>:<export>` (예: `nfs01.local:/vol/olvm_data`)
- 흔한 문제:
  - root squash → vdsm 권한 문제
  - no_root_squash 설정 권장
  - export 옵션에 `rw,sync,no_subtree_check,no_root_squash`
  - 클라이언트 측 마운트 옵션: `rw,relatime,vers=4.2,timeo=600,...`

### iSCSI
- LUN 단위로 스토리지 도메인 생성
- 멀티패스 필수 (multipath 활성)
- CHAP 인증 권장 (initiator/target 양쪽)
- 마운트: 자동 (vdsm이 iscsiadm 사용)

### FC SAN
- 멀티패스 필수
- WWPN 영역 분리 (zoning) 확인
- HBA 드라이버/펌웨어 버전 점검

### Gluster
- 노드 수 3 이상, replica 3 권장
- arbiter 노드로 split-brain 방지 가능

## 마운트 확인

```bash
# 모든 마운트
mount | grep -E 'nfs|iscsi|gluster'

# vdsm이 관리하는 도메인
vdsm-tool list-domains

# 도메인 디렉토리 구조
ls /rhev/data-center/
ls /rhev/data-center/mnt/
```

## SPM (Storage Pool Manager)

### 역할
- 클러스터당 1대만 SPM
- 메타 작업 (디스크 생성/삭제, 스냅샷) 책임
- VM IO 자체에는 관여 X (VM은 직접 스토리지 접근)

### Lease 동작
- 스토리지 도메인 자체에 SPM lease 파일
- sanlock으로 단일성 보장
- 갱신 실패 시 자동 인계 (sanlock io_timeout × 2~3)

### Contention 증상
- SPM이 자주 바뀜 (몇 분 단위)
- 스토리지 작업 실패 (디스크 생성, 스냅샷)
- vdsm.log 에 `SpmStatus`, `spmStop`, `spmStart` 반복
- Engine UI에 SPM 호스트 표시가 계속 변경

### 진단
```bash
# 현재 SPM (콘솔 또는)
vdsm-client Host getVdsCapabilities | grep -i spm

# Sanlock
sanlock client status
sanlock client gets

# 도메인 상태
vdsm-tool list-domains

# 도메인 메타 (위험! 읽기만)
ls /rhev/data-center/mnt/<server>/<path>/<domain-uuid>/dom_md/
```

## VM Paused 시나리오

VM이 Paused 상태 되는 가장 흔한 원인은 스토리지 IO 문제.

### Pause 원인 분류

| 원인 | Libvirt 표시 | 로그 |
|---|---|---|
| EIO (IO error) | `paused (io-error)` | qemu 로그에 `Block I/O error` |
| ENOSPC (용량 부족) | `paused (out-of-space)` | qemu 로그에 `ENOSPC` |
| 관리자 일시정지 | `paused (user)` | Engine 로그 |
| 마이그레이션 중 | `paused (migration)` | 정상 동작 |

### 진단
```bash
# VM 상태 상세
virsh list --all
virsh domstate <vm> --reason

# qemu 로그
ls /var/log/libvirt/qemu/
tail -100 /var/log/libvirt/qemu/<vm-name>.log

# 도메인 상태
vdsm-tool list-domains | grep -A 5 <domain-uuid>
```

### 복구
- EIO: 스토리지 정상 복귀 후 VM 자동 resume 또는 콘솔에서 resume
- ENOSPC: 도메인 용량 확보 후 resume
- 만약 VM이 resume 안 되면: `virsh resume <vm>` 시도

## 멀티패스 (FC/iSCSI)

### 정상 동작 확인
```bash
multipath -ll

# 출력 예
# 360000000000abc dm-0 NETAPP,LUN
# size=500G features='1 queue_if_no_path' hwhandler='1 alua' wp=rw
# |-+- policy='service-time 0' prio=50 status=active
# | |- 1:0:0:1 sdb 8:16 active ready running
# | `- 2:0:0:1 sdc 8:32 active ready running
# `-+- policy='service-time 0' prio=10 status=enabled
#   |- 1:0:1:1 sdd 8:48 active ready running
#   `- 2:0:1:1 sde 8:64 active ready running
```

각 path: `active ready running` 이 정상. `failed` 있으면 path 일부 장애.

### 한 path 장애 시
- 자동 fallback (정상 동작)
- 단, 일정 시간 latency 증가 가능
- HBA 모듈 / 케이블 / 스위치 점검

### 모든 path 장애 시
- 스토리지 접근 불가
- VM 모두 paused
- vdsm.log 에 EIO 폭주

## NFS 흔한 이슈

### 마운트 끊김 (stale handle)
- 증상: `ls` 등 명령에서 `stale file handle`
- 원인: NFS 서버 재기동, 네트워크 끊김
- 복구: 마운트 해제 후 재마운트 (vdsm-tool로)

### Lock 문제 (NFSv3)
- NLM (Network Lock Manager) 동작 불안정
- NFSv4 권장

### Soft mount 사용 (위험)
- timeo 작은 값으로 빠른 실패
- OLVM은 hard mount 권장 (timeo 600)
- soft mount는 데이터 손상 위험

## 도메인 Inactive 시 진단

```
1. 어느 호스트에서 inactive 표시되는가 (전체 호스트 vs 일부)
2. 해당 호스트에서 mount 확인
3. 스토리지 서버 ping/포트 확인
4. 멀티패스 path 상태 (FC/iSCSI)
5. sanlock 상태
6. vdsm.log 에서 도메인 UUID 검색
7. SPM 호스트 정상 여부
```

## 용량 관리

### 도메인 여유 용량
- 임계치: 10% 미만이면 알람
- VM 디스크 thin provisioning이면 실제 사용량 >> 도메인 표시 사용량 가능
- 스냅샷이 누적되면 빠르게 증가

### 진단
```bash
# 도메인별 용량 (호스트에서)
df -h | grep rhev

# 도메인 정보 (콘솔 또는)
vdsm-client StoragePool getStoragePoolInfo storagepoolID=<sp-uuid>

# 도메인 안의 디스크별 크기
du -sh /rhev/data-center/mnt/<...>/<domain-uuid>/images/*/
```

## 스토리지 점검 체크리스트

문제 의심 시:

- [ ] `vdsm-tool list-domains` — 모든 도메인 active?
- [ ] `mount | grep nfs` — 마운트 정상?
- [ ] `multipath -ll` — path 전부 active? (FC/iSCSI)
- [ ] SPM 호스트 정상? 자주 바뀌는가?
- [ ] 도메인 여유 용량 > 10%?
- [ ] 스토리지 서버 ping 정상? 포트 응답?
- [ ] `sanlock client status` — 정상?
- [ ] vdsm.log에 IO 에러?
- [ ] qemu 로그에 IO 에러?
- [ ] dmesg에 디스크/HBA 에러?

## 백업 (Engine 측)

### engine-backup
- 표준 백업 도구 (4.4+)
- 백업: `engine-backup --mode=backup --file=/path/backup.tar.gz --log=/path/log.log`
- 복원: `engine-backup --mode=restore --file=/path/backup.tar.gz ...`
- 검증: `engine-backup --mode=verify --file=/path/backup.tar.gz`

### 백업이 포함하는 것
- Engine DB
- DWH DB (옵션)
- PKI 인증서
- 설정 파일

### 백업이 포함하지 않는 것
- VM 디스크 (별도 스토리지 레벨 백업 필요)
- 호스트 설정
- 모니터링 데이터

### 복구 테스트
- 분기 1회 이상 권장
- 별도 테스트 환경에서 verify + restore 시도
- 마지막 테스트 일자 사이트 .md 에 기록
