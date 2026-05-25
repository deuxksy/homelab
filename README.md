# Homelab

walle (Proxmox VE 9.2) 인프라 IaC 관리. OpenTofu + Ansible + Talos.

## Architecture

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 100: talos-master (K8s control-plane)
├── VM 101: talos-worker (K8s worker)
└── LXC 200: heritage (Debian 12, Docker + Tailscale Serve)
    ├── Traefik (L7 reverse proxy)
    ├── Homepage (dashboard)
    ├── Transmission (torrent)
    ├── Jellyfin (streaming)
    ├── Gatus (uptime monitoring)
    └── Beszel (hw monitoring)
```

**접속:** Tailscale Serve(443) → Traefik(9080) → 서비스. TLS 종료는 Tailscale이 처리.

| ID | 이름 | 타입 | OS | 역할 | 접속 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| - | walle | - | Proxmox VE 9.2 | Hypervisor | `walle.bun-bull.ts.net` (443) |
| 100 | talos-master | VM | Talos | K8s control-plane | - |
| 101 | talos-worker | VM | Talos | K8s worker | - |
| 200 | heritage | LXC | Debian 12 | 미디어 서버 | `heritage.bun-bull.ts.net` (443) |

## Structure

| 경로 | 역할 |
| :--- | :--- |
| `proxmox/opentofu/` | OpenTofu 프로비저닝 |
| `proxmox/ansible/` | Ansible 인벤토리, 플레이북 (`walle.yml`, `heritage.yml`, `talos-bootstrap.yml`) |
| `heritage/` | Docker Compose + Traefik + Homepage/Gatus 설정 |
| `k8s/talconfig.yaml` | talhelper 클러스터 설정 |
| `scripts/` | Proxmox 호스트 스크립트 |

## Workflow

```bash
# 1. Proxmox VM/LXC 프로비저닝
cd proxmox/opentofu && tofu apply

# 2. Talos K8s 클러스터 부트스트랩
cd k8s && talhelper genconfig && talosctl apply ...

# 3. Heritage LXC 배포
cd proxmox/ansible && ansible-playbook playbooks/heritage.yml

# 4. walle Tailscale Serve 설정
cd proxmox/ansible && ansible-playbook playbooks/walle.yml

# Secrets 관리
sops -d secrets.sops.yaml              # 복호화
sops -e plain.yaml > secrets.sops.yaml # 암호화
```
