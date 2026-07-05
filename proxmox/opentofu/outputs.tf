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
  # agent IP 수집 전/실패 시 null — DHCP IP는 hosts.ini/talconfig와 동일하게 수동 조회 fallback
  value       = try(proxmox_virtual_environment_vm.cockpit.ipv4_addresses[1][0], null)
  description = "cockpit VM IPv4 (agent 기반, eth0) — agent 수집 전 null"
}

output "cockpit_mac" {
  value       = proxmox_virtual_environment_vm.cockpit.mac_addresses[0]
  description = "cockpit VM MAC 주소"
}
