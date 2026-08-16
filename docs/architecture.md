# Homelab Architecture

> **상태**: 운영 중
> **Proxmox**: walle (`walle.bun-bull.ts.net`, Tailscale)

## 인프라 구성

| ID | 이름 | 타입 | OS | vCPU | RAM | Disk | 주요 역할 / 접속 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 901 | ubuntu-2404-template | VM Template | Ubuntu 24.04 | 2 | 2G | 32G | Moni VM 클론 원본 템플릿 |
| 102 | moni | VM | Ubuntu 24.04 | 2 | 2G | 32G | Cockpit(9090), PatchMon(8443), Pulse(10000) |
| 200 | heritage | LXC | Debian 12 | 2 | 1.5G | 50G | Caddy(9080), Homepage, Jellyfin, Transmission, Aria2 |

## Architecture

```
walle (Proxmox VE 9.2, Tailscale: walle.bun-bull.ts.net)
├── VM 102: moni (Ubuntu 24.04 LTS, Cockpit + PatchMon + Pulse + Tailscale Serve)
│   ├── Cockpit (systemd socket, :9090 loopback only)
│   ├── PatchMon (Docker Compose 4컨테이너, :3000 loopback only)
│   └── Pulse (Docker Compose 1컨테이너, :7655 loopback only)
└── LXC 200: heritage (Debian 12, Docker + Tailscale Serve)
    ├── Caddy (L7 reverse proxy, port 9080)
    ├── Homepage (dashboard)
    ├── Transmission (torrent)
    ├── Jellyfin (streaming)
    └── Aria2 (다운로드 매니저, port 6800)
```

**외부 접속:** Tailscale Serve를 통해 TLS 종료 후 로컬 포트로 프록시. 공용 80/443 포트 미사용.

**Proxmox Web UI:** `walle.bun-bull.ts.net` (Tailscale Serve, `https+insecure://`로 8006 포워딩, 자가서명 인증서 수용)

## 프로비저닝 순서

1. `scripts/create-ubuntu-template.sh` — Ubuntu 24.04 템플릿 생성 (최초 1회, walle에서 실행)
2. `proxmox/opentofu/` — `tofu apply`로 moni VM(102) 및 heritage LXC(200) 프로비저닝
3. `proxmox/ansible/playbooks/cockpit.yml` — moni VM에 Cockpit, PatchMon, Pulse 배포
4. `proxmox/ansible/playbooks/heritage.yml` — heritage LXC에 Caddy 및 미디어 스택 배포
5. `proxmox/ansible/playbooks/walle.yml` — walle Tailscale Serve 설정 및 PVE 저장소 최적화

## Structure

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 (`cockpit.tf`, `heritage.tf`, `backend.tf` 등) |
| `proxmox/ansible/` | Ansible 인벤토리, 플레이북 (`cockpit.yml`, `heritage.yml`, `walle.yml`), roles |
| `proxmox/ansible/inventory/hosts.ini` | 인벤토리 (`proxmox_hosts`, `heritage_hosts`, `cockpit_hosts`) |
| `heritage/` | Docker Compose (`compose.yml`) 및 Homepage, Transmission, Jellyfin, Aria2 설정 |
| `heritage/caddy/` | Caddy L7 리버스 프록시 설정 (`Caddyfile`) |
| `scripts/` | Proxmox 호스트 스크립트 |
| `.sops.yaml` | sops 암호화 규칙 (age 키) |

## Secrets

- `proxmox/opentofu/secrets.sops.yaml` — OpenTofu용 Proxmox API Token (sops 암호화)
- `proxmox/ansible/secrets.sops.yaml` — Ansible용 Cockpit/Tailscale/PatchMon 변수 (sops 암호화)
- `heritage/.env.sops` — heritage 환경 변수 (sops 암호화)
