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
