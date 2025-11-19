# Outputs for Proxmox VM Module

output "vm_id" {
  description = "The VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "vm_name" {
  description = "The VM name"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "node_name" {
  description = "The Proxmox node where VM is located"
  value       = proxmox_virtual_environment_vm.vm.node_name
}

output "template_id" {
  description = "The template VM ID that was cloned"
  value       = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
}

output "template_name" {
  description = "The template name that was cloned"
  value       = var.template_name
}

output "ipv4_addresses" {
  description = "List of IPv4 addresses (requires QEMU guest agent)"
  value       = try(proxmox_virtual_environment_vm.vm.ipv4_addresses, [])
}

output "ipv6_addresses" {
  description = "List of IPv6 addresses (requires QEMU guest agent)"
  value       = try(proxmox_virtual_environment_vm.vm.ipv6_addresses, [])
}

output "mac_addresses" {
  description = "List of MAC addresses"
  value       = try(proxmox_virtual_environment_vm.vm.mac_addresses, [])
}

output "cpu_cores" {
  description = "Number of CPU cores"
  value       = var.cpu_cores
}

output "memory_mb" {
  description = "Memory in MB"
  value       = var.memory
}

output "tags" {
  description = "VM tags"
  value       = var.tags
}
