# Provider Configuration
#
# Proxmox and Talos provider setup

# Proxmox Provider
provider "proxmox" {
  endpoint  = local.secrets.proxmox_url
  api_token = local.secrets.proxmox_api_token
  insecure  = local.secrets.proxmox_tls_insecure
}

# Talos Provider
provider "talos" {
  # No explicit configuration needed
  # Uses endpoints from talos_machine_configuration resources
}

# Helm Provider (template) - for rendering Cilium inline manifest
# This provider alias has NO kubernetes config, used only for helm_template
# which does local template rendering without cluster connectivity.
provider "helm" {
  alias = "template"
  # No kubernetes block - template rendering is local only
}

# Helm Provider - for installing Longhorn (requires cluster)
provider "helm" {
  kubernetes = {
    host                   = "https://${var.node_ip}:6443"
    client_certificate     = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.client_certificate, ""))
    client_key             = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.client_key, ""))
    cluster_ca_certificate = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.ca_certificate, ""))
  }
}

# Kubernetes Provider - for creating CRDs and other resources
provider "kubernetes" {
  host                   = "https://${var.node_ip}:6443"
  client_certificate     = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.client_certificate, ""))
  client_key             = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.client_key, ""))
  cluster_ca_certificate = base64decode(try(talos_cluster_kubeconfig.cluster[0].kubernetes_client_configuration.ca_certificate, ""))
}

