# Homelab Proxmox IaC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** walle(Proxmox VE)에 OpenTofu + Ansible + Talos로 인프라를 코드로 관리하는 환경 구축

**Architecture:** 단일 Proxmox 노드에 VM 2대(Talos master/worker) + LXC 1대(heritage) 구성. OpenTofu로 프로비저닝, Talosctl로 K8s 부트스트랩, Ansible로 heritage 배포.

**Tech Stack:** OpenTofu (bpg/proxmox v0.70+), Talos Linux, talhelper, Ansible, sops

**Spec:** `docs/superpowers/specs/2026-05-24-homelab-proxmox-iac-design.md`

---

## File Structure

```
homelab/
├── .sops.yaml                           # sops 암호화 설정
├── .gitignore
├── .mise.toml                           # 도구 버전 고정 (tofu, talosctl, talhelper, ansible)
├── README.md
├── proxmox/
│   ├── opentofu/
│   │   ├── versions.tf                  # tofu required_version, provider 버전
│   │   ├── variables.tf                 # Proxmox 접속 정보, 리소스 사양 변수
│   │   ├── main.tf                      # provider 블록, locals
│   │   ├── templates.tf                 # Talos 템플릿 data 소스
│   │   ├── talos.tf                     # talos-master, talos-worker VM 리소스
│   │   ├── heritage.tf                  # heritage LXC 리소스
│   │   ├── outputs.tf                   # IP 주소 등 출력
│   │   └── secrets.sops.yaml            # sops 암호화된 민감 변수
│   └── ansible/
│       ├── ansible.cfg                  # Ansible 설정
│       ├── inventory/
│       │   └── hosts.ini                # 정적 인벤토리 (tofu output 기반 수동 갱신)
│       └── playbooks/
│           ├── heritage.yml             # heritage LXC: Docker + compose 배포
│           └── talos-bootstrap.yml      # localhost: talosctl로 Talos 클러스터 초기화
├── k8s/
│   ├── talconfig.yaml                   # talhelper 클러스터 설정
│   └── manifests/                       # K8s 애드온 매니페스트 (향후)
└── docs/
    └── architecture.md
```

---

### Task 1: Repo 기반 설정

**Files:**
- Create: `.gitignore`
- Create: `.sops.yaml`
- Create: `.mise.toml`
- Create: `README.md`

- [ ] **Step 1: `.gitignore` 작성**

```gitignore
# OpenTofu
proxmox/opentofu/.terraform/
proxmox/opentofu/*.tfstate
proxmox/opentofu/*.tfstate.*
proxmox/opentofu/.terraform.lock.hcl

# Sops
secrets.sops.yaml.dec

# OS
.DS_Store
```

- [ ] **Step 2: `.sops.yaml` 작성** — 기존 dotfiles와 동일한 age 키 사용

```yaml
keys:
  - &crong age1qw643dna4spaup6sr5ap0jf039ncjd54e8ekvrfy6p6x96ys2y4qn5vcsy

creation_rules:
  - path_regex: ^.*\.sops\.ya?ml$
    key_groups:
      - age:
          - *crong
```

- [ ] **Step 3: `.mise.toml` 작성** — 필요 도구 버전 고정

```toml
[tools]
tofu = "1.9"
talosctl = "1.10"
talhelper = "latest"
"python:ansible" = "latest"
```

- [ ] **Step 4: `README.md` 작성**

```markdown
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
```

- [ ] **Step 5: 커밋**

```bash
git add .gitignore .sops.yaml .mise.toml README.md
git commit -m "chore: initialize repo with gitignore, sops, mise, and README"
```

---

### Task 2: 도구 설치

**Files:** 없음 (로컬 환경 설정)

- [ ] **Step 1: mise로 도구 설치**

```bash
cd ~/git/homelab && mise install
```

- [ ] **Step 2: 설치 확인**

```bash
tofu version          # OpenTofu v1.9.x
talosctl version      # v1.10.x
talhelper version     # latest
ansible --version     # core 2.x
```

