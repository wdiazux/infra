# Talos Machine Secrets and Client Configuration
#
# This file manages Talos cluster secrets (CA, bootstrap tokens) and
# client configuration for talosctl access.

# ============================================================================
# Machine Secrets
# ============================================================================

# Generate Talos secrets (cluster CA, bootstrap token, etc.)
# IMPORTANT: These secrets contain cluster CA and bootstrap tokens.
#
# To rotate secrets (recommended annually per Talos production notes):
# 1. terraform state rm talos_machine_secrets.cluster
# 2. terraform apply (will regenerate secrets)
# 3. Reapply machine configuration to all nodes
# 4. Manually rotate client certificates via talosctl
resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version

  # Prevent accidental destruction of cluster secrets
  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================================
# Client Configuration
# ============================================================================

# Generate client configuration for talosctl
data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  endpoints            = [var.node_ip]
  nodes                = [var.node_ip]
}

# Save talosconfig to file
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.cluster.talos_config
  filename        = local.talosconfig_path
  file_permission = "0600"
}
