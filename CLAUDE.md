# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab IaC for walle (Proxmox VE 9.2) — OpenTofu로 VM/LXC 프로비저닝, Ansible로 애플리케이션/관리 도구 배포.

## Architecture

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 102: cockpit (Ubuntu 24.04 LTS, Cockpit + PatchMon + Tailscale Serve)
│   ├── Cockpit (systemd socket, :9090 loopback only)
│   └── PatchMon (Docker Compose 4컨테이너, :3000 loopback only)
├── LXC 200: heritage (Debian 12, Docker + Tailscale Serve)
│   ├── Caddy (L7 reverse proxy, port 9080)
│   ├── Homepage (dashboard)
│   ├── Transmission (torrent)
│   ├── Jellyfin (streaming)
│   └── Aria2 (다운로드 매니저, port 6800)
└── templates: 900 talos-template (미사용), 901 ubuntu-2404-template (cockpit clone 원본)
```

> K8s 클러스터(talos 100/101)는 2026-07-06 사용자 의도적 삭제됨. `k8s/` 디렉토리(talconfig.yaml)는 잔재.

**프로비저닝 흐름:** OpenTofu → cloud-init(최소) → Ansible

**외부 접속:** `tailscale serve`(443→백엔드)로 Tailscale이 TLS 종료.

**서비스 접속 URL** (Tailnet 내에서만 접근):

| 서비스 | URL | 비고 |
| :--- | :--- | :--- |
| Homepage | `https://heritage.bun-bull.ts.net/` | 대시보드 |
| Jellyfin | `https://heritage.bun-bull.ts.net/jellyfin` | 스트리밍 |
| Transmission | `https://heritage.bun-bull.ts.net/transmission` | 토렌트 |
| Proxmox UI | `https://walle.bun-bull.ts.net` | Tailscale Serve(443→8006) |
| Cockpit | `https://cockpit.bun-bull.ts.net` | Tailscale Serve(443→https+insecure://localhost:9090) |
| PatchMon | `https://cockpit.bun-bull.ts.net:8443` | 패치 모니터링, Tailscale Serve(8443→http://localhost:3000) |
| Aria2 RPC | `ws://heritage.bun-bull.ts.net:6800/jsonrpc` | 다운로드 매니저, RPC Secret: P3TERX |

## Full Provisioning Workflow

### Cockpit VM (신규)

```bash
# 0. Ubuntu template 생성 (최초 1회, walle에서)
ssh crong@walle.bun-bull.ts.net 'sudo bash -s' < scripts/create-ubuntu-template.sh

# 1. OpenTofu — cockpit VM 102 생성 (Ubuntu cloud image clone, started=true)
cd proxmox/opentofu && source /home/deck/git/247365/.env && tofu apply -auto-approve
tofu output  # MAC/IP 확인 (agent 기반, null이면 DHCP fallback)

# 2. DHCP IP 확인 → hosts.ini 갱신 (agent IP 미수집 시)
ssh arv "cat /tmp/dhcp.leases" | grep "<MAC>"

# 3. Ansible — cockpit role 배포
cd proxmox/ansible && ansible-playbook playbooks/cockpit.yml
```

### Heritage LXC

```bash
cd proxmox/opentofu && source /home/deck/git/247365/.env && tofu apply -auto-approve
cd proxmox/ansible && ansible-playbook playbooks/heritage.yml
```

## Other Commands

```bash
# OpenTofu 초기화 및 검증 (R2 자격 증명 필요)
# 주의: 실행 전 반드시 `source /home/deck/git/247365/.env` 실행 필요
cd proxmox/opentofu && tofu init
tofu validate

# Secrets — sops 암호화/복호화
sops -d secrets.sops.yaml              # 복호화 (평문 출력)
sops -e plain.yaml > secrets.sops.yaml # 암호화

# 템플릿 재생성 (walle에서)
ssh crong@walle.bun-bull.ts.net 'sudo bash -s' < scripts/create-ubuntu-template.sh

# ProxmoxMCP-Plus config schema 검증 (config.json 변경 후)
uv run --with proxmox-mcp-plus python3 -c "from proxmox_mcp.config.loader import load_config; load_config('/home/deck/.config/proxmox-mcp/config.json')" && echo "CONFIG VALID"
```

## Day-to-Day Operations

```bash
# Heritage 서비스 재시작
ssh heritage "cd /opt/heritage && docker compose restart <service>"

# Heritage 로그 확인
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 <service>"

# Caddy 서비스 재시작
ssh heritage "cd /opt/heritage && docker compose restart caddy"

# Caddy 로그 확인
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 caddy"

# Heritage 파일 권한 확인
ssh crong@walle.bun-bull.ts.net "ls -la /mnt/data1/torrent/ /mnt/data2/torrent/"

# Heritage 파일 소유권 변경 (호스트에서 UID 101000 사용)
ssh crong@walle.bun-bull.ts.net "chown -R 101000:101000 /mnt/data1/torrent/ /mnt/data2/torrent/"

# Cockpit 서비스 재시작 / 상태
ssh crong@cockpit "sudo systemctl restart cockpit.socket; sudo systemctl status cockpit.socket"

# Cockpit 로그 확인
ssh crong@cockpit "sudo journalctl -u cockpit -f --tail=50"

# PatchMon 서비스 재시작 / 상태 (cockpit VM 102)
ssh crong@cockpit "cd /opt/patchmon && sudo docker compose restart server"
ssh crong@cockpit "cd /opt/patchmon && sudo docker compose ps"

# PatchMon 로그 확인
ssh crong@cockpit "cd /opt/patchmon && sudo docker compose logs -f --tail=50 server"

# Tailscale Serve 상태 확인 (cockpit/heritage)
ssh crong@cockpit "tailscale serve status"
ssh heritage "tailscale serve status"

# Proxmox VM/LXC 상태
ssh crong@walle.bun-bull.ts.net "sudo qm list; sudo pct list"
```

## Key Constraints

- **Provider:** bpg/proxmox v0.111+ (`~> 0.111` pin). Container 리소스는 `initialization`, `operating_system`, `disk` 블록 사용 (구 `hostname`, `ostemplate`, `rootfs` 불가). VM 리소스는 `agent { enabled = true }` 블록 (구 `guest_agent = true` / Telmate `proxmox_vm_qemu` 금지)
- **Cockpit VM:** Ubuntu 24.04 LTS cloud image. `started = true` (QEMU guest agent 지원). `agent { enabled = true }`로 IP 인식. cloud-init은 `ubuntu` 계정 + SSH 키만 (최소화). `cockpit-admin` 계정/비밀번호/Tailscale은 Ansible 담당 (회사 서버 재현성)
- **Endpoint:** `walle.bun-bull.ts.net:8006` (Tailscale). `walle.bun-bull.ts.net` (443, Tailscale Serve). `insecure = true` 필요 (자가 서명 인증서)
- **Secrets:** `proxmox/opentofu/secrets.sops.yaml` (OpenTofu용), `proxmox/ansible/secrets.sops.yaml` (Ansible용, 분리). age 키로 sops 암호화. API Token 형식: `root@pam!<token-name>=<secret>`
- **SSH:** `ssh crong@walle.bun-bull.ts.net` (UID 101000, passwordless sudo). **root SSH는 키 미등록으로 불가** — Ansible inventory도 `ansible_user=crong ansible_become=true`. qm/pct/스크립트 실행 모두 이 계정 + sudo
- **Heritage SSH:** `ssh crong@walle.bun-bull.ts.net` (UID 101000, sudo 권한 포함). 파일 시스템 관리용 사용자
- **DHCP IP 조회:** `ssh arv "cat /tmp/dhcp.leases"` — 공유기(OpenWrt)에서 VM MAC 주소로 IP 매핑
- **OpenTofu R2 Backend:** Cloudflare R2 S3-compatible backend 사용. `tofu init`/`plan`/`apply` 전 `source /home/deck/git/247365/.env`로 AWS 자격 증명 주입 필요. state key: `homelab/dev/terraform.tfstate`

## File Layout

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 (provider, variables, cockpit.tf, heritage.tf, outputs.tf, backend.tf) |
| `proxmox/opentofu/backend.tf` | Cloudflare R2 S3-compatible backend (state 저장소, key: `homelab/dev/terraform.tfstate`) |
| `proxmox/ansible/` | Ansible 설정, 인벤토리, 플레이북, roles |
| `proxmox/ansible/inventory/hosts.ini` | 인벤토리 (플레이북과 그룹명 1:1 매핑: proxmox_hosts, heritage_hosts, cockpit_hosts) |
| `proxmox/ansible/playbooks/walle.yml` | walle Tailscale Serve (443→8006) + PVE post-install (enterprise repo 비활성화, no-subscription repo, 알림 숨김) |
| `proxmox/ansible/playbooks/cockpit.yml` | Cockpit + PatchMon 배포 (cockpit_hosts, become, role cockpit) |
| `proxmox/ansible/roles/cockpit/` | Cockpit role — 패키지, socket loopback, UFW, Docker, PatchMon Compose, Tailscale Serve 다중 포트 |
| `proxmox/ansible/roles/cockpit/tasks/docker.yml` | Docker CE Engine 설치 (heritage 패턴: GPG key + apt_repository) |
| `proxmox/ansible/roles/cockpit/tasks/patchmon.yml` | PatchMon Compose 배포 (.env 0600, docker_compose_v2 wait) |
| `proxmox/ansible/roles/cockpit/templates/docker-compose.yml.j2` | PatchMon Compose 템플릿 (4컨테이너, 127.0.0.1:3000 loopback) |
| `proxmox/ansible/roles/cockpit/templates/patchmon.env.j2` | PatchMon .env 템플릿 (시크릿 변수 주입) |
| `proxmox/ansible/secrets.sops.yaml` | Ansible 전용 sops (cockpit_admin_password, tailscale_auth_key, patchmon_* 5키) |
| `heritage/` | Heritage 미디어 서버 Docker Compose 설정 (compose.yml, homepage, aria2) |
| `heritage/.env.sops` | sops 암호화 환경변수 (서버 .env의 소스) |
| `heritage/caddy/` | Caddy L7 리버스 프록시 설정 (Caddyfile) |
| `scripts/` | Proxmox 호스트 실행 스크립트 (create-ubuntu-template.sh 등) |
| `docs/` | 문서 (architecture.md, specs, plans) |
| `.mcp.json` | MCP 서버 설정 |
| `.sops.yaml` | sops 암호화 규칙 (age 키) |

## Gotchas

- **Bash CWD:** `cd proxmox/ansible && ...` 실행 후 CWD가 변경됨. 후속 git 명령어는 반드시 절대 경로 또는 `cd /home/deck/git/homelab &&` 선행 필요
- **Ansible hosts.ini IP:** `inventory/hosts.ini`의 IP는 현재 하드코딩되어 있음. VM 재생성 후 DHCP IP가 변경되면 반드시 갱신 필요
- **Homepage 보안:** 기본 설정으로 `/:/host:ro`와 `/var/run/docker.sock` 마운트가 활성화되어 있음. 보안 강화를 위해 주석 처리 필요
- **Aria2 RPC 시크릿:** `RPC_SECRET` 환경변수가 주석 처리되어 있을 경우 기본값 `P3TERX` 사용. 포트 6800이 직접 노출되므로 반드시 설정 필요
- **Memory Consolidation:** 세션 시작 시 자동으로 memory consolidation이 백그라운드에서 실행됨. 완료될 때까지 대용량 검색 작업 지연 권장
- **Heritage LXC UID 매핑:** LXC 200은 unprivileged → 컨테이너 UID N → 호스트 UID 100000+N 매핑. 현재 crong 사용자 UID 101000은 컨테이너 내 UID 1000으로 매핑됨
- **Transmission/Jellyfin 권한:** 호스트 `/mnt/data{1,2}/torrent/`는 UID 101000:101000 소유(권한 700). Transmission(PUID=1000)과 Jellyfin(user:1000:1000)이 동일 UID 사용
- **Proxmox HTTP 검증:** `curl -sI`(HEAD)는 501 반환. GET으로 검증: `curl -s -o /dev/null -w "%{http_code}" https://walle.bun-bull.ts.net`
- **Cockpit socket loopback:** `cockpit.socket`을 `/etc/systemd/system/cockpit.socket.d/override.conf`로 `127.0.0.1:9090` 제한. 외부 노출은 Tailscale Serve(443)만
- **Cockpit Tailscale Serve 스킴:** 백엔드는 `https+insecure://localhost:9090` (Cockpit 자가서명 TLS). 일반 `https://`는 502
- **Cockpit admin 계정:** Ansible이 동적 생성 (`cockpit-admin`, passworded sudo — NOPASSWD 지양). 비밀번호는 `proxmox/ansible/secrets.sops.yaml`
- **PatchMon 배포 제어:** `cockpit_patchmon_enabled`(기본 true)로 Docker/PatchMon 전체 on/off. 회사 서버는 false 시 Cockpit만 배포 (재현성)
- **PatchMon loopback 바인딩:** docker-compose `127.0.0.1:3000:3000` (LAN 노출 금지). 외부 접속은 Tailscale Serve 8443만
- **PatchMon Tailscale Serve JSON idempotency:** `tailscale serve status --json`의 `TCP['443']`/`TCP['8443']` 키로 재구성 여부 판단. `Web` 키는 `host:port` 형식이라 직접 포트 접근 불가 (2026-07-06 스키마 확인)
- **PatchMon .env 권한:** `/opt/patchmon/.env`는 mode 0600 owner root (평문 시크릿). Ansible `no_log: true`로 배포 로깅 차단
- **PatchMon 컬렉션 의존:** `community.docker`(docker_compose_v2) 필요. heritage.yml도 동일 모듈 사용 중
- **.terraform.lock.hcl:** `.gitignore`에 있지만 재현 가능한 빌드를 위해 커밋 권장. 필요시 gitignore에서 제거
- **DHCP IP:** `hosts.ini` IP는 공유기 DHCP 기반. VM 재생성 시 `ssh arv "cat /tmp/dhcp.leases"`로 MAC→IP 매핑 후 갱신
- **Heritage bind mount:** `/mnt/data1`, `/mnt/data2`는 walle에 디스크 설정 후 `heritage.tf`에 `mount_point` 블록 추가 필요
- **Heritage LXC:** `/dev/net/tun` 디바이스 패스스루 + `keyctl=true` 필요 (Tailscale용). `heritage.tf`에 이미 설정됨
- **Heritage 외부 접속:** `heritage.bun-bull.ts.net` — Tailscale LXC 호스트 설치 + `tailscale serve`로 path-based 라우팅 (Caddy 사용)
- **Caddy 라우팅:** Tailscale Serve(443→9080) → Caddy → 서비스. Homepage(`/`), Transmission(`/transmission`), Jellyfin(`/jellyfin`) path-based 라우팅
- **Caddyfile 포맷:** `caddy fmt --overwrite` 실행 필요 (경고 있음, 작동 영향 없음)
- **Ansible orphan container:** `docker compose up --remove-orphans`로 정리 가능
- **롤백 방법:** `git checkout HEAD~N` — commit count 기반 (HEAD~8, HEAD~7)
- **Tailscale Serve HTTPS 백엔드:** 자가 서명 인증서 백엔드는 `https+insecure://` 스킴 사용 필요 (일반 `https://`는 502 에러)
- **Proxmox no-subscription 설정:** 재설치 후 enterprise repo 비활성화 + no-subscription repo 전환 (trixie). `walle.yml`이 idempotent로 자동화. 로그인 알림 숨김은 `proxmoxlib.js`의 `res.data.status.toLowerCase() !== 'active'` → `false` 치환 (2곳, pveproxy 재시작). **Ceph repo는 Web UI Ceph 설치 마법사가 no-subscription으로 자동 추가** — Ansible이 건드리지 않음
- **LXC 템플릿:** `pveam update && pveam download local <template-name>` — Proxmox에서 LXC용 OS 템플릿 다운로드. `pveam available --section system`으로 목록 확인
- **Ubuntu cloud image:** `noble-server-cloudimg-amd64.img` (https://cloud-images.ubuntu.com/noble/current/). `create-ubuntu-template.sh`가 다운로드 + importdisk + template 변환
- **Aria2 RPC Secret:** `RPC_SECRET` 미설정 시 이미지 기본값 `P3TERX` 사용. RPC 클라이언트 연결 시 필요
- **Aria2 이미지:** `p3terx/aria2-pro:test` 사용 (latest 4년 전, `:test` 태그가 daily build)
- **Homepage aria2 위젯:** 미지원 ([#1280](https://github.com/gethomepage/homepage/discussions/1280)). 컨테이너 상태 카드만 가능

## MCP Servers

`.mcp.json`으로 관리. Claude Code 시작 시 자동 로드.

| 서버 | 상태 | 비고 |
| :--- | :--- | :--- |
| proxmox-mcp-plus | 활성 | `uvx proxmox-mcp-plus`, 설정: `/home/deck/.config/proxmox-mcp/config.json` (권한 600, git 미추적) |
| serena | 활성 | 코드 심볼 분석 |
| zai-mcp-server | 활성 | 멀티모달 분석, OCR, UI 비교 |
| figma | 비활성 | 필요시 활성 |
| discord | 비활성 | 필요시 활성 |

> kubernetes MCP는 K8s 클러스터(talos) 삭제로 비활성화됨. `.mcp.json`에서 제거 대상.

- **Proxmox MCP 설정:** `/home/deck/.config/proxmox-mcp/config.json` (권한 600) — `verify_ssl=false` + `dev_mode=true` (자가 서명 인증서 허용 조건), `ssh.user=crong` + `use_sudo=true` (NOPASSWD), `command_policy.mode=deny_all` (SSH exec 도구 비활성, API 도구만 사용). 토큰은 `proxmox/opentofu/secrets.sops.yaml`의 `proxmox_api_token`에서 sops 복호화 후 주입
- **Proxmox MCP 데이터 경로:** `~/.local/state/proxmox-mcp/walle/` (sqlite DB, 로그) — XDG 표준 준수
- **Heritage 사용자:** crong(UID 101000)는 LXC 200 내에서 UID 1000으로 매핑됨. 호스트에서 파일 관리 시 `chown 101000:101000` 사용