Expected: 모든 명령어 실행 가능

---

### Task 3: OpenTofu 기반 — Provider + Variables

**Files:**
- Create: `proxmox/opentofu/versions.tf`
- Create: `proxmox/opentofu/variables.tf`
- Create: `proxmox/opentofu/main.tf`
- Create: `proxmox/opentofu/secrets.sops.yaml`

- [ ] **Step 1: `versions.tf` 작성**

```hcl
terraform {
  required_version = ">= 1.8"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.1"
    }
  }
}
```

- [ ] **Step 2: `variables.tf` 작성**

```hcl
variable "proxmox_node" {
  type    = string
  default = "walle"
}

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
  default     = "https://192.168.221.198:8006"
}

variable "talos_template_vmid" {
  type    = number
  default = 900
  description = "Talos VM 템플릿 ID (사전 수동 생성)"
}

variable "talos_master_vmid" {
  type    = number
  default = 100
}

variable "talos_worker_vmid" {
  type    = number
  default = 101
}

variable "heritage_vmid" {
  type    = number
  default = 200
}

variable "talos_master_resources" {
  type = object({
    cores   = number
    memory  = number
    disk    = number
  })
  default = {
    cores  = 2
    memory = 1536
    disk   = 20
  }
}

variable "talos_worker_resources" {
  type = object({
    cores   = number
    memory  = number
    disk    = number
  })
  default = {
    cores  = 2
    memory = 2560
    disk   = 30
  }
}

variable "heritage_resources" {
  type = object({
    cores  = number
    memory = number
    swap   = number
    disk   = number
  })
  default = {
    cores  = 2
    memory = 1536
    swap   = 512
    disk   = 50
  }
}
```

- [ ] **Step 3: `secrets.sops.yaml` 작성 (평문 → sops 암호화)**

먼저 평문 파일 생성:

```yaml
proxmox_api_token: "root@pam!tofu=CHANGE_ME"
```

sops로 암호화:

```bash
cd proxmox/opentofu
sops -e secrets.sops.yaml > secrets.sops.yaml.enc && mv secrets.sops.yaml.enc secrets.sops.yaml
```

- [ ] **Step 4: `main.tf` 작성**

```hcl
data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = data.sops_file.secrets.data["proxmox_api_token"]

  ssh {
    username = "root"
    agent    = true
  }

  tmp_dir = "/var/tmp"
}
```

- [ ] **Step 5: `tofu init` 및 validate**

```bash
cd proxmox/opentofu
tofu init
tofu validate
```

Expected: `OpenTofu has been successfully initialized!`, `The configuration is valid`

- [ ] **Step 6: 커밋**

```bash
git add proxmox/opentofu/
git commit -m "feat(opentofu): add provider, variables, and sops secrets"
```

---

### Task 4: OpenTofu — Talos VM 리소스

**Files:**
- Create: `proxmox/opentofu/templates.tf`
- Create: `proxmox/opentofu/talos.tf`

- [ ] **Step 1: `templates.tf` 작성**

```hcl
data "proxmox_virtual_environment_vm" "talos_template" {
  vm_id     = var.talos_template_vmid
  node_name = var.proxmox_node
}
```

- [ ] **Step 2: `talos.tf` 작성**

```hcl
resource "proxmox_virtual_environment_vm" "talos_master" {
  name        = "talos-master"
  vm_id       = var.talos_master_vmid
  node_name   = var.proxmox_node
  description = "Talos Linux K8s control-plane"
  started     = true

  clone {
    vm_id = data.proxmox_virtual_environment_vm.talos_template.id
  }

  cpu {
    cores = var.talos_master_resources.cores
    type  = "host"
  }

  memory {
    dedicated = var.talos_master_resources.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.talos_master_resources.disk
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
  }

  vga {}
}

resource "proxmox_virtual_environment_vm" "talos_worker" {
  name        = "talos-worker"
  vm_id       = var.talos_worker_vmid
  node_name   = var.proxmox_node
  description = "Talos Linux K8s worker"
  started     = true

  clone {
    vm_id = data.proxmox_virtual_environment_vm.talos_template.id
  }

  cpu {
    cores = var.talos_worker_resources.cores
    type  = "host"
  }

  memory {
    dedicated = var.talos_worker_resources.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.talos_worker_resources.disk
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
  }

  vga {}
}
```

