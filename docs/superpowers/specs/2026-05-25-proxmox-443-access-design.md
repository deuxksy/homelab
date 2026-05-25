# Proxmox 443 접속 via Tailscale Serve

## 목표

`walle.bun-bull.ts.net:8006` → `walle.bun-bull.ts.net` (포트 없이 접속)

## 구성

```
브라우저 → https://walle.bun-bull.ts.net:443 (Tailscale TLS)
         → tailscale serve (walle 호스트)
         → https://127.0.0.1:8006 (PVE Web UI)
```

walle과 heritage는 각각 독립적인 Tailscale 노드이므로 443 포트 충돌 없음.

## IaC 변경사항

### 1. 인벤토리에 walle 추가

`proxmox/ansible/inventory/hosts.ini`에 추가:

```ini
[proxmox_hosts]
walle ansible_host=walle.bun-bull.ts.net ansible_user=root
```

### 2. Ansible playbook 생성

`proxmox/ansible/playbooks/walle.yml`:

- `tailscale serve --bg --set-path / https://127.0.0.1:8006` 실행
- idempotent 처리: 이미 설정되어 있으면 변경하지 않음

## 성공 기준

- `https://walle.bun-bull.ts.net` (포트 없이) 접속 시 Proxmox Web UI 표시
- `ansible-playbook playbooks/walle.yml` 재실행 시 changed=0
