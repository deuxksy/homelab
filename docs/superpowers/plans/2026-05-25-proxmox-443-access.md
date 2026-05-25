# Proxmox 443 접속 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tailscale Serve로 `walle.bun-bull.ts.net:443` → PVE Web UI(8006) 포워딩 설정

**Architecture:** walle 호스트의 tailscaled가 443 포트에서 수신하고, 로컬 127.0.0.1:8006으로 역방향 프록시. Ansible로 선언적 관리.

**Tech Stack:** Ansible, Tailscale Serve

---

### Task 1: 인벤토리에 walle 호스트 추가

**Files:**
- Modify: `proxmox/ansible/inventory/hosts.ini`

- [ ] **Step 1: `[proxmox_hosts]` 그룹과 walle 호스트 추가**

`proxmox/ansible/inventory/hosts.ini`에 추가:

```ini
[proxmox_hosts]
walle ansible_host=walle.bun-bull.ts.net ansible_user=root
```

파일 최상단(기존 `[heritage_hosts]` 위)에 배치.

- [ ] **Step 2: 인벤토리 확인**

Run: `cd proxmox/ansible && ansible-inventory --list`
Expected: `proxmox_hosts` 그룹에 `walle` 호스트 표시

- [ ] **Step 3: Commit**

```bash
git add proxmox/ansible/inventory/hosts.ini
git commit -m "feat: walle 호스트를 Ansible 인벤토리에 추가"
```

---

### Task 2: walle playbook 생성

**Files:**
- Create: `proxmox/ansible/playbooks/walle.yml`

- [ ] **Step 1: `walle.yml` playbook 작성**

heritage.yml의 Tailscale 패턴을 따름. 단순히 tailscale serve만 설정:

```yaml
---
- name: Configure walle Tailscale Serve
  hosts: proxmox_hosts
  gather_facts: false

  tasks:
    - name: Check current Tailscale Serve status
      ansible.builtin.command: tailscale serve status
      register: ts_serve_status
      changed_when: false
      failed_when: false

    - name: Configure Tailscale Serve (443 → 8006)
      ansible.builtin.shell:
        cmd: |
          tailscale serve reset
          tailscale serve --bg --set-path / https://127.0.0.1:8006
      when: "'https://127.0.0.1:8006' not in ts_serve_status.stdout"
      changed_when: true
```

- [ ] **Step 2: Syntax 검증**

Run: `cd proxmox/ansible && ansible-playbook playbooks/walle.yml --syntax-check`
Expected: "playbook: playbooks/walle.yml" (에러 없음)

- [ ] **Step 3: Commit**

```bash
git add proxmox/ansible/playbooks/walle.yml
git commit -m "feat: walle Tailscale Serve 설정 playbook 추가"
```

---

### Task 3: 배포 및 검증

**Files:** 변경 없음

- [ ] **Step 1: Playbook 실행**

Run: `cd proxmox/ansible && ansible-playbook playbooks/walle.yml`

Expected: `changed=1` (최초) 또는 `changed=0` (이미 설정된 경우)

- [ ] **Step 2: 443 포트 접속 확인**

Run: `curl -sI https://walle.bun-bull.ts.net`
Expected: `HTTP/2 200` + Proxmox 응답 헤더

- [ ] **Step 3: Idempotency 확인**

Run: `cd proxmox/ansible && ansible-playbook playbooks/walle.yml`
Expected: `changed=0`

- [ ] **Step 4: CLAUDE.md 업데이트 — Proxmox endpoint 변경 반영**

`proxmox/opentofu/variables.tf`의 `default = "https://walle.bun-bull.ts.net:8006"` → `443` 포트로 접속 가능하다는 내용을 CLAUDE.md Gotchas에 추가.

---

### Task 4: Push

- [ ] **Step 1: 모든 커밋 push**

```bash
git push origin main
```
