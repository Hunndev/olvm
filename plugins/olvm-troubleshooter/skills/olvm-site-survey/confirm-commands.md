# "모를 때" 안내할 확인 명령어 모음

사용자가 인터뷰 답변을 모르겠다고 할 때 안내. 모두 read-only 안전 명령어.

## OLVM 버전 / 환경

| 알고 싶은 것 | 명령어 | 실행 위치 |
|---|---|---|
| OLVM 버전 | `rpm -q ovirt-engine` | Engine 서버 / SHE Engine VM |
| 호스트의 vdsm 버전 | `rpm -q vdsm` | 각 호스트 |
| Oracle Linux 버전 | `cat /etc/oracle-release` | 모든 노드 |
| 커널 버전 | `uname -r` | 모든 노드 |
| Engine 형태 (SHE 여부) | `hosted-engine --check-deployed` | 호스트 (SHE면 결과 출력) |
| Engine 설정 | `engine-config -g ConfigVersion` | Engine 서버 |

## Engine / 서비스 상태

```bash
# Engine 서비스
systemctl status ovirt-engine ovirt-engine-dwhd ovirt-engine-notifier

# 호스트 데몬
systemctl status vdsmd libvirtd

# SHE HA 데몬
systemctl status ovirt-ha-agent ovirt-ha-broker sanlock

# DB
systemctl status postgresql
```

## SHE 상태

```bash
# 가장 중요한 SHE 상태 확인 명령
hosted-engine --vm-status

# Engine VM 상태
hosted-engine --check-liveliness

# Maintenance Mode 확인
hosted-engine --get-shared-config maintenance --type=he_local
```

## 호스트 하드웨어

```bash
# CPU 모델
lscpu | grep "Model name"

# CPU 패밀리 (마이그레이션 호환성 판단)
cat /proc/cpuinfo | grep "model name" | head -1
cat /proc/cpuinfo | grep -E "vendor_id|cpu family|model[^ ]*\s*:" | head -3

# NUMA 토폴로지
numactl --hardware

# 메모리
free -h
cat /proc/meminfo | head -5

# 디스크
df -h
lsblk

# 시리얼 / 모델 (Dell)
dmidecode -s system-serial-number
dmidecode -s system-product-name
```

## 네트워크

```bash
# IP, 인터페이스
ip a
ip -br link

# 라우팅
ip r

# 본딩 상태
cat /proc/net/bonding/bond0   # bond1, bond2 등 있으면 각각

# VLAN
ip -d link show | grep -A 2 vlan

# 방화벽
systemctl status firewalld
firewall-cmd --list-all

# DNS
cat /etc/resolv.conf
nslookup olvm.example.local   # 콘솔 URL로 테스트

# NTP
chronyc sources
chronyc tracking
```

## 스토리지

```bash
# OLVM 스토리지 도메인
vdsm-tool list-domains

# 마운트
mount | grep -E 'nfs|iscsi|gluster'
df -h

# 멀티패스 (FC/iSCSI)
multipath -ll
multipath -v3 | head -20

# iSCSI 세션
iscsiadm -m session

# NFS 통계
nfsiostat 1 2   # 2회 측정
```

## VM / Libvirt

```bash
# OLVM이 관리하는 VM 목록 (호스트에서)
vdsm-client Host getVMList

# Libvirt 레벨 VM 목록
virsh list --all

# 특정 VM 정의 (XML)
virsh dumpxml <vm-uuid>

# QEMU 프로세스
ps -ef | grep qemu-kvm | head -5

# VM의 CPU 핀
taskset -pc <qemu-pid>
```

## 로그 빠른 확인 (최근 1시간)

```bash
# Engine 로그
journalctl -u ovirt-engine --since "1 hour ago" -p err
tail -100 /var/log/ovirt-engine/engine.log

# vdsm
journalctl -u vdsmd --since "1 hour ago" -p err
tail -100 /var/log/vdsm/vdsm.log

# Libvirt
tail -100 /var/log/libvirt/libvirtd.log

# SHE
tail -100 /var/log/ovirt-hosted-engine-ha/agent.log
tail -100 /var/log/ovirt-hosted-engine-ha/broker.log
tail -100 /var/log/sanlock.log

# 커널 (하드웨어 이슈)
dmesg -T | tail -100
```

## 백업

```bash
# Engine 백업 (수동 실행)
engine-backup --mode=backup --file=/backup/engine-$(date +%Y%m%d).tar.gz --log=/tmp/engine-backup.log

# 백업 검증
engine-backup --mode=verify --file=/path/to/backup.tar.gz

# 백업 디렉토리 확인
ls -lh /backup/
```

## 인증서

```bash
# Engine CA
ls -la /etc/pki/ovirt-engine/
openssl x509 -in /etc/pki/ovirt-engine/ca.pem -text -noout | head -20

# 호스트 vdsm 인증서
openssl x509 -in /etc/pki/vdsm/certs/vdsmcert.pem -text -noout | head -20

# 만료일 빠른 확인
for cert in /etc/pki/ovirt-engine/certs/*.cer; do
  echo "$cert: $(openssl x509 -in $cert -enddate -noout)"
done
```

## 사이트 식별 (잘못된 사이트 작업 방지)

작업 시작 전 항상 확인:

```bash
hostname
hostname -f
ip a | grep inet | grep -v 127
```

이 결과가 사이트 .md 의 호스트 인벤토리와 일치하는지 매번 확인.

## 사용 시 주의

- 모든 명령은 read-only. 위험 없음.
- 결과가 길면 폰 카메라로 화면 촬영 OK.
- 결과를 파일로 저장: 명령 뒤에 `> /tmp/result.txt` 추가 후 USB로 가져오기 가능.
- 사용자가 모르면 "이 명령 결과 알려주세요" 안내 후 답변 기다리기. 추측 금지.
