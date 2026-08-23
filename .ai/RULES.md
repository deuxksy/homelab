# Homelab Rules & Architecture

Repository-wide Single Source of Truth for AI Coding Agents.

## Project Overview

Homelab IaC for walle (Proxmox VE 9.2) — OpenTofu로 VM/LXC 프로비저닝, Ansible로 애플리케이션/관리 도구 배포.

## Architecture

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 102: moni (Ubuntu 24.04 LTS) — stopped (2026-08-23, RAM 4GB 회수·heritage의 Immich/Pulse 수용. disk 보존, Cockpit/PatchMon 폐기)
├── LXC 200: heritage (Debian 12, cores 4 / memory 4096 / swap 1024, Docker + Tailscale Serve)
│   ├── Caddy (L7 reverse proxy, port 9080)
│   ├── Homepage (dashboard)
│   ├── Transmission (torrent)
│   ├── Jellyfin (streaming)
│   ├── Aria2 (다운로드 매니저, port 6800)
│   ├── Immich v3.1.0 (사진 관리 — immich_server/immich_machine_learning/immich_redis/immich_postgres, :2283 loopback, server mem_limit 1.5g)
│   └── Pulse (통합 모니터링, :7655 loopback — moni에서 이전)
└── templates: 901 ubuntu-2404-template (moni VM clone 원본)
```

> K8s 클러스터(talos 100/101)는 2026-07-06 사용자 의도적 삭제됨. `k8s/` 디렉토리(talconfig.yaml)는 잔재.

**프로비저닝 흐름:** OpenTofu → cloud-init(최소) → Ansible  
**외부 접속:** `tailscale serve`로 Tailscale이 TLS 종료 — walle: 443→8006(PVE UI), heritage: 443→9080(Caddy) + 2283(Immich) + 10000(Pulse). 80 미사용.  
**콘텐츠 파이프라인 (상류 자동화는 외부 repo가 담당):**
- Vesper-X (`~/git/Vesper-X/`, 직링크 추출) → aria2 RPC(heritage:6800) → `/mnt/data2/torrent/downloads/aria` → Immich External Library
- Meridian-X (`~/git/Meridian-X/`, 토렌트 수집 자동화) → Transmission RPC → `/mnt/data{1,2}/torrent` → Jellyfin

### 서비스 접속 URL (Tailnet 내부)

| 서비스 | URL | 비고 |
| :--- | :--- | :--- |
| Homepage | `https://heritage.bun-bull.ts.net/` | 대시보드 |
| Jellyfin | `https://heritage.bun-bull.ts.net/jellyfin` | 스트리밍 |
| Transmission | `https://heritage.bun-bull.ts.net/transmission` | 토렌트 |
| Immich | `https://heritage.bun-bull.ts.net:2283` | 사진 관리, Tailscale Serve(2283→http://localhost:2283). LAN 직접: `http://192.168.221.214:2284` (Tailscale 없는 기기·TV용) |
| Pulse | `https://heritage.bun-bull.ts.net:10000` | 통합 모니터링, Tailscale Serve(10000→http://localhost:7655), moni에서 이전 |
| Proxmox UI | `https://walle.bun-bull.ts.net` | Tailscale Serve(443→8006) |
| Aria2 RPC | `ws://heritage.bun-bull.ts.net:6800/jsonrpc` | 다운로드 매니저, RPC Secret: P3TERX |

> moni 서비스(Cockpit :9090 / PatchMon :8443 / Pulse :10000)는 VM 102 중지(2026-08-23)로 폐쇄됨.

## Full Provisioning Workflow

### Cockpit VM (신규)

> moni VM 102는 2026-08-23 중지(disk 보존). 아래 워크플로는 moni 재배포 시에만 사용.

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

## Common Commands & Operations

```bash
# OpenTofu 초기화 및 검증 (R2 자격 증명 필요)
# 주의: 실행 전 반드시 `source /home/deck/git/247365/.env` 실행 필요
cd proxmox/opentofu && tofu init && tofu validate

# Secrets — sops 암호화/복호화
sops -d secrets.sops.yaml              # 복호화 (평문 출력)
sops -e plain.yaml > secrets.sops.yaml # 암호화

# 템플릿 재생성 (walle에서)
ssh crong@walle.bun-bull.ts.net 'sudo bash -s' < scripts/create-ubuntu-template.sh

# ProxmoxMCP-Plus config schema 검증 (config.json 변경 후)
uv run --with proxmox-mcp-plus python3 -c "from proxmox_mcp.config.loader import load_config; load_config('/home/deck/.config/proxmox-mcp/config.json')" && echo "CONFIG VALID"

# Heritage 서비스 재시작 / 로그
# 컨테이너: caddy, homepage, transmission, aria2, jellyfin,
#           immich_server, immich_machine_learning, immich_redis, immich_postgres, pulse
ssh heritage "cd /opt/heritage && docker compose restart <service>"
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 <service>"

# Caddy 서비스 재시작 / 로그
ssh heritage "cd /opt/heritage && docker compose restart caddy"
ssh heritage "cd /opt/heritage && docker compose logs -f --tail=50 caddy"

# Heritage 파일 권한 확인 / 소유권 변경 (호스트에서 UID 101000 사용)
ssh crong@walle.bun-bull.ts.net "ls -la /mnt/data1/torrent/ /mnt/data2/torrent/"
ssh crong@walle.bun-bull.ts.net "chown -R 101000:101000 /mnt/data1/torrent/ /mnt/data2/torrent/"

# --- moni VM 102: 현재 stopped (2026-08-23). 아래 명령은 재기동 시 참고용 ---

# Cockpit 서비스 재시작 / 상태 / 로그 (VM 102, ubuntu user + proxyjump)
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "sudo systemctl restart cockpit.socket; sudo systemctl status cockpit.socket"
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "sudo journalctl -u cockpit -f --tail=50"

# PatchMon 서비스 재시작 / 상태 / 로그 (VM 102)
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "cd /opt/patchmon && sudo docker compose restart server"
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "cd /opt/patchmon && sudo docker compose ps"
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "cd /opt/patchmon && sudo docker compose logs -f --tail=50 server"

# Tailscale Serve 상태 확인 (moni — 중지 상태 / heritage)
ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117 "tailscale serve status"
ssh heritage "tailscale serve status"

# Proxmox VM/LXC 상태
ssh crong@walle.bun-bull.ts.net "sudo qm list; sudo pct list"
```

## Key Constraints

- **Provider:** bpg/proxmox v0.111+ (`~> 0.111` pin). Container 리소스는 `initialization`, `operating_system`, `disk` 블록 사용 (구 `hostname`, `ostemplate`, `rootfs` 불가). VM 리소스는 `agent { enabled = true }` 블록 (구 `guest_agent = true` / Telmate `proxmox_vm_qemu` 금지)
- **Cockpit VM:** Ubuntu 24.04 LTS cloud image. `started = true` (QEMU guest agent 지원). `agent { enabled = true }`로 IP 인식. cloud-init은 `ubuntu` 계정 + SSH 키만 (최소화). `cockpit-admin` 계정/비밀번호/Tailscale은 Ansible 담당 (회사 서버 재현성). **현재 `started = false` — 2026-08-23 중지, disk 보존 (cockpit role은 재현용 보존)**
- **Endpoint:** `walle.bun-bull.ts.net:8006` (Tailscale). `walle.bun-bull.ts.net` (443, Tailscale Serve). `insecure = true` 필요 (자가 서명 인증서)
- **Secrets:** `proxmox/opentofu/secrets.sops.yaml` (OpenTofu용), `proxmox/ansible/secrets.sops.yaml` (Ansible용, 분리). age 키로 sops 암호화. API Token 형식: `root@pam!<token-name>=<secret>`
- **SSH:** `ssh crong@walle.bun-bull.ts.net` (UID 101000, passwordless sudo). **root SSH는 키 미등록으로 불가** — Ansible inventory도 `ansible_user=crong ansible_become=true`. qm/pct/스크립트 실행 모두 이 계정 + sudo
- **Moni VM SSH:** `ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117` (proxyjump, `ansible_user=ubuntu ansible_become=true`). `crong@moni` 또는 `crong@cockpit` 불가 — ubuntu 계정만 SSH 키 등록됨. **VM 102는 현재 stopped — 재기동 시 DHCP 재임대로 IP 변경 가능**
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
| `proxmox/ansible/playbooks/cockpit.yml` | Cockpit + PatchMon + Pulse 배포 (cockpit_hosts, become, role cockpit) |
| `proxmox/ansible/roles/cockpit/` | Cockpit role — 패키지, socket loopback, UFW, Docker, PatchMon/Pulse Compose, Tailscale Serve 다중 포트 |
| `proxmox/ansible/roles/cockpit/tasks/auth.yml` | cockpit-admin 계정 생성 + sudoers + SSH 키 제한 |
| `proxmox/ansible/roles/cockpit/tasks/docker.yml` | Docker CE Engine 설치 (heritage 패턴: GPG key + apt_repository) |
| `proxmox/ansible/roles/cockpit/tasks/patchmon.yml` | PatchMon Compose 배포 (.env 0600, docker_compose_v2 wait) |
| `proxmox/ansible/roles/cockpit/tasks/pulse.yml` | Pulse Compose 배포 (docker_compose_v2 wait, assert 1 컨테이너) |
| `proxmox/ansible/roles/cockpit/tasks/tailscale_join.yml` | Tailscale 패키지 설치 + 인증키 조인 |
| `proxmox/ansible/roles/cockpit/tasks/tailscale_serve.yml` | Tailscale Serve reset 기반 4상태 동적 패턴 (9090/8443/10000, R1/R2) |
| `proxmox/ansible/roles/cockpit/templates/docker-compose.yml.j2` | PatchMon Compose 템플릿 (4컨테이너, 127.0.0.1:3000 loopback) |
| `proxmox/ansible/roles/cockpit/templates/patchmon.env.j2` | PatchMon .env 템플릿 (시크릿 변수 주입) |
| `proxmox/ansible/roles/cockpit/templates/pulse-docker-compose.yml.j2` | Pulse Compose 템플릿 (1컨테이너, 127.0.0.1:7655 loopback) |
| `proxmox/ansible/secrets.sops.yaml` | Ansible 전용 sops (cockpit_admin_password, tailscale_auth_key, patchmon_* 5키) |
| `heritage/` | Heritage 서비스 Docker Compose (10컨테이너: caddy, homepage, transmission, aria2, jellyfin, immich×4, pulse) |
| `heritage/.env.sops` | sops 암호화 환경변수 (서버 .env의 소스. Immich env 포함: `IMMICH_VERSION`, `UPLOAD_LOCATION`, `DB_DATA_LOCATION`, `DB_HOSTNAME`, `REDIS_HOSTNAME` 등) |
| `heritage/caddy/` | Caddy L7 리버스 프록시 설정 (Caddyfile) |
| `scripts/` | Proxmox 호스트 실행 스크립트 (create-ubuntu-template.sh 등) |
| `docs/` | 문서 (architecture.md, README.md, superpowers/specs·plans — Immich 설계: `2026-08-23-immich-design.md`) |
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
- **Cockpit socket loopback:** `cockpit.socket`을 `/etc/systemd/system/cockpit.socket.d/override.conf`로 `127.0.0.1:9090` 제한. 외부 노출은 Tailscale Serve(9090)만
- **Cockpit Tailscale Serve 스킴:** 백엔드는 `https+insecure://localhost:9090` (Cockpit 자가서명 TLS). 일반 `https://`는 502
- **Cockpit admin 계정:** Ansible이 동적 생성 (`cockpit-admin`, passworded sudo — NOPASSWD 지양). 비밀번호는 `proxmox/ansible/secrets.sops.yaml`
- **Cockpit VM SSH:** `ubuntu` 계정 + walle proxyjump (`ssh -J crong@walle.bun-bull.ts.net ubuntu@192.168.221.117`). `crong@moni` 불가 (SSH 키 미등록)
- **Tailscale Serve 포트:** 80 미사용. 443은 walle(→8006 PVE UI)과 heritage(→9080 Caddy)가 사용. Immich=2283, Pulse=10000 (비표준 HTTPS 포트도 지원). moni(재기동 시) Cockpit=9090, PatchMon=8443
- **Immich LAN 직접 접속 (2284):** tailscaled가 tailnet IP의 2283을 선점하므로 컨테이너의 `0.0.0.0:2283` 바인딩 불가 (address already in use). compose는 `127.0.0.1:2283`(Serve용) + `2284:2283`(LAN용) 이중 구성 — LAN 기기는 `http://<heritage-LAN-IP>:2284`로 접속. heritage IP는 DHCP라 변경 시 URL 갱신 필요
- **Tailscale Serve 4상태 동적 패턴:** reset 기반 재구성 (9090 항상 + 8443/10000 조건부). `serve_required_ports` vs `ts_current_serve.TCP.keys()` 비교로 idempotency 보장
- **PatchMon 배포 제어:** `cockpit_patchmon_enabled`(기본 true)로 Docker/PatchMon 전체 on/off. 회사 서버는 false 시 Cockpit만 배포 (재현성)
- **PatchMon loopback 바인딩:** docker-compose `127.0.0.1:3000:3000` (LAN 노출 금지). 외부 접속은 Tailscale Serve 8443만
- **PatchMon CORS_ORIGIN:** `cockpit_patchmon_cors_origin` 변수 (`https://moni.bun-bull.ts.net:8443`). 노드명/포트 변경 시 동기화 필수
- **PatchMon Tailscale Serve JSON idempotency:** `tailscale serve status --json`의 `TCP` 키로 재구성 여부 판단 (2026-07-06 스키마 확인)
- **PatchMon .env 권한:** `/opt/patchmon/.env`는 mode 0600 owner root (평문 시크릿). Ansible `no_log: true`로 배포 로깅 차단
- **PatchMon 컬렉션 의존:** `community.docker`(docker_compose_v2) 필요. heritage.yml도 동일 모듈 사용 중
- **Pulse 배포:** 현재 heritage `compose.yml`의 `pulse` 서비스로 배포(moni에서 이전, `pulse_data` volume 이관으로 admin 계정/PVE 토큰 보존). `cockpit_pulse_enabled` 플래그는 moni cockpit role 재배포 시에만 적용
- **Pulse Docker 포트:** `127.0.0.1:7655` loopback 바인딩만 (LAN 노출 금지). 외부 접속은 Tailscale Serve 10000만
- **Pulse 인증:** UI setup wizard로 관리자 계정 최초 생성. `PULSE_AUTH_USER`/`PULSE_AUTH_PASS` env preseed 금지 (B1 — 환경변수가 UI 설정을 override함)
- **Pulse healthcheck:** `/api/health` 엔드포인트 (nc -z 대신 curl로 검증)
- **Pulse Proxmox 연동:** Tailscale 도메인 사용 (`https://walle.bun-bull.ts.net`, TLS skip 불필요). PVEAuditor 역할 API Token 필요 (수동 생성, IaC 범위 밖)
- **moni 재기동 시 RAM 재부족:** walle(host) 7.5GB 제약 — heritage(4GB)와 moni(4GB) 동시 구동 불가. 재기동하려면 heritage 축소 또는 Immich ML(`immich_machine_learning`) 중지 필요. 재기동 후 `hosts.ini` moni IP는 DHCP 재임대 확인 필수
- **Immich subpath 미지원:** path-based 라우팅 불가 → 전용 포트(2283, Tailscale Serve) 노출 필수
- **Immich External Library:** aria2 다운로드 경로(`/mnt/data2/torrent/downloads/aria`)를 `/mnt/aria:ro`로 마운트. External Library 등록/관리는 Immich Admin UI에서 수행
- **Immich 스토리지 경로:** `UPLOAD_LOCATION=/mnt/data1/immich`(data1), `DB_DATA_LOCATION=/opt/heritage/postgres`(rootfs). 신규 bind mount 디렉토리는 walle host에서 사전 생성 필요 — unprivileged LXC 권한 제약
- **Immich .env 호스트명:** `DB_HOSTNAME=immich-postgres`, `REDIS_HOSTNAME=immich-redis` 필수 — 컨테이너명(`immich_postgres` 등)과 서비스명이 달라 미설정 시 연결 실패
- **Immich 초기 ML 인덱싱:** 라이브러리 규모에 따라 수일 소요 (백그라운드 job)
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
- **Homepage Immich 위젯:** homepage v2.1.2까지 구 API 경로(`/api/server-info/*`)를 호출 — Immich v3가 `/api/server/*`로 개명해 404 호환 불가. 상류 지원 시 services.yaml 위젯 블록 재활성화 (.env 키 `HOMEPAGE_VAR_KEY_IMMICH` 보존)
- **Homepage docker.sock:** 앱이 node(uid 1000)로 실행되어 docker GID(996) 그룹 미소속 시 EACCES — compose `group_add: ["996"]`로 해결. `.env` 변경(신규 키)은 컨테이너 재생성 전까지 미적용
