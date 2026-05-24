output "talos_master_ipv4" {
  value       = proxmox_virtual_environment_vm.talos_master.ipv4_addresses[0]
  description = "talos-master IPv4 주소"
}

output "talos_worker_ipv4" {
  value       = proxmox_virtual_environment_vm.talos_worker.ipv4_addresses[0]
  description = "talos-worker IPv4 주소"
}

output "heritage_ipv4" {
  value       = values(proxmox_virtual_environment_container.heritage.ipv4)[0]
  description = "heritage LXC IPv4 주소"
}
