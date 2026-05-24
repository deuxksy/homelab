resource "proxmox_virtual_environment_vm" "talos_master" {
  name        = "talos-master"
  vm_id       = var.talos_master_vmid
  node_name   = var.proxmox_node
  description = "Talos Linux K8s control-plane"
  started     = false

  clone {
    vm_id = var.talos_template_vmid
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
  started     = false

  clone {
    vm_id = var.talos_template_vmid
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
