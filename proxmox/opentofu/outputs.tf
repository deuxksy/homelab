output "talos_master_mac" {
  value       = proxmox_virtual_environment_vm.talos_master.mac_addresses[0]
  description = "talos-master MAC 주소"
}

output "talos_worker_mac" {
  value       = proxmox_virtual_environment_vm.talos_worker.mac_addresses[0]
  description = "talos-worker MAC 주소"
}

output "heritage_ipv4" {
  value       = proxmox_virtual_environment_container.heritage.ipv4
  description = "heritage LXC IPv4 주소"
}

output "cockpit_vm_id" {
  value       = proxmox_virtual_environment_vm.cockpit.vm_id
  description = "cockpit VM ID"
}

output "cockpit_ipv4" {
  value       = proxmox_virtual_environment_vm.cockpit.ipv4_addresses[1][0]
  description = "cockpit VM IPv4 (agent 기반, eth0)"
}

output "cockpit_mac" {
  value       = proxmox_virtual_environment_vm.cockpit.mac_addresses[0]
  description = "cockpit VM MAC 주소"
}
