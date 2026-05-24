# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab IaC for walle (Proxmox VE 9.2) — OpenTofu로 VM/LXC 프로비저닝, Talos로 K8s 클러스터, Ansible로 애플리케이션 배포.

## Architecture

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 100: talos-master (K8s control-plane)
├── VM 101: talos-worker (K8s worker)
└── LXC 200: heritage (Debian 12, Docker Compose 미디어 서버)
```

**프로비저닝 흐름:** OpenTofu → talhelper/talosctl → Ansible

## Full Provisioning Workflow

```bash
# 1. OpenTofu — VM/LXC 생성 (Talos VM은 started=false로 생성됨)
cd proxmox/opentofu && tofu apply -auto-approve
tofu output  # MAC 주소 확인

# 2. VM 시작 + boot order 수정 (CDROM 우선)
ssh root@walle.bun-bull.ts.net "qm set 100 --boot order=ide2; qm set 101 --boot order=ide2; qm start 100; qm start 101"

# 3. DHCP IP 확인 → hosts.ini, talconfig.yaml 갱신
ssh arv "cat /tmp/dhcp.leases" | grep "<MAC>"

# 4. Talos 부트스트랩
cd k8s && talhelper genconfig
talosctl apply-config --nodes <MASTER_IP> --file clusterconfig/homelab-talos-master.yaml --insecure
talosctl apply-config --nodes <WORKER_IP> --file clusterconfig/homelab-talos-worker.yaml --insecure
talosctl bootstrap --nodes <MASTER_IP>

# 5. Ansible — heritage 배포
cd proxmox/ansible && ansible-playbook playbooks/heritage.yml
```

## Other Commands

```bash
# Secrets — sops 암호화/복호화
cd proxmox/opentofu
sops -d secrets.sops.yaml              # 복호화 (평문 출력)
sops -e plain.yaml > secrets.sops.yaml # 암호화

# 템플릿 재생성 (walle에서)
ssh root@walle.bun-bull.ts.net 'bash -s' < scripts/create-talos-template.sh
```

## Key Constraints

- **Provider:** bpg/proxmox v0.106+ (v0.70 API와 호환되지 않음). Container 리소스는 `initialization`, `operating_system`, `disk` 블록 사용 (구 `hostname`, `ostemplate`, `rootfs` 불가)
- **Talos VM:** QEMU guest agent 미지원 → `started = false`로 생성 후 수동 시작. 부팅 순서 `ide2`(CDROM) 우선 필요
- **Endpoint:** `walle.bun-bull.ts.net:8006` (Tailscale). `insecure = true` 필요 (자가 서명 인증서)
- **Secrets:** `proxmox/opentofu/secrets.sops.yaml` — age 키로 sops 암호화. API Token 형식: `root@pam!<token-name>=<secret>`
- **SSH:** `ssh root@walle.bun-bull.ts.net` (root 접속). SSH config의 `Host walle`은 user=crong이라 root 명령어 불가
- **DHCP IP 조회:** `ssh arv "cat /tmp/dhcp.leases"` — 공유기(OpenWrt)에서 VM MAC 주소로 IP 매핑

## File Layout

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 (provider, variables, talos.tf, heritage.tf, outputs.tf) |
| `proxmox/ansible/` | Ansible 설정, 인벤토리, 플레이북 |
| `k8s/talconfig.yaml` | talhelper 클러스터 설정 |
| `scripts/` | Proxmox 호스트 실행 스크립트 (템플릿 생성 등) |
| `.sops.yaml` | sops 암호화 규칙 (age 키) |

## Gotchas

- **Boot order:** Talos VM 클론 후 `boot order=scsi0`(빈 디스크)로 설정됨. `qm set <ID> --boot order=ide2`로 CDROM 부팅으로 변경해야 Talos ISO가 로드됨. 이후 talosctl apply-config로 설치하면 디스크 부팅으로 전환됨
- **.terraform.lock.hcl:** `.gitignore`에 있지만 재현 가능한 빌드를 위해 커밋 권장. 필요시 gitignore에서 제거
- **DHCP IP:** `hosts.ini`, `talconfig.yaml` IP는 공유기 DHCP 기반. VM 재생성 시 `ssh arv "cat /tmp/dhcp.leases"`로 MAC→IP 매핑 후 갱신
- **Heritage bind mount:** `/mnt/data1`, `/mnt/data2`는 walle에 디스크 설정 후 `heritage.tf`에 `mount_point` 블록 추가 필요
- **Proxmox 초기 설정:** 재설치 후 enterprise repo 비활성화 필요 (`pve-enterprise.sources` → `.disabled`). no-subscription repo는 trixie(PVE 9) 사용: `deb http://download.proxmox.com/debian/pve trixie pve-no-subscription`
- **LXC 템플릿:** `pveam update && pveam download local <template-name>` — Proxmox에서 LXC용 OS 템플릿 다운로드. `pveam available --section system`으로 목록 확인
