---
schema_version: 1
type: site
company_id: ""
site_code: ""
site_name: ""
region: ""
location: ""
role: "primary"
independence: "fully_independent"
related_sites: []
olvm_version: ""
ol_version: ""
cluster_count: 1
host_count: 0
she_enabled: false
she_host_count: 0
vm_count_approx: 0
risk_level: "medium"
locale: "ko"
last_updated: ""
last_incident: ""
pending_fields: []
offline_visits: []
---

# (회사명) — (사이트 코드) (지역 설명)

> **소속 회사**: [_company.md](./_company.md)  
> **독립도**: (fully_independent / shared_storage / shared_network / shared_auth)

## 사이트 기본 정보
- **사이트 코드**: 
- **위치**: 
- **상면 (Rack)**: 
- **사이트 담당자**: 
- **현장 출입 절차**: 

## 작업 시간대 제약
- **운영 시간**: 
- **점검 윈도우**: 
- **사전 통보 필요 시간**: 

## OLVM 환경
- **OLVM 버전**: 
- **Oracle Linux 버전**: 
- **Engine 형태**: (standalone / SHE)
- **관리 콘솔 URL**: 
- **Data Center 명**: 
- **Cluster 명**: 
- **CPU Type**: 

## 호스트 인벤토리
| 호스트명 | IP | iLO/IPMI | 역할 | CPU | RAM | 디스크 | 비고 |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

## 네트워크
- **관리망(ovirtmgmt)**: VLAN __, 대역 __, GW __
- **VM망**: VLAN __, 대역 __
- **스토리지망**: VLAN __, 대역 __, 분리 여부: 
- **마이그레이션망**: VLAN __, 대역 __, 분리 여부: 
- **본딩**: 모드 __, NIC __
- **방화벽 정책 담당**: 

## 스토리지
- **종류**: (NFS / iSCSI / FC / Gluster)
- **벤더/모델**: 
- **마운트 정보**:
  - Data Domain: 
  - Hosted Engine Domain: 
  - 기타: 
- **백업 스토리지**: 
- **여유 용량 임계치**: 

## 인증/접속
- **콘솔 URL**: 
- **관리자 계정**: (비밀번호는 별도 보안 저장소)
- **LDAP/AD 연동**: 
- **호스트 SSH**: 
- **Bastion**: 

## 백업
- **Engine 백업 주기**: 
- **백업 보존**: 
- **백업 위치**: 
- **마지막 복구 테스트**: 

## 모니터링
- **솔루션**: 
- **호스트 그룹**: 
- **알림 채널**: 
- **주요 알람 임계치**: 

## 알려진 이슈
- 

## 작업 이력
| 일자 | 작업 | 작업자 | 결과 | 비고 |
|---|---|---|---|---|
|  |  |  |  |  |

## 변경 시 주의사항
- 

## 비상시 의사결정
- **SHE 다운 시**: 
- **SPM 강제 변경**: 
- **호스트 fence**: 
