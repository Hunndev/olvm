# OLVM 컴포넌트별 내부 동작

가설 검증 시 깊이 들어갈 때 참조.

## NUMA / CPU 핀

### NUMA 토폴로지
- 호스트는 NUMA 노드를 가짐 (CPU 패키지당 1개가 일반적)
- 각 노드는 자기 메모리에 빠르게 접근, 다른 노드 메모리는 느림 (cross-NUMA latency)
- `numactl --hardware` 로 확인:
  ```
  available: 2 nodes (0-1)
  node 0 cpus: 0-19   size: 196608 MB
  node 1 cpus: 20-39  size: 196608 MB
  ```

### OLVM의 NUMA 처리 흐름
```
[VM 정의]                  [호스트 선택]                [실행]
Engine UI                  스케줄러                    libvirt
vNUMA 설정     ────▶       NUMA 호환 호스트  ────▶     cpuset/memnode 바인딩
NUMA Tune Mode             후보로 필터링                cgroup 적용
CPU Pinning                                            
```

### NUMA Tune Mode
- `interleave` — 모든 노드에 메모리 분산. 안전.
- `strict` — 지정된 노드만 사용. 메모리 부족 시 OOM.
- `preferred` — 선호 노드 우선, 부족하면 다른 노드.

### 마이그레이션 시 NUMA 영향
- 대상 호스트의 NUMA 토폴로지가 다르면 vNUMA 매핑 재계산
- VM의 CPU pinning이 'soft'면 다른 노드로 재배치 가능
- cross-NUMA 메모리 접근 발생 → 레이턴시 증가 → 성능 저하

### 진단 명령
```
# 호스트 NUMA
numactl --hardware

# VM의 메모리 분포
numastat -p <qemu-pid>
# other_node 비율 >5% 면 cross-NUMA 의심

# VM의 CPU 핀
taskset -pc <qemu-pid>

# Libvirt 설정
virsh dumpxml <vm-uuid> | grep -A 5 -E 'numa|cpu|memory'
```

### 가설 검증 체크 포인트
- 양 호스트 `numactl --hardware` 결과 비교
- 호스트별 노드당 코어 수가 VM 요구 vCPU와 호환되는가
- HugePage 설정 여부 (NUMA 영향 크게 다름)
- 클러스터의 CPU Type이 'Lowest Common Denominator'로 다운그레이드되어 있지 않은가

## SPM (Storage Pool Manager)

### 역할
- 한 클러스터에 1대만 SPM
- 스토리지 메타 변경 작업 (디스크 생성/삭제/스냅샷, 도메인 마운트/해제) 책임
- VM 동작 자체에는 영향 없음 (VM은 직접 스토리지 IO)

### Lease 기반 동작
- 스토리지 도메인 자체에 SPM lease 파일 존재 (sanlock 기반)
- SPM 호스트가 주기적으로 lease 갱신
- 갱신 실패 시 다른 호스트가 lease 획득 → 새 SPM
- 자동 인계는 보통 수 분 (sanlock io_timeout × 2 ~ 3배)

### SPM 변경 트리거
- 현 SPM 호스트의 데몬 다운 (vdsm/sanlock)
- 현 SPM 호스트의 스토리지 접근 실패
- 현 SPM 호스트 maintenance 또는 reboot
- 수동 강제 변경 (콘솔에서)

### Contention 증상
- SPM이 자주 바뀜 (몇 분 단위 변경)
- 스토리지 작업 (디스크 생성/스냅샷) 실패
- vdsm.log 에 "SpmStatus" "spmStop" "spmStart" 반복

### 진단
```
# 현재 SPM 호스트
# OLVM 콘솔 > Hosts 에서 SPM 표시
# 또는
vdsm-client Host getVdsCapabilities | grep -i spm

# Sanlock 상태
sanlock client status

# 스토리지 도메인 lease
vdsm-tool list-domains
```

### 가설 검증 (SPM 의심)
- SPM 호스트 변경 빈도 (이상하면 contention)
- 모든 호스트가 스토리지에 정상 접근하는가
- 네트워크 latency (스토리지망)
- sanlock 로그에서 lease 갱신 실패

## ha-agent / ha-broker / sanlock (SHE만)

### 역할
- ha-agent: 각 SHE 호스트에 1개. Engine VM 상태 감시, HA 결정
- ha-broker: ha-agent의 보조. 호스트 간 통신, 메타데이터 공유
- sanlock: 단일 인스턴스 보장 (Engine VM이 한 호스트에만 떠 있도록)

### HE 상태 머신
```
                  ┌─────────────────┐
                  │ EngineUp        │
                  │ (정상 동작)     │
                  └──────┬──────────┘
                         │ 장애
                         ▼
              ┌──────────────────┐
              │ EngineStarting   │
              │ EngineDown       │
              └──────┬───────────┘
                     │ 다른 호스트가
                     ▼
              ┌──────────────────┐
              │ EngineUpOther    │
              │ (다른 호스트에서 │
              │  부팅됨)         │
              └──────────────────┘
```

