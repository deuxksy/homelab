resource "proxmox_virtual_environment_vm" "cockpit" {
  name        = "cockpit"
  vm_id       = var.cockpit_vmid
  node_name   = var.proxmox_node
  description = "Cockpit web management (Ubuntu 24.04 LTS)"
  started     = true
  tags        = ["monitoring", "cockpit"]

  clone {
    vm_id = var.cockpit_template_vmid
    full  = true
  }

  cpu {
    cores = var.cockpit_resources.cores
    type  = "host"
  }

  memory {
    dedicated = var.cockpit_resources.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.cockpit_resources.disk
    interface    = "scsi0"
  }

  # Ubuntu 24.04는 QEMU guest agent 지원 → agent로 IP 인식
  agent {
    enabled = true
  }

  # cloud-init은 초기 SSH 접근 확보용만 (bootstrap user).
  # cockpit-admin 계정/비밀번호/Tailscale은 Ansible이 담당 (회사 서버 재현성, design R5).
  initialization {
    user_account {
      username = "ubuntu"
      keys     = [file("/home/deck/.ssh/id_ed25519.pub")]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = "vmbr0"
  }

  vga {}
}
