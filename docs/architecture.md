# Homelab Architecture

> **상태**: 초기 구축
> **Proxmox**: walle (192.168.221.198:8006)

## 인프라 구성

| ID | 이름 | 타입 | OS | vCPU | RAM | Disk |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 900 | talos-template | VM Template | Talos | 2 | 1G | 10G |
| 100 | talos-master | VM | Talos | 2 | 1.5G | 20G |
| 101 | talos-worker | VM | Talos | 2 | 2.5G | 30G |
| 200 | heritage | LXC | Debian 12 | 2 | 1.5G | 50G |

## 프로비저닝 순서

1. `scripts/create-talos-template.sh` — Talos 템플릿 생성 (최초 1회)
2. `proxmox/opentofu/` — `tofu apply` VM/LXC 프로비저닝
3. `k8s/talconfig.yaml` — talhelper로 Talos 설정 생성
4. `proxmox/ansible/playbooks/talos-bootstrap.yml` — K8s 클러스터 부트스트랩
5. `proxmox/ansible/playbooks/heritage.yml` — heritage 미디어 서버 배포

## Secrets

- `proxmox/opentofu/secrets.sops.yaml` — Proxmox API Token (sops 암호화)
- `k8s/talosconfig` — Talos 인증 정보 (gitignore)
- `heritage/.env.sops` — heritage 환경 변수 (heritage repo에서 관리)
