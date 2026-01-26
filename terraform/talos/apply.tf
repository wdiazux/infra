# Talos Configuration Application
#
# This file handles applying the Talos machine configuration to the node,
# including DHCP IP detection and waiting for static IP assignment.

# ============================================================================
# DHCP IP Detection
# ============================================================================

# Wait for VM to boot and get DHCP IP (maintenance mode)
# Talos boots with DHCP first, then we apply config to set static IP
resource "null_resource" "wait_for_vm_dhcp" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-vm-dhcp.sh"

    environment = {
      PROXMOX_API_TOKEN = local.secrets.proxmox_api_token
      PROXMOX_URL       = local.secrets.proxmox_url
      PROXMOX_NODE      = var.proxmox_node
      VM_ID             = var.node_vm_id
      FALLBACK_IP       = var.node_ip
      OUTPUT_FILE       = "${path.module}/.talos_dhcp_ip"
    }
  }

  depends_on = [
    proxmox_virtual_environment_vm.talos_node
  ]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.talos_node.id
  }
}

# Read the detected DHCP IP
data "local_file" "talos_dhcp_ip" {
  filename   = "${path.module}/.talos_dhcp_ip"
  depends_on = [null_resource.wait_for_vm_dhcp]
}

# ============================================================================
# Configuration Application
# ============================================================================

# Apply Talos machine configuration to the node (using DHCP IP)
resource "talos_machine_configuration_apply" "node" {
  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.node.machine_configuration
  node                        = local.talos_initial_ip
  endpoint                    = local.talos_initial_ip

  # Optional: Wipe STATE and EPHEMERAL partitions on destroy
  # This provides a clean teardown but data will be lost
  on_destroy = {
    graceful = true                 # Try graceful shutdown first
    reboot   = false                # Don't reboot after reset
    reset    = var.reset_on_destroy # Wipe if var.reset_on_destroy is true
  }

  # Apply configuration after VM is created and DHCP IP detected
  depends_on = [
    null_resource.wait_for_vm_dhcp,
    data.local_file.talos_dhcp_ip
  ]
}

# ============================================================================
# Static IP Wait
# ============================================================================

# Wait for node to reboot with static IP after config is applied
resource "null_resource" "wait_for_static_ip" {
  provisioner "local-exec" {
    command = "${path.module}/scripts/wait-static-ip.sh"

    environment = {
      NODE_IP     = var.node_ip
      TALOSCONFIG = "${path.module}/talosconfig"
      OUTPUT_FILE = "${path.module}/.talos_dhcp_ip"
    }
  }

  depends_on = [
    talos_machine_configuration_apply.node
  ]

  triggers = {
    config_applied = talos_machine_configuration_apply.node.id
  }
}
