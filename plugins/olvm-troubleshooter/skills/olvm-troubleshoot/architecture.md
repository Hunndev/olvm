# OLVM 아키텍처 — 초급 엔지니어를 위한 구조 이해

## OLVM이란

Oracle Linux Virtualization Manager는 KVM 기반의 가상화 관리 플랫폼이다. 오픈소스 oVirt의 Oracle 공식 배포판.

## 전체 구조

```
┌─────────────────────────────────────────────────────────┐
│              사용자 / 관리자                              │
│  웹 콘솔 / REST API / ovirt-shell                        │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS (443)
                         ▼
┌─────────────────────────────────────────────────────────┐
│            Engine (ovirt-engine)                         │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────────┐│
│  │ JBoss/WildFly│  │ PostgreSQL │  │  PKI / 인증서    ││
│  │ (웹/API)     │  │ (메타 DB)  │  │ /etc/pki/ovirt-..││
│  └──────────────┘  └────────────┘  └──────────────────┘│
└────────────────────────┬────────────────────────────────┘
                         │ vdsm-jsonrpc (TLS 54321)
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Host 1    │  │  Host 2    │  │  Host 3    │
│            │  │            │  │            │
│ ┌────────┐ │  │ ┌────────┐ │  │ ┌────────┐ │
│ │ vdsmd  │ │  │ │ vdsmd  │ │  │ │ vdsmd  │ │
│ ├────────┤ │  │ ├────────┤ │  │ ├────────┤ │
│ │libvirtd│ │  │ │libvirtd│ │  │ │libvirtd│ │
│ ├────────┤ │  │ ├────────┤ │  │ ├────────┤ │
│ │ QEMU   │ │  │ │ QEMU   │ │  │ │ QEMU   │ │
│ │ VMs    │ │  │ │ VMs    │ │  │ │ VMs    │ │
│ └────────┘ │  │ └────────┘ │  │ └────────┘ │
└─────┬──────┘  └─────┬──────┘  └─────┬──────┘
      │               │               │
      └───────────────┼───────────────┘
                      ▼
       ┌─────────────────────────┐
       │      공유 스토리지       │
       │   (NFS / iSCSI / FC)    │
       │  ┌──────────────────┐  │
       │  │ Data Domain      │  │
       │  │   VM 디스크      │  │
       │  │ HE Domain (SHE)  │  │
       │  │   Engine VM 디스크│  │
       │  │ HA 메타데이터    │  │
       │  └──────────────────┘  │
       └─────────────────────────┘
```

## 컴포넌트별 역할

### Engine (ovirt-engine)
"본부" 역할. 모든 명령이 여기서 시작.
- 호스트에게 명령 전달 (VM 시작/정지, 마이그레이션, 디스크 작업)
- 메타데이터는 PostgreSQL에 저장
- standalone (별도 서버) 또는 SHE (클러스터 안의 VM) 두 형태
- 포트: 443 (HTTPS), 80 (HTTP)
- 주요 서비스:
  - `ovirt-engine` — 메인 웹 서버 (JBoss/WildFly)
  - `ovirt-engine-dwhd` — Data Warehouse
  - `ovirt-engine-notifier` — 이메일 알림
  - `postgresql` — DB

### vdsm (Virtual Desktop Server Manager)
각 하이퍼바이저 호스트에서 동작하는 에이전트.
- Engine의 명령을 받아 libvirt에 전달
- 호스트 상태(CPU, 메모리, 네트워크) Engine에 보고
- 죽으면 → 호스트 Non-Responsive 상태로 표시
- 포트: 54321 (jsonrpc TLS)
- 서비스: `vdsmd`, `supervdsmd` (privileged 작업)

### libvirtd
실제로 KVM을 제어하는 표준 라이브러리.
- vdsmd가 libvirtd에게, libvirtd가 QEMU에게 명령
- 서비스: `libvirtd`

### QEMU/KVM
실제 VM 실행 엔진.
- VM 하나당 qemu-kvm 프로세스 하나
- KVM 커널 모듈로 하드웨어 가속

### ovirt-ha-agent / ovirt-ha-broker (SHE만)
Self-Hosted Engine의 HA 책임.
- 호스트들끼리 서로 감시
- Engine VM이 죽으면 다른 호스트에서 자동 부팅
- sanlock으로 단일 인스턴스 보장
- 서비스: `ovirt-ha-agent`, `ovirt-ha-broker`, `sanlock`

## 데이터 흐름 예시: VM 켜기

