resource "proxmox_virtual_environment_container" "heritage" {
  node_name   = var.proxmox_node
  vm_id       = var.heritage_vmid
  description = "Heritage media server (Docker Compose)"

  unprivileged = true

  initialization {
    hostname = "heritage"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  cpu {
    cores = var.heritage_resources.cores
  }

  memory {
    dedicated = var.heritage_resources.memory
    swap      = var.heritage_resources.swap
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.heritage_resources.disk
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
    type             = "debian"
  }

  features {
    nesting = true
    keyctl  = true
  }

  # Tailscale용 TUN 디바이스는 pct set --dev0 /dev/net/tun으로 수동 설정 필요
  # provider v0.106 미지원

  mount_point {
    volume = "/mnt/data1"
    path   = "/mnt/data1"
  }

  mount_point {
    volume = "/mnt/data2"
    path   = "/mnt/data2"
  }

  network_interface {
    name   = "veth0"
    bridge = "vmbr0"
  }

  started = true
}
