# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab IaC for walle (Proxmox VE 9.2) — OpenTofu로 VM/LXC 프로비저닝, Talos로 K8s 클러스터, Ansible로 애플리케이션 배포.

## Architecture

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 100: talos-master (K8s control-plane)
├── VM 101: talos-worker (K8s worker)
└── LXC 200: heritage (Debian 12, Docker + Tailscale Serve)
    ├── Traefik (L7 reverse proxy, port 9080)
    ├── Homepage (dashboard)
    ├── Transmission (torrent)
    ├── Jellyfin (streaming)
    ├── Gatus (uptime monitoring)
    └── Beszel (hw monitoring)
```

**프로비저닝 흐름:** OpenTofu → talhelper/talosctl → Ansible

**외부 접속:** `tailscale serve`(443→9080) → Traefik(L7 리버스 프록시) → 각 서비스. TLS 종료는 Tailscale이 처리.

**서비스 접속 URL** (Tailnet 내에서만 접근):

| 서비스 | URL | 비고 |
| :--- | :--- | :--- |
| Homepage | `https://heritage.bun-bull.ts.net/` | 대시보드 |
| Jellyfin | `https://heritage.bun-bull.ts.net/jellyfin` | 스트리밍 |
| Transmission | `https://heritage.bun-bull.ts.net/transmission` | 토렌트 |
| Beszel | `https://heritage.bun-bull.ts.net/beszel` | HW 모니터링 |
| Gatus | `http://heritage.bun-bull.ts.net:8088` | SPA subpath 미지원, 직접 접속 |
| Proxmox UI | `https://walle.bun-bull.ts.net` | Tailscale Serve(443→8006) |
| K8s API | `https://192.168.221.172:6443` | 내부망만 |

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
cd k8s && talhelper gensecret > talsecret.yaml  # 최초 1회
talhelper genconfig
talosctl apply-config --nodes <MASTER_IP> --file clusterconfig/homelab-talos-master.yaml --insecure
talosctl apply-config --nodes <WORKER_IP> --file clusterconfig/homelab-talos-worker.yaml --insecure
TALOSCONFIG=clusterconfig/talosconfig talosctl --endpoints <MASTER_IP> --nodes <MASTER_IP> bootstrap
TALOSCONFIG=clusterconfig/talosconfig talosctl --endpoints <MASTER_IP> --nodes <MASTER_IP> kubeconfig ~/.kube/homelab.config --force

# 5. Ansible — heritage 배포
cd proxmox/ansible && ansible-playbook playbooks/heritage.yml
```

## Other Commands

```bash
# OpenTofu 초기화 및 검증
cd proxmox/opentofu && tofu init
tofu validate

# Secrets — sops 암호화/복호화
sops -d secrets.sops.yaml              # 복호화 (평문 출력)
sops -e plain.yaml > secrets.sops.yaml # 암호화

# 템플릿 재생성 (walle에서)
ssh root@walle.bun-bull.ts.net 'bash -s' < scripts/create-talos-template.sh
```

## Day-to-Day Operations

```bash
# K8s 클러스터 상태
KUBECONFIG=~/.kube/homelab.config kubectl get nodes -o wide
KUBECONFIG=~/.kube/homelab.config kubectl get pods -A

# Heritage 서비스 재시작
ssh heritage "cd /opt/heritage && docker compose restart <service>"

# Heritage 로그 확인
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 <service>"

# Heritage 파일 권한 확인
ssh crong@walle.bun-bull.ts.net "ls -la /mnt/data1/torrent/ /mnt/data2/torrent/"

# Heritage 파일 소유권 변경 (호스트에서 UID 101000 사용)
ssh crong@walle.bun-bull.ts.net "chown -R 101000:101000 /mnt/data1/torrent/ /mnt/data2/torrent/"

# Talos 노드 재부팅 / kubelet 재시작
TALOSCONFIG=k8s/clusterconfig/talosconfig talosctl --endpoints 192.168.221.172 --nodes 192.168.221.172 reboot
TALOSCONFIG=k8s/clusterconfig/talosconfig talosctl --endpoints 192.168.221.172 --nodes 192.168.221.172 service kubelet restart

