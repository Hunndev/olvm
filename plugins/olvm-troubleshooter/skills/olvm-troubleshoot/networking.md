# OLVM 네트워크 — 망 분리, 본딩, 방화벽

## 망 종류와 역할

| 망 | 역할 | 분리 권장도 |
|---|---|---|
| 관리망 (ovirtmgmt) | Engine ↔ 호스트, vdsm 통신 | 필수 (그 자체로 분리망) |
| VM망 | VM의 외부 통신 | 강력 권장 |
| 스토리지망 | 호스트 ↔ 스토리지 | **필수 권장** (미분리는 위험) |
| 마이그레이션망 | VM live migration 트래픽 | 권장 |
| Display/Console망 | VNC/SPICE 콘솔 | 선택 |

## 스토리지망 미분리 위험

운영 상황에서 자주 보는 사고:
- VM이 대량 IO 발생 → 스토리지망 포화
- 같은 망인 관리망(vdsm-Engine) 응답 지연
- Engine이 호스트 응답 못 받음 → 호스트 Non-Responsive
- 자동 fence 트리거 가능
- 그 호스트 VM 전부 다운

해결: 스토리지망을 별도 VLAN/물리망으로 분리.

## 본딩

### 모드별 특성
| 모드 | 명칭 | 스위치 설정 | OLVM 권장 |
|---|---|---|---|
| 0 | balance-rr | unused | X (패킷 순서) |
| 1 | active-backup | 불필요 | 가장 안전, 권장 |
| 2 | balance-xor | static LAG | 가능 |
| 4 | 802.3ad (LACP) | LACP 설정 | 처리량 필요 시 |
| 5 | balance-tlb | 불필요 | X |
| 6 | balance-alb | 불필요 | X |

### LACP 확인
```bash
cat /proc/net/bonding/bond0

# 확인 포인트
# - Bonding Mode: IEEE 802.3ad Dynamic link aggregation
# - LACP rate: fast (또는 slow)
# - System priority, Partner ...
# - Slave Interface 별 link status

# 스위치 측 LACP 상태도 양쪽 일치 필요
```

### 본딩 흔한 문제
- 한쪽 NIC 다운인데 다른 쪽으로 fallback 안 됨 → LACP timeout 설정
- 스위치 측 LAG 설정 안 됨 → 본딩 동작 안 함
- 슬레이브 NIC speed/duplex 불일치 → 본딩 down

## VLAN

### VLAN 설정 위치
- 호스트: bond0.{vlan-id} subinterface (vdsm이 생성)
- 스위치: trunk port 설정 (해당 VLAN 허용)

### 진단
```bash
ip -d link show | grep -A 2 vlan

# 특정 VLAN 트래픽 확인
tcpdump -i bond0.100 -nn -c 50

# 스위치 측 VLAN 통과 여부 (CDP/LLDP)
lldpcli show neighbors
```

### 흔한 문제
- 스위치 측 VLAN 허용 안 됨 → 트래픽 안 통함
- VLAN ID 1, 4095 사용 (예약됨) → 예측 못한 동작
- Native VLAN 충돌

## 방화벽

### 호스트 firewalld
- OLVM 호스트는 firewalld 활성 권장
- vdsm 설치 시 필요 포트 자동 열림

### 필수 포트 (호스트 측)
- 22 (SSH)
- 54321 (vdsm jsonrpc) — Engine에서 호스트로
- 54322 (vdsm SSL)
- 5900-6923 (VNC), 5900-6923 (SPICE) — 콘솔
- 16514 (libvirt-tls) — 마이그레이션
- 49152-49215 (마이그레이션 데이터)
- 80, 443 (HTTP/HTTPS) — Engine 측

### Engine 측 포트
- 80, 443 (콘솔, API)
- 6100 (websocket-proxy)
- 5432 (PostgreSQL, 외부 노출 안 함)

### 방화벽 진단
```bash
# 활성 여부
systemctl status firewalld

# 정책
firewall-cmd --list-all

# 특정 포트 열림 확인
firewall-cmd --query-port=54321/tcp

# 외부 방화벽이 막혔는지 (호스트끼리 또는 Engine-호스트)
nc -zv <대상 IP> 54321
```

## DNS / 호스트명

### OLVM과 DNS
- 호스트는 정/역 DNS 모두 동작해야 안전
- Engine은 FQDN 으로 호스트 등록
- DNS 변경 시 인증서 영향 (CN/SAN이 IP인지 FQDN인지)

### 흔한 문제
- DNS 응답 느림 → vdsm 명령 timeout
- 정 lookup OK인데 역 lookup 실패 → 일부 기능 (HA, 인증서 검증) 문제

## NTP

OLVM에서 가장 중요. 시간 1초 차이도 인증서 문제 유발 가능.

### 권장
- chronyd 사용 (RHEL/OL 8 기본)
- 모든 호스트 + Engine 같은 NTP 소스
- iburst, makestep 옵션

### 진단
```bash
# chronyd
chronyc tracking
chronyc sources

# 시간 차이 확인
for host in host01 host02 host03; do
  echo -n "$host: "
  ssh $host date
done
```

## 마이그레이션 네트워크

### 마이그레이션 시 사용 망
- 클러스터 설정에서 지정한 마이그레이션 망 사용
- 미지정이면 관리망 사용

### 대역폭 제한
- 클러스터 정책에서 동시 마이그레이션 수, 호스트당 bandwidth 제한 가능
- 운영 시간 마이그레이션 시 제한 활용

### 마이그레이션 실패 원인
- CPU Type 비호환 (cluster CPU type 보다 낮은 모델)
- 마이그레이션 네트워크 미설정 또는 단절
- 양쪽 호스트 스토리지 도메인 접근 차이
- VM 메모리가 대상 호스트에서 부족
- VM의 SR-IOV 또는 PCI passthrough (마이그레이션 불가)

## 사이트 간 네트워크 (멀티사이트)

### 일반적 구조
- 사이트 간 운영 트래픽 없음 (각 사이트 독립 OLVM)
- DR 사이트는 별도 (스토리지 복제만)
- 관리 트래픽 (모니터링) 만 사이트 간

### 사이트 식별 헷갈리는 경우
- 사이트마다 별도 사설망 사용하면 IP가 겹칠 수 있음
- 호스트 FQDN 으로 구분
- Bastion 분리 권장

## 네트워크 진단 빠른 체크

```bash
# Engine에서 모든 호스트 통신 확인
for host in host01 host02 host03; do
  echo "=== $host ==="
  ping -c 2 $host
  nc -zv $host 54321
done

# 호스트에서 스토리지 통신
ping <storage_ip>
nc -zv <storage_ip> 2049   # NFS
nc -zv <storage_ip> 3260   # iSCSI

# DNS
nslookup <engine-fqdn>
nslookup -type=PTR <engine-ip>

# 호스트의 ovirtmgmt 인터페이스
ip a show ovirtmgmt
```