```
[1] 관리자 웹 콘솔 "VM 시작" 클릭
        │
        ▼ HTTPS POST
[2] Engine
    ├─ DB 조회: VM 정의, 스토리지 도메인, 호스트 상태
    ├─ 스케줄러: 어느 호스트에 띄울지 결정
    └─ 결정된 호스트의 vdsmd 호출 (jsonrpc)
        │
        ▼ TLS 54321
[3] 호스트 vdsmd
    ├─ VM 정의 XML 생성 (Engine에서 받은 정보 + 호스트 capabilities)
    └─ libvirtd 호출
        │
        ▼ libvirt API
[4] libvirtd
    └─ QEMU 프로세스 fork
        │
        ▼ exec
[5] QEMU
    ├─ 공유 스토리지에서 디스크 이미지 읽기 (NFS/iSCSI/FC)
    ├─ KVM 활성화 (CPU/메모리)
    └─ VM 부팅 시작
        │
        ▼ 각 단계 응답 거꾸로 전파
[6] 콘솔에 "Up" 상태 표시
```

## 문제 위치별 증상

| 증상 | 의심 |
|---|---|
| 웹 콘솔 접속 불가 | Engine 서비스, JBoss, DB, 네트워크 |
| 콘솔은 되는데 호스트 Non-Responsive | 호스트 vdsmd, 호스트-Engine 네트워크, 인증서 |
| 호스트 Up인데 VM 안 켜짐 | libvirtd, QEMU, 스토리지 도메인 접근 |
| VM 떠 있는데 콘솔 접속 불가 | WebSocket Proxy, 인증서, VM의 VNC/SPICE |
| 마이그레이션 실패 | CPU 호환성, 마이그레이션 네트워크, 양쪽 호스트 스토리지 접근 |
| 스토리지 작업 실패 | SPM 호스트, 스토리지 도메인 상태 |
| SHE Engine VM 안 뜸 | ovirt-ha-agent, ha-broker, sanlock |

## 인증서 체계

Engine이 자체 CA 운영:
- `/etc/pki/ovirt-engine/ca.pem` — Engine CA
- `/etc/pki/ovirt-engine/certs/*` — 각 컴포넌트 인증서
- `/etc/pki/vdsm/` — vdsm 측 인증서 (Engine CA로 서명됨)

핵심:
- 모든 vdsm-Engine 통신은 TLS
- 시간 동기 안 되면 인증서 검증 실패 → 호스트 Non-Operational
- 인증서 만료 (4년 기본) 사전 갱신 필요
- 호스트 추가 시 Engine이 자동으로 인증서 발급

## 스토리지 도메인 종류

| 종류 | 용도 | 비고 |
|---|---|---|
| Data Domain | VM 디스크, 스냅샷 | 1개 이상 필수 |
| ISO Domain | 설치 이미지 | deprecated (4.4+ Data Domain에 통합) |
| Export Domain | VM 백업/이전 | deprecated |
| Hosted Engine Domain | SHE의 Engine VM 디스크, HA 메타 | SHE 전용, Data Domain과 분리 권장 |

## SPM (Storage Pool Manager)

- 클러스터 내 단 한 대의 호스트가 SPM 역할
- 스토리지 메타데이터 변경 (디스크 생성/삭제, 스냅샷) 책임
- SPM 호스트 죽으면 다른 호스트가 자동 인계 (수 분)
- VM 동작 자체에는 영향 없음 (VM은 직접 스토리지 접근)
- SPM lease는 스토리지 도메인 자체에 기록 (sanlock 기반)

## 클러스터 / 데이터센터 계층

```
Data Center
└── Cluster (CPU Type, Compatibility Version 공유)
    └── Hosts (1대 이상)

Cluster 단위:
- CPU Type (마이그레이션 호환성)
- 네트워크 정의
- 스케줄링 정책
- Compatibility Version (OLVM 기능 레벨)

Data Center 단위:
- 스토리지 도메인 집합
- 호환성 버전
```

## 진단 시 항상 확인할 5가지

문제 상황이 무엇이든 다음 5가지부터:

1. **시간 동기** — `date` 모든 노드, NTP 정상
2. **인증서** — 만료 여부, `/etc/pki/` 변경 이력
3. **네트워크** — Engine ↔ 호스트, 호스트 ↔ 스토리지 통신 정상
4. **공간** — Engine `/var`, 호스트 `/var/log`, 스토리지 도메인 여유
5. **서비스 상태** — Engine, vdsm, libvirtd 모두 active

이 다섯이 정상인데 문제 있으면 그때부터 상세 진단.
