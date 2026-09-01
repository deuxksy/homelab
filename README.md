# Homelab

본 저장소는 Proxmox VE 9.2(walle) 기반 홈랩 인프라를 OpenTofu와 Ansible을 통해 코드로 관리(IaC)하는 프로젝트입니다. Debian 기반 미디어 서비스 LXC(Caddy, Homepage, Jellyfin, Transmission, Aria2, Immich)를 자동 프로비저닝하며, Tailscale을 통해 안전한 외부 TLS 접속 및 내부 네트워크 분리를 제공합니다. 모니터링 VM(moni)은 2026-08-23 중지 상태입니다.

---

## 🏗️ 인프라 아키텍처 요약

```
walle (Proxmox VE, Tailscale: walle.bun-bull.ts.net)
├── VM 102: moni (Ubuntu 24.04 LTS — 2026-08-23 중지, disk 보존)
└── LXC 200: heritage (Debian 12, Docker + Caddy + Media Stack + Immich)
```

### 주요 서비스 접속 URL (Tailnet 전용)

| 서비스 | URL | 설명 |
| :--- | :--- | :--- |
| **Homepage** | `https://heritage.bun-bull.ts.net/` | 홈랩 통합 대시보드 |
| **Jellyfin** | `https://heritage.bun-bull.ts.net/jellyfin` | 미디어 스트리밍 |
| **Transmission** | `https://heritage.bun-bull.ts.net/transmission` | 토렌트 다운로더 |
| **Immich** | `https://heritage.bun-bull.ts.net:2283` | 사진 관리 (LAN 직접: `http://<LAN-IP>:2284`) |
| **Proxmox UI** | `https://walle.bun-bull.ts.net` | PVE 관리 웹 콘솔 (Tailscale Serve 443→8006) |

> moni 서비스(Cockpit :9090 / PatchMon :8443 / Pulse :10000)는 VM 102 중지(2026-08-23)로 폐쇄 — 재기동 시 복원

---

## ⚡ 빠른 시작 (Quick Start)

### 1. OpenTofu 프로비저닝 (VM/LXC 생성)

```bash
# 환경변수 로드 후 인프라 배포
cd proxmox/opentofu
tofu init
tofu plan
tofu apply
```

### 2. Ansible 플레이북 실행 (서비스 및 환경 구성)

```bash
cd proxmox/ansible

# Cockpit 및 모니터링 스택 배포
ansible-playbook playbooks/cockpit.yml

# Heritage 미디어 서버 스택 배포
ansible-playbook playbooks/heritage.yml
```

---

## 📚 문서 체계 (Diátaxis Documentation Index)

### 1. Tutorials (튜토리얼 / 입문)
- [Ubuntu 템플릿 생성 스크립트](./scripts/create-ubuntu-template.sh) - PVE 호스트에서 cloud-init 기반 템플릿 생성하기

### 2. How-to Guides (가이드 / 실무 절차)
- [OpenTofu & Ansible 배포 가이드](./.ai/RULES.md#full-provisioning-workflow) - 인프라 프로비저닝 및 롤아웃 절차
- [일상 운영 및 서비스 제어](./.ai/RULES.md#common-commands--operations) - 컨테이너 재시작, 로그 확인 및 권한 관리

### 3. Reference (참고자료 / 사양서)
- [문서 허브 (docs/README.md)](./docs/README.md) - `docs/` 디렉터리 구조 및 문서 안내
- [인프라 규칙 및 제약사항](./.ai/RULES.md) - 포트 매핑, 계정 정책, Tailscale Serve 스킴 상세
- [시크릿 관리 규격](./.sops.yaml) - SOPS + age 키 암호화 규칙

### 4. Explanation (설명 / 아키텍처)
- [인프라 아키텍처 상세](./docs/architecture.md) - 노드 구성, 네트워크 라우팅 및 스토리지 설계 철학

---

## 🔒 보안 및 시크릿

- 모든 시크릿은 `sops`와 `age` 키로 암호화되어 관리됩니다.
- 외부는 Tailscale Serve를 통한 상호 인증 기반 TLS 종단을 사용하며, 공용 인터넷 포트포워딩(80/443)은 열려 있지 않습니다.
