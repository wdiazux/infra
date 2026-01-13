# Outputs for Traditional VMs

# ============================================================================
# VM Information
# ============================================================================

output "vms" {
  description = "All deployed traditional VMs"
  value = {
    for name, vm in module.traditional_vm : name => {
      vm_id          = vm.vm_id
      vm_name        = vm.vm_name
      ipv4_addresses = vm.ipv4_addresses
      os_type        = local.traditional_vms[name].os_type
      description    = local.traditional_vms[name].description
    }
  }
}

output "vm_count" {
  description = "Count of deployed VMs by OS type"
  value       = local.vm_counts
}

output "vm_ips" {
  description = "Quick lookup of VM IPs"
  value = {
    for name, vm in module.traditional_vm : name => (
      length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0
      ? vm.ipv4_addresses[0][0]
      : "pending"
    )
  }
}

# ============================================================================
# SSH Commands
# ============================================================================

output "ssh_commands" {
  description = "SSH commands to connect to each VM"
  sensitive   = true
  value = {
    for name, vm in module.traditional_vm : name => (
      local.traditional_vms[name].os_type != "windows"
      ? "ssh ${local.secrets.cloud_init_user}@${length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0 ? vm.ipv4_addresses[0][0] : "PENDING"}"
      : "# Windows: Use RDP to ${length(vm.ipv4_addresses) > 0 && length(vm.ipv4_addresses[0]) > 0 ? vm.ipv4_addresses[0][0] : "PENDING"}"
    )
  }
}

# ============================================================================
# Summary
# ============================================================================

output "summary" {
  description = "Deployment summary"
  value = {
    total_vms = local.vm_counts.total
    by_os     = local.vm_counts
    vms = {
      for name, vm in module.traditional_vm : name => {
        vm_id   = vm.vm_id
        os_type = local.traditional_vms[name].os_type
      }
    }
  }
}