- [ ] **Step 3: validate**

```bash
cd proxmox/opentofu
tofu validate
```

Expected: `The configuration is valid`

- [ ] **Step 4: 커밋**

```bash
git add proxmox/opentofu/templates.tf proxmox/opentofu/talos.tf
git commit -m "feat(opentofu): add Talos VM resources (master + worker)"
```

---

### Task 5: OpenTofu — Heritage LXC 리소스

**Files:**
- Create: `proxmox/opentofu/heritage.tf`

- [ ] **Step 1: `heritage.tf` 작성**

```hcl
resource "proxmox_virtual_environment_container" "heritage" {
  node_name    = var.proxmox_node
  vm_id        = var.heritage_vmid
  hostname     = "heritage"
  description  = "Heritage media server (Docker Compose)"

  ostemplate = "local:vztmpl/debian-12-standard.tar.zst"

  cpu {
    cores = var.heritage_resources.cores
  }

  memory {
    dedicated = var.heritage_resources.memory
    swap      = var.heritage_resources.swap
  }

  rootfs {
    datastore_id = "local-lvm"
    size         = var.heritage_resources.disk
  }

  features {
    nesting = true
  }

  mount_point {
    volume = "/mnt/data1"
    path   = "/mnt/data1"
  }

  mount_point {
    volume = "/mnt/data2"
    path   = "/mnt/data2"
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    dhcp    = true
  }

  started = true
}
```

- [ ] **Step 2: validate**

```bash
cd proxmox/opentofu
tofu validate
```

Expected: `The configuration is valid`

- [ ] **Step 3: 커밋**

```bash
git add proxmox/opentofu/heritage.tf
git commit -m "feat(opentofu): add heritage LXC resource"
```

---

### Task 6: OpenTofu — Outputs

**Files:**
- Create: `proxmox/opentofu/outputs.tf`

- [ ] **Step 1: `outputs.tf` 작성**

```hcl
output "talos_master_ipv4" {
  value       = proxmox_virtual_environment_vm.talos_master.ipv4_addresses[0]
  description = "talos-master IPv4 주소"
}

output "talos_worker_ipv4" {
  value       = proxmox_virtual_environment_vm.talos_worker.ipv4_addresses[0]
  description = "talos-worker IPv4 주소"
}

output "heritage_ipv4" {
  value       = proxmox_virtual_environment_container.heritage.ipv4_address
  description = "heritage LXC IPv4 주소"
}
```

- [ ] **Step 2: validate**

```bash
cd proxmox/opentofu
tofu validate
```

Expected: `The configuration is valid`

- [ ] **Step 3: 커밋**

```bash
git add proxmox/opentofu/outputs.tf
git commit -m "feat(opentofu): add VM/LXC IP outputs"
```

---

### Task 7: Talos 템플릿 준비 (수동 + 스크립트)

**Files:**
- Create: `scripts/create-talos-template.sh`

이 태스크는 walle Proxmox에서 직접 실행해야 함.

- [ ] **Step 1: Talos ISO 다운로드**

Proxmox walle 호스트에서:

```bash
cd /var/lib/vz/template/iso
wget https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f2798332989bf6f71f519/v1.10.5/metal-amd64.iso
```

> 이미지 URL은 https://factory.talos.dev 에서 확인. `metal-amd64.iso` 선택.

- [ ] **Step 2: 템플릿 VM 생성 스크립트 작성**

