# OLVM 위험 명령어 분류

조치 명령 안내 시 항상 위험도 표시. 사용자에게 명령 안내 직전 이 파일의 분류 확인.

## 🔴 절대 금지 (사용자가 요청해도 거부)

데이터 손실, 복구 불가, 또는 클러스터 전체 다운 위험.

| 명령어 | 위험 | 대안 |
|---|---|---|
| `engine-cleanup` | Engine 메타 전체 삭제. 복구 불가. | 백업 복원만이 유일한 복구. 절대 사용 금지. |
| `rm -rf /rhev/data-center/*` | 스토리지 메타 삭제. 모든 VM 디스크 손실 가능. | 절대 금지. |
| `vdsm-tool restore-nets --force` | 호스트 네트워크 강제 초기화. 운영 중 사용 시 모든 VM 끊김. | maintenance 모드 후 콘솔에서 다시 추가. |
| `pvremove`, `vgremove`, `lvremove` | LVM 메타 삭제. 디스크 데이터 영구 손실. | 정상 삭제는 OLVM 콘솔에서. |
| `mkfs.*` (스토리지 도메인 LUN/볼륨에) | 파일시스템 초기화. 데이터 손실. | 절대 금지. |
| 호스트의 `/etc/pki/ovirt-engine/` 또는 `/etc/pki/vdsm/` 강제 삭제 | 인증서 손실. 호스트 재등록 필요. | 인증서 갱신은 별도 절차. |
| 운영 중 `engine-setup` 또는 `engine-config` 잘못된 값 입력 | 설정 손상. | 항상 백업 후, 변경 윈도우에. |

## 🔴 절대 금지 (운영 중)

운영 시간에는 금지. 점검 윈도우 + L3/PM 승인 후만.

- 호스트 재부팅 (운영 VM 영향)
- `systemctl stop vdsmd` (해당 호스트 VM 모두 끊김)
- `systemctl stop libvirtd` (호스트의 VM 모두 끊김)
- `iptables -F` / `firewall-cmd --reload` (네트워크 끊김 가능)
- NetworkManager 또는 network 서비스 재기동
- 스토리지 마운트 강제 해제 (`umount -f`)

## 🟡 L3 협의 후 (영향 큼)

서비스 영향 가능. L3 엔지니어 또는 PM 승인 후 진행. 결과 즉시 확인 가능해야 함.

### 호스트 데몬 재기동
- `systemctl restart vdsmd`
  - 영향: 해당 호스트의 VM은 동작 유지되나 vdsm 재초기화 중 OLVM 콘솔에서 Non-Responsive 표시
  - 결과 확인: `systemctl status vdsmd`, `journalctl -u vdsmd -n 50`
  - 대안: 먼저 supervdsm 재기동 시도 (`systemctl restart supervdsmd`)

- `systemctl restart libvirtd`
  - 영향: VM은 유지되나 libvirt 재초기화. 짧은 시간 콘솔/마이그레이션 불가.
  - 결과 확인: `systemctl status libvirtd`, `virsh list --all`

- `systemctl restart ovirt-ha-agent ovirt-ha-broker`
  - SHE 환경 한정. ha-agent 재기동은 HE 모니터링 잠시 중단.
  - Engine VM 자체는 영향 없음.

### Engine 재기동
- `systemctl restart ovirt-engine`
  - 영향: 웹 콘솔 + API 끊김 (1-2분). VM 동작 자체는 영향 없음.
  - 사전 작업: 진행 중인 작업(마이그레이션, 스냅샷) 없는지 확인.
  - 결과 확인: `systemctl status ovirt-engine`, 콘솔 로그인 가능 여부.

### SHE Engine 강제 종료
- `hosted-engine --vm-poweroff`
  - 영향: Engine VM 강제 다운. HA가 다른 호스트에서 자동 부팅 시도.
  - 사전: 정상 종료(`hosted-engine --vm-shutdown`) 먼저 시도. 그래도 안 되면 사용.

- `hosted-engine --vm-shutdown`
  - 정상 종료. 우선 시도.

