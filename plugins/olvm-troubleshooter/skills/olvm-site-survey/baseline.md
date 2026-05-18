# OLVM 정상 베이스라인

사이트 등록 답변을 검증하는 기준. 답변이 이 베이스라인에서 벗어나면 Claude가 재확인 또는 우려 사항 기록.

## OLVM 버전

- 지원 종료된 버전: 4.3 이하 (Oracle 지원 만료) → 우려 사항 기록
- 권장: 4.4.x 또는 4.5.x
- OLVM 버전과 OL 버전 매트릭스:
  - OLVM 4.4 → OL 8.x
  - OLVM 4.5 → OL 8.6 이상
- 호스트와 Engine의 버전 차이가 1 마이너 이상이면 마이그레이션/HA 문제 가능

## Engine 형태 vs 호스트 수

| Engine 형태 | 최소 호스트 | 권장 | 비고 |
|---|---|---|---|
| Standalone | 1 (호스트 1대 가능, HA 없음) | 2 이상 | Engine 서버는 별도 |
| SHE | 2 (HA 위해 최소) | 3 이상 | SHE 호스트만 카운트 |

- SHE인데 SHE 호스트 1대 → HA 불가, 단일 장애점. 위험 표시.
- SHE 호스트 3대 미만에서 maintenance 시 quorum 깨질 수 있음 안내.

## 호스트 CPU

- 클러스터 내 호스트는 같은 CPU 패밀리여야 라이브 마이그레이션 가능
- 클러스터 CPU Type이 'Lowest Common Denominator'로 설정되면 모든 호스트 호환되지만 성능 손실
- 다른 패밀리(Intel/AMD 혼재)는 클러스터 분리 권장

## RAM

- 호스트당 최소 16GB (OLVM 자체 + 최소 VM)
- 권장: 운영 VM 메모리 총합의 1.3배 이상 (overcommit 여유 + 1대 fail 대응)
- 마지막 호스트 1대 다운 시 남은 호스트가 모든 VM 수용 가능한가 (N+1 원칙)

## 네트워크

### 망 분리 권장
| 망 종류 | 분리 권장 | 미분리 시 영향 |
|---|---|---|
| 관리망(ovirtmgmt) | 필수 분리 | (그 자체로 분리망) |
| VM망 | 분리 권장 | VM 트래픽이 관리에 영향 |
| 스토리지망 | **강력 분리 권장** | 스토리지 부하가 관리 끊김 유발, 호스트 Non-Responsive 위험 |
| 마이그레이션망 | 분리 권장 | 운영 시간 마이그레이션 시 관리망 부하 |

스토리지망 미분리는 항상 risk_level 'high' 사유.

### VLAN ID
- 1, 4095 예약 (사용 금지)
- 호스트와 스위치 양쪽 VLAN 설정 일치 필요

### 본딩
- LACP: 스위치 LAG 설정 필요. 양쪽 일치 확인.
- active-backup: 스위치 설정 불필요. 가장 안전한 기본.
- balance-rr / balance-xor: VM 트래픽에는 부적합 (패킷 순서 문제)

## 스토리지

### 종류별 일반 사항
- **NFS**: 가장 단순. NFSv3 vs NFSv4 차이 (lock 동작). NFSv4 권장.
- **iSCSI**: 멀티패스 필수. CHAP 인증 권장.
- **FC SAN**: 멀티패스 필수. WWPN 영역 분리 확인.
- **Gluster**: 노드 수 3 이상, replica 3 권장.

### 도메인
- Data Domain: 1개 이상 필수
- Hosted Engine Domain: SHE인 경우 필수, 별도 도메인으로 분리 권장 (Data Domain과 같이 두면 SPM 전환 시 영향)
- ISO Domain: deprecated. 4.4 이후 Data Domain에 직접 업로드 가능.
- Export Domain: deprecated.

### SPM
- 한 클러스터에 1대만 SPM
- SPM은 디스크 메타데이터 작업(생성/삭제/스냅샷) 책임
- SPM 다운 시 자동 인계 (수 분 소요)

## 인증

- LDAP/AD 연동 권장 (계정 관리 단일화)
- 비연동 시 admin@internal 계정 분실 위험
- 비밀번호는 사이트 .md에 절대 저장하지 않음

## 백업

- Engine 백업 일 1회 이상 권장
- engine-backup 명령 (4.4+ 표준)
- 백업 파일은 별도 스토리지로 외부 복사 권장
- 복구 테스트 분기 1회 권장. 3개월 이상 안 했으면 우려.

## 시간 동기화

- NTP는 OLVM에서 매우 중요 (인증서 검증)
- 모든 호스트와 Engine, 스토리지가 같은 NTP 소스 사용 권장
- 시간 차이 5초 이상 → vdsm-Engine 통신 인증서 오류 가능

## 모니터링

- 최소 모니터링 대상:
  - 호스트 CPU/메모리/디스크
  - 호스트 vdsm/libvirtd 프로세스
  - 스토리지 도메인 상태
  - VM 상태 변화
  - SPM 호스트 변경
- 알람 채널 이중화 권장 (메일 + Slack 등)

## 위험 신호 (자동 risk_level 'high' 사유)

다음 중 하나라도 해당하면 risk_level을 자동 'high'로 올림:

1. SHE 호스트 1대만 (HA 없음)
2. 스토리지망 관리망과 공유
3. 백업 복구 테스트 6개월 이상 미실시
4. 호스트 CPU 패밀리 혼재
5. OLVM 4.3 이하
6. Engine과 호스트 마이너 버전 차이 2 이상
7. 모니터링 미구축
8. 알려진 이슈에 "운영 중 빈번한 vdsm timeout" 등 명시
9. SR-IOV / GPU passthrough VM 존재 (마이그레이션 제약)