# Proxmox VM/LXC 상태
ssh root@walle.bun-bull.ts.net "qm list; pct list"
```

## Key Constraints

- **Provider:** bpg/proxmox v0.106+ (v0.70 API와 호환되지 않음). Container 리소스는 `initialization`, `operating_system`, `disk` 블록 사용 (구 `hostname`, `ostemplate`, `rootfs` 불가)
- **Talos VM:** QEMU guest agent 미지원 → `started = false`로 생성 후 수동 시작. 설치 후 반드시 `qm set <ID> --boot order=scsi0`로 디스크 부팅 전환 (Gotchas 참조)
- **Endpoint:** `walle.bun-bull.ts.net:8006` (Tailscale). `walle.bun-bull.ts.net` (443, Tailscale Serve). `insecure = true` 필요 (자가 서명 인증서)
- **Secrets:** `proxmox/opentofu/secrets.sops.yaml` — age 키로 sops 암호화. API Token 형식: `root@pam!<token-name>=<secret>`
- **SSH:** `ssh root@walle.bun-bull.ts.net` (root 접속). SSH config의 `Host walle`은 user=crong이라 root 명령어 불가
- **Heritage SSH:** `ssh crong@walle.bun-bull.ts.net` (UID 101000, sudo 권한 포함). 파일 시스템 관리용 사용자
- **DHCP IP 조회:** `ssh arv "cat /tmp/dhcp.leases"` — 공유기(OpenWrt)에서 VM MAC 주소로 IP 매핑

## File Layout

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 (provider, variables, talos.tf, heritage.tf, outputs.tf) |
| `proxmox/ansible/` | Ansible 설정, 인벤토리, 플레이북 |
| `proxmox/ansible/inventory/hosts.ini` | 인벤토리 (플레이북과 그룹명 1:1 매핑: proxmox_hosts, heritage_hosts, talos) |
| `proxmox/ansible/playbooks/walle.yml` | walle Tailscale Serve 설정 (443→8006) |
| `heritage/` | Heritage 미디어 서버 Docker Compose 설정 (compose.yml, homepage, gatus) |
| `heritage/traefik/` | Traefik L7 리버스 프록시 설정 (static + dynamic YAML) |
| `k8s/talconfig.yaml` | talhelper 클러스터 설정 |
| `k8s/talsecret.yaml` | 클러스터 시크릿 (gitignore, 분실 시 재부트스트랩 필요) |
| `k8s/clusterconfig/` | talhelper 생성 산출물 — machine config + talosconfig (gitignore) |
| `scripts/` | Proxmox 호스트 실행 스크립트 (템플릿 생성 등) |
| `docs/` | 문서 (architecture.md, specs, plans) |
| `.mcp.json` | MCP 서버 설정 — proxmox, k8sgpt (kubeconfig: `~/.kube/homelab.config`) |
| `.sops.yaml` | sops 암호화 규칙 (age 키) |

## Gotchas

- **Bash CWD:** `cd proxmox/ansible && ...` 실행 후 CWD가 변경됨. 후속 git 명령어는 반드시 절대 경로 또는 `cd /Users/crong/git/homelab &&` 선행 필요
- **Heritage LXC UID 매핑:** LXC 200은 unprivileged → 컨테이너 UID N → 호스트 UID 100000+N 매핑. 현재 crong 사용자 UID 101000은 컨테이너 내 UID 1000으로 매핑됨
- **Transmission/Jellyfin 권한:** 호스트 `/mnt/data{1,2}/torrent/`는 UID 101000:101000 소유(권한 700). Transmission(PUID=1000)과 Jellyfin(user:1000:1000)이 동일 UID 사용
- **Proxmox HTTP 검증:** `curl -sI`(HEAD)는 501 반환. GET으로 검증: `curl -s -o /dev/null -w "%{http_code}" https://walle.bun-bull.ts.net`
- **Boot order:** Talos VM 클론 후 `boot order=scsi0`(빈 디스크)로 설정됨. 최초 부팅만 `qm set <ID> --boot order=ide2`로 CDROM 부팅하여 ISO 로드 → `talosctl apply-config --insecure`로 설치 후 `qm set <ID> --boot order=scsi0`로 디스크 부팅 전환 필요
- **.terraform.lock.hcl:** `.gitignore`에 있지만 재현 가능한 빌드를 위해 커밋 권장. 필요시 gitignore에서 제거
- **DHCP IP:** `hosts.ini`, `talconfig.yaml` IP는 공유기 DHCP 기반. VM 재생성 시 `ssh arv "cat /tmp/dhcp.leases"`로 MAC→IP 매핑 후 갱신
- **Heritage bind mount:** `/mnt/data1`, `/mnt/data2`는 walle에 디스크 설정 후 `heritage.tf`에 `mount_point` 블록 추가 필요
- **Heritage LXC:** `/dev/net/tun` 디바이스 패스스루 + `keyctl=true` 필요 (Tailscale용). `heritage.tf`에 이미 설정됨
- **Heritage 외부 접속:** `heritage.bun-bull.ts.net` — Tailscale LXC 호스트 설치 + `tailscale serve`로 path-based 라우팅 (Caddy 불필요)
- **Traefik 라우팅:** Tailscale Serve(443→9080) → Traefik → 서비스. Gatus는 SPA subpath 미지원으로 Traefik 라우팅 제외, `:8088` 직접 접속
- **Tailscale Serve HTTPS 백엔드:** 자가 서명 인증서 백엔드는 `https+insecure://` 스킴 사용 필요 (일반 `https://`는 502 에러)
- **Proxmox 초기 설정:** 재설치 후 enterprise repo 비활성화 필요 (`pve-enterprise.sources` → `.disabled`). no-subscription repo는 trixie(PVE 9) 사용: `deb http://download.proxmox.com/debian/pve trixie pve-no-subscription`
- **LXC 템플릿:** `pveam update && pveam download local <template-name>` — Proxmox에서 LXC용 OS 템플릿 다운로드. `pveam available --section system`으로 목록 확인
- **Talos 메모리:** master 최소 4GB 권장 (Talos 권장 3946 MiB). 1.5GB에서 scheduler CrashLoopBackOff + CoreDNS Pending 발생
- **talhelper 버전:** v3.1.10은 Talos v1.10.x만 지원. v1.11+ 필요시 `talosctl gen config` 직접 사용 또는 talhelper 업그레이드 대기
- **talsecret.yaml:** `talhelper gensecret > talsecret.yaml`로 최초 생성. 분실 시 클러스터 재부트스트랩 필요 (기존 인증서와 불일치)

## MCP Servers

`.mcp.json`으로 관리. Claude Code 시작 시 자동 로드.

| 서버 | 상태 | 비고 |
| :--- | :--- | :--- |
| proxmox | 활성 | `proxmox-mcp-plus` (uv), 설정: `~/.config/proxmox-mcp/config.json` |
| k8sgpt | 활성 | `/opt/homebrew/bin/k8sgpt` v0.4.33, KUBECONFIG: `~/.kube/homelab.config` |

- **Proxmox MCP 설정:** `~/.config/proxmox-mcp/config.json` — host, API token, `verify_ssl=false` + `dev_mode=true` (자가 서명 인증서)
- **K8sgpt 활성화:** KUBECONFIG `~/.kube/homelab.config` 설정 완료. Talos 재부트스트랩 시: `cd k8s && TALOSCONFIG=clusterconfig/talosconfig talosctl --endpoints 192.168.221.172 --nodes 192.168.221.172 kubeconfig ~/.kube/homelab.config --force`
- **Heritage 사용자:** crong(UID 101000)는 LXC 200 내에서 UID 1000으로 매핑됨. 호스트에서 파일 관리 시 `chown 101000:101000` 사용