### Fence
- `fence_ipmilan ... -o off` 또는 콘솔에서 호스트 fence
  - 영향: 해당 호스트 전원 차단. 그 호스트의 VM 전부 다운.
  - 사전: 다른 호스트로 VM 마이그레이션 시도. 정상 호스트면 절대 fence X.
  - SHE 호스트 fence는 더 위험 (HE 영향 가능).

### VM 강제 종료
- `virsh destroy <vm>`
  - 영향: VM 즉시 종료. 데이터 손상 가능 (write-back 캐시 등).
  - 사전: Engine UI에서 shutdown 시도 → poweroff → 그래도 안 되면 virsh destroy.

### SPM 강제 변경
- 콘솔에서 SPM 강제 변경
  - 영향: 진행 중 스토리지 작업 중단. SPM 자동 인계 정상 동작 안 할 때만.

### 스토리지 도메인 maintenance
- 콘솔에서 스토리지 도메인 maintenance 전환
  - 영향: 해당 도메인의 VM 모두 paused.
  - 점검 윈도우 필수.

### 마이그레이션망 변경, 본딩 변경
- 호스트 네트워크 구성 변경
  - maintenance 모드 후 진행.

## 🟢 안전 (조회만)

진단 시 자유롭게 사용. read-only.

### 서비스 상태
- `systemctl status <service>`
- `systemctl is-active <service>`
- `journalctl -u <service> --since "1 hour ago"`

### OLVM 조회
- `hosted-engine --vm-status`
- `hosted-engine --check-deployed`
- `hosted-engine --check-liveliness`
- `engine-config -g <key>` (조회만, set 아님)
- `engine-config --all` (전체 설정 조회)
- `vdsm-tool list-domains`
- `vdsm-tool list-nics`
- `vdsm-client Host getVMList`
- `vdsm-client Host getVdsCapabilities`

### Libvirt 조회
- `virsh list --all`
- `virsh dumpxml <vm-uuid>`
- `virsh domstats <vm>`

### 시스템 조회
- `uptime`, `date`, `hostname`
- `df -h`, `free -h`, `lscpu`, `lsblk`
- `ip a`, `ip r`, `ss -tlnp`
- `multipath -ll`, `iscsiadm -m session`
- `dmesg | tail`, `journalctl --since "1 hour ago"`
- `cat /proc/net/bonding/bond0`

### 로그 조회
- `tail`, `head`, `less`, `cat` 으로 로그 파일 읽기
- `grep`, `awk` 로 패턴 검색
- `find /var/log/ovirt-engine -name "*.log" -mtime -1`

### 백업 (조회)
- `engine-backup --mode=verify --file=<path>` — 검증만, 복원 아님
- 백업 디렉토리 ls

## 안내 규칙

Claude가 명령어 안내 시 항상:

1. **위험도 prefix**: `🟢` / `🟡` / `🔴` 명시
2. **사이트/호스트 prefix**: `[seoul-dc01/host03]`
3. **영향 설명**: 한 줄로 "이 명령은 어떤 영향을 줍니다" 명시
4. **사전 확인**: 위험 명령 안내 시 "사전에 X 확인" 항목 추가
5. **결과 확인**: 명령 후 어떻게 정상 확인할지 안내

### 예시

```
🟡 L3 협의 후 [seoul-dc01/host03] systemctl restart vdsmd

영향: 이 호스트의 VM은 동작 유지되나 OLVM 콘솔에서 1-2분간 Non-Responsive 표시.
사전 확인:
  - 진행 중 마이그레이션 없음 (콘솔 > Tasks)
  - 다른 호스트는 모두 정상
결과 확인:
  - systemctl status vdsmd → active
  - OLVM 콘솔에서 호스트 Up 상태 복귀
```

## 사용자가 위험 명령 요청 시

사용자가 🔴 명령을 실행해달라고 하면:
1. 거부
2. 위험 사유 설명
3. 대안 제시
4. 정말 필요하면 L3/PM 승인 후 사용자가 직접 실행하도록 안내

사용자가 🟡 명령을 실행해달라고 하면:
1. 위험도와 영향 명확히 안내
2. 사전 확인 항목 제시
3. L3/PM 승인 받았는지 확인
4. 진행 시 결과 확인 방법 안내