```bash
#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_VMID=900
ISO_NAME="metal-amd64.iso"
STORAGE="local-lvm"

echo "Creating Talos template VM (ID: ${TEMPLATE_VMID})..."

qm create ${TEMPLATE_VMID} \
  --name "talos-template" \
  --bios seabios \
  --cores 2 \
  --memory 1024 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --disk ${STORAGE}:vm-${TEMPLATE_VMID}-disk-0,size=10G \
  --cdrom local:iso/${ISO_NAME} \
  --boot order=scsi0 \
  --agent enabled=1

echo "Converting to template..."
qm template ${TEMPLATE_VMID}

echo "Talos template (VM ${TEMPLATE_VMID}) created."
```

- [ ] **Step 3: walle에서 스크립트 실행**

```bash
ssh root@192.168.221.198 'bash -s' < scripts/create-talos-template.sh
```

- [ ] **Step 4: 템플릿 확인**

```bash
ssh root@192.168.221.198 'qm list | grep 900'
```

Expected: VM 900이 존재하고 status가 stopped (template)

- [ ] **Step 5: 커밋**

```bash
git add scripts/
git commit -m "feat(scripts): add Talos template creation script"
```

---

### Task 8: 첫 `tofu apply` — VM/LXC 프로비저닝

**사전 조건:** Task 7 완료 (Talos 템플릿 존재), Proxmox API Token 생성됨

- [ ] **Step 1: Proxmox API Token 생성 (수동)**

Proxmox Web UI (`https://192.168.221.198:8006`):
1. Datacenter → Permissions → API Tokens
2. User: `root@pam`, Token ID: `tofu`
3. Privilege: `Administrator` (체크 해제 시 최소 권한 필요)
4. 생성된 시크릿을 `secrets.sops.yaml`에 기록 후 sops 재암호화

```bash
cd proxmox/opentofu
# 평문으로 업데이트 후 재암호화
sops secrets.sops.yaml
# 파일 내 proxmox_api_token 값을 실제 토큰으로 변경
```

- [ ] **Step 2: `tofu plan` 실행**

```bash
cd proxmox/opentofu
tofu plan
```

Expected: Plan에 3개 리소스 생성 표시 (2 VM + 1 LXC)

- [ ] **Step 3: `tofu apply` 실행**

```bash
tofu apply
```

Expected: VM 100, 101, LXC 200 생성됨

- [ ] **Step 4: 생성 확인**

```bash
tofu output
```

Expected: talos_master_ipv4, talos_worker_ipv4, heritage_ipv4에 DHCP 할당 IP 표시

- [ ] **Step 5: `.terraform.lock.hcl` 커밋**

```bash
git add proxmox/opentofu/.terraform.lock.hcl
git commit -m "chore(opentofu): lock provider versions after first apply"
```

---

### Task 9: Ansible 기반 설정

**Files:**
- Create: `proxmox/ansible/ansible.cfg`
- Create: `proxmox/ansible/inventory/hosts.ini`

- [ ] **Step 1: `ansible.cfg` 작성**

```ini
[defaults]
inventory = inventory/hosts.ini
host_key_checking = False
private_key_file = ~/.ssh/id_ed25519
stdout_callback = yaml
```

- [ ] **Step 2: `inventory/hosts.ini` 작성** — tofu output으로 얻은 IP 입력

```ini
[heritage]
heritage ansible_host=TOFU_OUTPUT_IP ansible_user=root

[talos:children]
talos_master
talos_worker

[talos_master]
talos-master ansible_host=TOFU_OUTPUT_IP ansible_connection=local

[talos_worker]
talos-worker ansible_host=TOFU_OUTPUT_IP ansible_connection=local

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

> Talos 노드는 SSH 미지원 → `ansible_connection=local` 사용. talosctl은 localhost에서 실행.

- [ ] **Step 3: syntax-check**

```bash
cd proxmox/ansible
ansible-inventory --list
ansible all --list-hosts
```

Expected: 인벤토리에 3개 호스트 표시

- [ ] **Step 4: 커밋**

```bash
git add proxmox/ansible/
git commit -m "feat(ansible): add config and inventory"
```

---

### Task 10: Talos 클러스터 부트스트랩

**Files:**
- Create: `k8s/talconfig.yaml`
- Create: `proxmox/ansible/playbooks/talos-bootstrap.yml`

- [ ] **Step 1: `k8s/talconfig.yaml` 작성** — talhelper 설정

```yaml
clusterName: homelab
talosVersion: v1.10
kubernetesVersion: v1.32.5
endpoint: https://<TOFU_OUTPUT_MASTER_IP>:6443