### Maintenance Mode (HE 한정)
- `None`: 정상 동작, HA 활성
- `Local`: 이 호스트는 HE 후보에서 제외 (다른 호스트로 이동 가능)
- `Global`: 전체 HE HA 비활성 (모든 호스트가 후보 제외)

### 진단
```
# HE 상태
hosted-engine --vm-status

# Maintenance Mode
hosted-engine --get-shared-config maintenance --type=he_local

# Sanlock
sanlock client status
sanlock client gets

# 로그
tail -100 /var/log/ovirt-hosted-engine-ha/agent.log
tail -100 /var/log/ovirt-hosted-engine-ha/broker.log
tail -100 /var/log/sanlock.log
```

### 자주 발생 이슈
- **Engine VM 안 떠움**: HE 도메인 마운트 실패, sanlock lease 획득 실패
- **여러 호스트가 EngineUp 시도**: sanlock 미동작, split-brain 위험
- **자동 페일오버 안 됨**: ha-agent 다운, score 0 (모든 호스트 후보 X)

## 인증서

### 종류
- Engine CA: `/etc/pki/ovirt-engine/ca.pem`
- Engine 인증서: `/etc/pki/ovirt-engine/certs/`
  - `apache.cer` — 웹 콘솔용
  - `engine.cer` — Engine 서비스
  - `jboss.cer`, `websocket-proxy.cer`
- vdsm 인증서: 각 호스트 `/etc/pki/vdsm/`
  - `vdsmcert.pem` — vdsm 서비스 (Engine CA로 서명)
  - `cacert.pem` — Engine CA 사본

### 만료
- 기본 4년
- 만료 시 호스트 Non-Operational, 콘솔 접근 불가
- `engine-setup --offline` 시 갱신 또는 수동 갱신 절차

### 시간 동기와 인증서
- 호스트 시간이 인증서 not_before 보다 이전이면 검증 실패
- 시간이 not_after 이후도 실패
- NTP 끊긴 호스트가 시간이 점프하면 갑자기 인증서 무효

### 진단
```
# 인증서 정보
openssl x509 -in /etc/pki/ovirt-engine/ca.pem -text -noout | head -20

# 만료 빠른 확인
for cert in /etc/pki/ovirt-engine/certs/*.cer; do
  echo "$cert: $(openssl x509 -in $cert -enddate -noout)"
done

# vdsm 측
openssl x509 -in /etc/pki/vdsm/certs/vdsmcert.pem -text -noout | head -20
```

## 네트워크 — vdsm-libvirt 흐름 (각론)

### 호스트 네트워크 구조
```
Physical NIC (eth0, eth1, ...)
   ↓ (본딩)
Bond Interface (bond0)
   ↓ (VLAN)
VLAN Subinterface (bond0.100)
   ↓ (브리지)
Bridge (ovirtmgmt, vmnet1, ...)
   ↓
VM tap interfaces
```

### vdsm 네트워크 관리
- vdsm이 네트워크 구성 관리 (NetworkManager 비활성 권장)
- 구성 파일: `/etc/sysconfig/network-scripts/ifcfg-*` (vdsm이 작성)
- `vdsm-tool list-nics`, `vdsm-tool restore-nets` 등으로 조작

### 마이그레이션 네트워크
- 클러스터 설정에서 별도 지정 가능
- 분리하면 운영 트래픽에 영향 X
- 미분리면 관리망 사용 (운영 시간 마이그레이션 시 콘솔 끊김 위험)

## QEMU / KVM — VM 레벨

### VM 프로세스
```
ps -ef | grep qemu-kvm
# 각 VM당 qemu-kvm 프로세스 하나
```

### VM 상태 (Engine UI vs Libvirt vs QEMU)
| Engine UI | Libvirt | QEMU | 의미 |
|---|---|---|---|
| Up | running | 실행 중 | 정상 |
| Down | shut off | 없음 | 정상 종료 상태 |
| Paused | paused | suspend | 일시정지 (이유 다양) |
| Not Responding | running | 실행 중 | qemu는 떠 있는데 guest-agent 응답 X |
| Unknown | (모름) | (모름) | vdsm-Engine 통신 끊김 |

### Pause 원인
- IO error (스토리지 접근 실패) — 가장 흔함, EIO
- ENOSPC (스토리지 용량 부족)
- 외부 신호 (관리자가 일시정지)
- 마이그레이션 중 일시정지

### 진단
```
# VM 상태
virsh list --all

# VM 정의
virsh dumpxml <vm-uuid> > /tmp/vm.xml

# VM 통계
virsh domstats <vm>

# qemu 프로세스
ps -ef | grep <vm-uuid>

# guest-agent 통신
virsh domiflist <vm>  # 네트워크 인터페이스
```
