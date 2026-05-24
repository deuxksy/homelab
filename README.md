# Homelab

walle (Proxmox VE) 인프라 IaC 관리. OpenTofu + Ansible + Talos.

## 구성

| ID | 이름 | 타입 | OS | 역할 |
| :--- | :--- | :--- | :--- | :--- |
| 100 | talos-master | VM | Talos | K8s control-plane |
| 101 | talos-worker | VM | Talos | K8s worker |
| 200 | heritage | LXC | Debian 12 | 미디어 서버 |

## 워크플로우

```bash
# 1. Proxmox VM/LXC 프로비저닝
cd proxmox/opentofu && tofu apply

# 2. Talos K8s 클러스터 부트스트랩
cd k8s && talhelper genconfig && talosctl apply ...

# 3. Heritage LXC 설정
cd proxmox/ansible && ansible-playbook playbooks/heritage.yml
```