nodes:
  - hostname: talos-master
    ipAddress: <TOFU_OUTPUT_MASTER_IP>
    controlPlane: true
    installDiskSelector:
      size: "<= 20GB"
    machineSpec:
      mode: metal
  - hostname: talos-worker
    ipAddress: <TOFU_OUTPUT_WORKER_IP>
    controlPlane: false
    installDiskSelector:
      size: "<= 30GB"
    machineSpec:
      mode: metal

worker:
  nodeLabels:
    node-role.kubernetes.io/worker: ""
```

> `<TOFU_OUTPUT_*_IP>`는 `tofu output` 결과로 치환.

- [ ] **Step 2: `playbooks/talos-bootstrap.yml` 작성**

```yaml
---
- name: Bootstrap Talos K8s cluster
  hosts: localhost
  gather_facts: false
  vars:
    k8s_dir: "{{ playbook_dir }}/../k8s"

  tasks:
    - name: Generate Talos configs with talhelper
      ansible.builtin.command:
        cmd: talhelper genconfig
        chdir: "{{ k8s_dir }}"
      changed_when: true

    - name: Apply machine config to master
      ansible.builtin.command:
        cmd: >-
          talosctl apply-config
          --nodes {{ hostvars['talos-master']['ansible_host'] }}
          --file {{ k8s_dir }}/clusterconfig/homelab-talos-master.yaml
          --insecure
      changed_when: true

    - name: Wait for master to be ready
      ansible.builtin.pause:
        seconds: 60

    - name: Apply machine config to worker
      ansible.builtin.command:
        cmd: >-
          talosctl apply-config
          --nodes {{ hostvars['talos-worker']['ansible_host'] }}
          --file {{ k8s_dir }}/clusterconfig/homelab-talos-worker.yaml
          --insecure
      changed_when: true

    - name: Bootstrap K8s cluster
      ansible.builtin.command:
        cmd: >-
          talosctl bootstrap
          --nodes {{ hostvars['talos-master']['ansible_host'] }}
          --endpoints {{ hostvars['talos-master']['ansible_host'] }}
      environment:
        TALOSCONFIG: "{{ k8s_dir }}/talosconfig"
      changed_when: true

    - name: Fetch kubeconfig
      ansible.builtin.command:
        cmd: >-
          talosctl kubeconfig
          --nodes {{ hostvars['talos-master']['ansible_host'] }}
          --endpoints {{ hostvars['talos-master']['ansible_host'] }}
          {{ playbook_dir }}/../../kubeconfig
      environment:
        TALOSCONFIG: "{{ k8s_dir }}/talosconfig"
      changed_when: true

    - name: Verify nodes
      ansible.builtin.command:
        cmd: kubectl --kubeconfig {{ playbook_dir }}/../../kubeconfig get nodes
      changed_when: false
      register: nodes_result

    - name: Show nodes
      ansible.builtin.debug:
        msg: "{{ nodes_result.stdout_lines }}"
