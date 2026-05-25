# Homelab Architecture

> **상태**: 운영 중
> **Proxmox**: walle (`walle.bun-bull.ts.net`, Tailscale)

## 인프라 구성

| ID | 이름 | 타입 | OS | vCPU | RAM | Disk | 접속 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 900 | talos-template | VM Template | Talos | 2 | 1G | 10G | - |
| 100 | talos-master | VM | Talos | 2 | 1.5G | 20G | - |
| 101 | talos-worker | VM | Talos | 2 | 2.5G | 30G | - |
| 200 | heritage | LXC | Debian 12 | 2 | 1.5G | 50G | `heritage.bun-bull.ts.net` |

## Architecture

```
walle (Proxmox VE 9.2, Tailscale: walle.bun-bull.ts.net)
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

**외부 접속:** Tailscale Serve(443→9080) → Traefik → 서비스. TLS 종료는 Tailscale이 처리.
Gatus는 SPA subpath 미지원으로 `:8088` 직접 접속.

**Proxmox Web UI:** `walle.bun-bull.ts.net` (Tailscale Serve, `https+insecure://`로 8006 포워딩)

## 프로비저닝 순서

1. `scripts/create-talos-template.sh` — Talos 템플릿 생성 (최초 1회)
2. `proxmox/opentofu/` — `tofu apply` VM/LXC 프로비저닝
3. `k8s/talconfig.yaml` — talhelper로 Talos 설정 생성
4. `proxmox/ansible/playbooks/talos-bootstrap.yml` — K8s 클러스터 부트스트랩
5. `proxmox/ansible/playbooks/heritage.yml` — heritage 미디어 서버 배포
6. `proxmox/ansible/playbooks/walle.yml` — walle Tailscale Serve 설정

## Structure

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 (provider, variables, talos.tf, heritage.tf, outputs.tf) |
| `proxmox/ansible/` | Ansible 인벤토리, 플레이북 |
| `proxmox/ansible/inventory/hosts.ini` | 인벤토리 (proxmox_hosts, heritage_hosts, talos) |
| `heritage/` | Docker Compose + Traefik + Homepage/Gatus 설정 |
| `heritage/traefik/` | Traefik L7 리버스 프록시 설정 (static + dynamic YAML) |
| `k8s/talconfig.yaml` | talhelper 클러스터 설정 |
| `scripts/` | Proxmox 호스트 스크립트 |
| `.sops.yaml` | sops 암호화 규칙 (age 키) |

## Secrets

- `proxmox/opentofu/secrets.sops.yaml` — Proxmox API Token (sops 암호화)
- `k8s/talosconfig` — Talos 인증 정보 (gitignore)
- `heritage/.env.sops` — heritage 환경 변수 (sops binary 암호화)