```

- [ ] **Step 3: syntax-check**

```bash
cd proxmox/ansible
ansible-playbook playbooks/talos-bootstrap.yml --syntax-check
```

Expected: `playbook: playbooks/talos-bootstrap.yml` (에러 없음)

- [ ] **Step 4: 커밋**

```bash
git add k8s/talconfig.yaml proxmox/ansible/playbooks/talos-bootstrap.yml
git commit -m "feat(talos): add cluster config and bootstrap playbook"
```

---

### Task 11: Heritage LXC 배포 Playbook

**Files:**
- Create: `proxmox/ansible/playbooks/heritage.yml`

- [ ] **Step 1: `playbooks/heritage.yml` 작성**

```yaml
---
- name: Deploy heritage media server
  hosts: heritage
  gather_facts: true
  vars:
    heritage_repo: /opt/heritage

  tasks:
    - name: Install dependencies
      ansible.builtin.apt:
        name:
          - curl
          - git
          - ca-certificates
          - gnupg
        state: present
        update_cache: true

    - name: Add Docker GPG key
      ansible.builtin.shell:
        cmd: |
          install -m 0755 -d /etc/apt/keyrings
          curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
          chmod a+r /etc/apt/keyrings/docker.asc
      changed_when: true

    - name: Add Docker repository
      ansible.builtin.apt_repository:
        repo: >-
          deb [arch={{ ansible_architecture | replace('x86_64', 'amd64') }}
          signed-by=/etc/apt/keyrings/docker.asc]
          https://download.docker.com/linux/debian
          {{ ansible_distribution_release }} stable
        state: present
        update_cache: true

    - name: Install Docker
      ansible.builtin.apt:
        name:
          - docker-ce
          - docker-ce-cli
          - containerd.io
          - docker-compose-plugin
        state: present

    - name: Clone heritage repo
      ansible.builtin.git:
        repo: git@github.com:deuxksy/heritage.git
        dest: "{{ heritage_repo }}"
        version: main
        accept_hostkey: true

    - name: Decrypt .env.sops
      ansible.builtin.shell:
        cmd: sops -d .env.sops > .env
        chdir: "{{ heritage_repo }}"
      changed_when: true

    - name: Start heritage services
      community.docker.docker_compose_v2:
        project_src: "{{ heritage_repo }}"
        state: present
      environment:
        DOCKER_HOST: unix:///run/docker.sock

    - name: Wait for services
      ansible.builtin.pause:
        seconds: 30

    - name: Verify Jellyfin is responding
      ansible.builtin.uri:
        url: "http://localhost:8096/health"
        status_code: 200
        timeout: 10
      register: health
      until: health.status == 200
      retries: 5
      delay: 10
```

- [ ] **Step 2: syntax-check**

```bash
cd proxmox/ansible
ansible-playbook playbooks/heritage.yml --syntax-check
```

Expected: `playbook: playbooks/heritage.yml` (에러 없음)

- [ ] **Step 3: 커밋**

```bash
git add proxmox/ansible/playbooks/heritage.yml
git commit -m "feat(ansible): add heritage deployment playbook"
```

---

### Task 12: 문서 작성

**Files:**
- Create: `docs/architecture.md`

- [ ] **Step 1: `docs/architecture.md` 작성**

```markdown
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
```

- [ ] **Step 2: 커밋**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture documentation"
```

---

## Self-Review

### Spec Coverage

| 스펙 요구사항 | 태스크 |
| :--- | :--- |
| VM 2대 (Talos master/worker) | Task 4, 7, 8 |
| LXC 1대 (heritage, Debian 12) | Task 5, 8 |
| OpenTofu (bpg/proxmox) | Task 3, 4, 5, 6 |
| Cloud-init 템플릿 | Task 7 (Talos ISO 템플릿) |
| Talos K8s | Task 10 |
| Ansible heritage 배포 | Task 11 |
| sops secrets | Task 3 |
| vmbr0 + DHCP | Task 4, 5 |
| bind mount (/mnt/data1, /mnt/data2) | Task 5 |
| Repo 구조 | Task 1 |

### Placeholder Scan

- `CHANGE_ME` in secrets.sops.yaml — 실제 토큰은 Task 8에서 수동 입력
- `<TOFU_OUTPUT_*>` in talconfig.yaml — Task 8 apply 후 실제 IP로 치환
- Placeholders 없음 (모든 코드에 실제 구현 포함)

### Type Consistency

- VM ID: `var.talos_master_vmid` (100), `var.talos_worker_vmid` (101), `var.heritage_vmid` (200) — 변수와 리소스 일치
- Resource names: `proxmox_virtual_environment_vm.talos_master`, `.talos_worker`, `proxmox_virtual_environment_container.heritage` — outputs와 playbooks에서 동일 참조
