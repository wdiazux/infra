## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.2 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.3 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2.4 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.92.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.1.1 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.10.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.92.0 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.1.1 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_traditional_vm"></a> [traditional\_vm](#module\_traditional\_vm) | ./modules/proxmox-vm | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.configure_longhorn_namespace](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.install_gpu_operator](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.remove_control_plane_taint](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_kubernetes](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_static_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_vm_dhcp](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [proxmox_virtual_environment_vm.talos_node](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [talos_cluster_kubeconfig.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [local_file.talos_dhcp_ip](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [proxmox_virtual_environment_vms.talos_template](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_vms) | data source |
| [sops_file.proxmox_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [talos_client_configuration.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_scheduling_on_control_plane"></a> [allow\_scheduling\_on\_control\_plane](#input\_allow\_scheduling\_on\_control\_plane) | Allow pod scheduling on control plane (required for single-node) | `bool` | `true` | no |
| <a name="input_arch_template_name"></a> [arch\_template\_name](#input\_arch\_template\_name) | Arch Linux Packer template name in Proxmox | `string` | `"arch-cloud-template"` | no |
| <a name="input_auto_bootstrap"></a> [auto\_bootstrap](#input\_auto\_bootstrap) | Automatically bootstrap the cluster after creation | `bool` | `true` | no |
| <a name="input_auto_install_gpu_operator"></a> [auto\_install\_gpu\_operator](#input\_auto\_install\_gpu\_operator) | Automatically install NVIDIA GPU Operator after cluster bootstrap (requires enable\_gpu\_passthrough = true) | `bool` | `true` | no |
| <a name="input_cloud_init_password"></a> [cloud\_init\_password](#input\_cloud\_init\_password) | Fallback password if not in SOPS secrets (prefer SOPS) | `string` | `""` | no |
| <a name="input_cloud_init_ssh_keys"></a> [cloud\_init\_ssh\_keys](#input\_cloud\_init\_ssh\_keys) | Additional SSH keys (primary key comes from SOPS) | `list(string)` | `[]` | no |
| <a name="input_cloud_init_user"></a> [cloud\_init\_user](#input\_cloud\_init\_user) | Fallback username if not in SOPS secrets | `string` | `"wdiaz"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint (IP or DNS) | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Talos/Kubernetes cluster name | `string` | `"homelab-k8s"` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Tags applied to all traditional VMs | `list(string)` | <pre>[<br/>  "traditional-vm",<br/>  "packer-template"<br/>]</pre> | no |
| <a name="input_debian_template_name"></a> [debian\_template\_name](#input\_debian\_template\_name) | Debian Packer template name in Proxmox | `string` | `"debian-13-cloud-template"` | no |
| <a name="input_default_gateway"></a> [default\_gateway](#input\_default\_gateway) | Default gateway for static IP configurations | `string` | `"10.10.2.1"` | no |
| <a name="input_default_storage"></a> [default\_storage](#input\_default\_storage) | Default Proxmox storage pool for VM disks | `string` | `"tank"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the Proxmox VM | `string` | `"Talos Linux single-node Kubernetes cluster with NVIDIA GPU support"` | no |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | DNS domain for all VMs | `string` | `"local"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers for the node | `list(string)` | <pre>[<br/>  "10.10.2.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_enable_cloud_init"></a> [enable\_cloud\_init](#input\_enable\_cloud\_init) | Enable cloud-init for VM provisioning | `bool` | `true` | no |
| <a name="input_enable_gpu_passthrough"></a> [enable\_gpu\_passthrough](#input\_enable\_gpu\_passthrough) | Enable NVIDIA GPU passthrough to this node | `bool` | `true` | no |
| <a name="input_enable_qemu_agent"></a> [enable\_qemu\_agent](#input\_enable\_qemu\_agent) | Enable QEMU guest agent (included in template) | `bool` | `true` | no |
| <a name="input_generate_kubeconfig"></a> [generate\_kubeconfig](#input\_generate\_kubeconfig) | Generate kubeconfig file after bootstrap | `bool` | `true` | no |
| <a name="input_gpu_mapping"></a> [gpu\_mapping](#input\_gpu\_mapping) | GPU resource mapping name from Proxmox. Create in: Datacenter → Resource Mappings → Add → PCI Device | `string` | `"nvidia-gpu"` | no |
| <a name="input_gpu_pci_id"></a> [gpu\_pci\_id](#input\_gpu\_pci\_id) | PCI ID of the GPU to passthrough (e.g., '07:00'). Used with METHOD 2 (password auth). Find with: lspci \| grep -i nvidia | `string` | `"07:00"` | no |
| <a name="input_gpu_pcie"></a> [gpu\_pcie](#input\_gpu\_pcie) | Enable PCIe passthrough mode | `bool` | `true` | no |
| <a name="input_gpu_rombar"></a> [gpu\_rombar](#input\_gpu\_rombar) | Enable GPU ROM bar (false recommended for GPU passthrough) | `bool` | `false` | no |
| <a name="input_install_disk"></a> [install\_disk](#input\_install\_disk) | Disk device to install Talos on | `string` | `"/dev/sda"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to deploy (supported by Talos version) | `string` | `"v1.35.0"` | no |
| <a name="input_kubernetes_wait_timeout"></a> [kubernetes\_wait\_timeout](#input\_kubernetes\_wait\_timeout) | Maximum seconds to wait for Kubernetes API to be ready | `number` | `300` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Proxmox network bridge | `string` | `"vmbr0"` | no |
| <a name="input_network_model"></a> [network\_model](#input\_network\_model) | Network interface model | `string` | `"virtio"` | no |
| <a name="input_network_vlan"></a> [network\_vlan](#input\_network\_vlan) | VLAN tag (0 for none) | `number` | `0` | no |
| <a name="input_nfs_path"></a> [nfs\_path](#input\_nfs\_path) | NFS export path for Longhorn backup target (optional) | `string` | `"/mnt/tank/longhorn-backups"` | no |
| <a name="input_nfs_server"></a> [nfs\_server](#input\_nfs\_server) | NFS server IP or hostname for Longhorn backup target (optional) | `string` | `""` | no |
| <a name="input_nixos_template_name"></a> [nixos\_template\_name](#input\_nixos\_template\_name) | NixOS Packer template name in Proxmox | `string` | `"nixos-cloud-template"` | no |
| <a name="input_node_cpu_cores"></a> [node\_cpu\_cores](#input\_node\_cpu\_cores) | Number of CPU cores for the node | `number` | `8` | no |
| <a name="input_node_cpu_sockets"></a> [node\_cpu\_sockets](#input\_node\_cpu\_sockets) | Number of CPU sockets | `number` | `1` | no |
| <a name="input_node_cpu_type"></a> [node\_cpu\_type](#input\_node\_cpu\_type) | CPU type (must be 'host' for Talos v1.0+) | `string` | `"host"` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Disk size in GB for the node | `number` | `200` | no |
| <a name="input_node_disk_storage"></a> [node\_disk\_storage](#input\_node\_disk\_storage) | Proxmox storage pool for node disk | `string` | `"tank"` | no |
| <a name="input_node_gateway"></a> [node\_gateway](#input\_node\_gateway) | Network gateway for the Talos node | `string` | `"10.10.2.1"` | no |
| <a name="input_node_ip"></a> [node\_ip](#input\_node\_ip) | Static IP address for the Talos node (REQUIRED) | `string` | `""` | no |
| <a name="input_node_memory"></a> [node\_memory](#input\_node\_memory) | Memory in MB for the node | `number` | `32768` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Name for the Talos node VM | `string` | `"talos-node"` | no |
| <a name="input_node_netmask"></a> [node\_netmask](#input\_node\_netmask) | Network netmask (CIDR notation) | `number` | `24` | no |
| <a name="input_node_vm_id"></a> [node\_vm\_id](#input\_node\_vm\_id) | Proxmox VM ID for the Talos node (changed from 100 to avoid conflict with traditional VMs) | `number` | `1000` | no |
| <a name="input_ntp_servers"></a> [ntp\_servers](#input\_ntp\_servers) | NTP servers for time synchronization | `list(string)` | <pre>[<br/>  "time.cloudflare.com"<br/>]</pre> | no |
| <a name="input_proxmox_api_token"></a> [proxmox\_api\_token](#input\_proxmox\_api\_token) | Proxmox API token (recommended over password). Use TF\_VAR\_proxmox\_api\_token env var or set in terraform.tfvars | `string` | `null` | no |
| <a name="input_proxmox_insecure"></a> [proxmox\_insecure](#input\_proxmox\_insecure) | Skip TLS verification for self-signed certificates | `bool` | `true` | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | Proxmox node name where VMs will be created | `string` | `"pve"` | no |
| <a name="input_proxmox_password"></a> [proxmox\_password](#input\_proxmox\_password) | Proxmox password (use api\_token instead if possible) | `string` | `""` | no |
| <a name="input_proxmox_url"></a> [proxmox\_url](#input\_proxmox\_url) | Proxmox API endpoint URL | `string` | `"https://pve.home-infra.net:8006/api2/json"` | no |
| <a name="input_proxmox_username"></a> [proxmox\_username](#input\_proxmox\_username) | Proxmox username (format: user@pve for API-only access) | `string` | `"root@pve"` | no |
| <a name="input_reset_on_destroy"></a> [reset\_on\_destroy](#input\_reset\_on\_destroy) | Reset (wipe) Talos node when destroying (resets STATE and EPHEMERAL partitions) | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to Proxmox VM | `list(string)` | <pre>[<br/>  "talos",<br/>  "kubernetes",<br/>  "nvidia-gpu"<br/>]</pre> | no |
| <a name="input_talos_config_patches"></a> [talos\_config\_patches](#input\_talos\_config\_patches) | Additional Talos configuration patches (YAML) | `list(string)` | `[]` | no |
| <a name="input_talos_schematic_id"></a> [talos\_schematic\_id](#input\_talos\_schematic\_id) | Talos Factory schematic ID with required system extensions. REQUIRED for Longhorn storage (iscsi-tools, util-linux-tools). Generate at https://factory.talos.dev/ | `string` | `"b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"` | no |
| <a name="input_talos_template_name"></a> [talos\_template\_name](#input\_talos\_template\_name) | Name of the Talos template created by Packer | `string` | `"talos-1.12.1-nvidia-template"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (must match template version) | `string` | `"v1.12.1"` | no |
| <a name="input_ubuntu_template_name"></a> [ubuntu\_template\_name](#input\_ubuntu\_template\_name) | Ubuntu Packer template name in Proxmox | `string` | `"ubuntu-2404-cloud-template"` | no |
| <a name="input_windows_admin_password"></a> [windows\_admin\_password](#input\_windows\_admin\_password) | Fallback admin password if not in SOPS secrets (prefer SOPS) | `string` | `""` | no |
| <a name="input_windows_admin_user"></a> [windows\_admin\_user](#input\_windows\_admin\_user) | Fallback admin username if not in SOPS secrets | `string` | `"Administrator"` | no |
| <a name="input_windows_template_name"></a> [windows\_template\_name](#input\_windows\_template\_name) | Windows Packer template name in Proxmox | `string` | `"windows-11-golden-template"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_instructions"></a> [access\_instructions](#output\_access\_instructions) | Instructions for accessing the cluster |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | Kubernetes cluster CA certificate (sensitive) |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Talos/Kubernetes cluster name |
| <a name="output_deployed_vms_summary"></a> [deployed\_vms\_summary](#output\_deployed\_vms\_summary) | Summary of all deployed VMs (Talos + Traditional) |
| <a name="output_deployment_timestamp"></a> [deployment\_timestamp](#output\_deployment\_timestamp) | Timestamp of deployment |
| <a name="output_gpu_passthrough_enabled"></a> [gpu\_passthrough\_enabled](#output\_gpu\_passthrough\_enabled) | Whether NVIDIA GPU passthrough is enabled |
| <a name="output_gpu_pci_id"></a> [gpu\_pci\_id](#output\_gpu\_pci\_id) | PCI ID of passed-through GPU (if enabled) |
| <a name="output_gpu_verification_command"></a> [gpu\_verification\_command](#output\_gpu\_verification\_command) | Command to verify GPU passthrough in a pod |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to generated kubeconfig file |
| <a name="output_kubernetes_version"></a> [kubernetes\_version](#output\_kubernetes\_version) | Kubernetes version deployed |
| <a name="output_network_configuration"></a> [network\_configuration](#output\_network\_configuration) | Network configuration summary |
| <a name="output_node_ip"></a> [node\_ip](#output\_node\_ip) | Talos node IP address |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Talos node name |
| <a name="output_node_resources"></a> [node\_resources](#output\_node\_resources) | Node hardware resources |
| <a name="output_node_vm_id"></a> [node\_vm\_id](#output\_node\_vm\_id) | Proxmox VM ID for the node |
| <a name="output_ssh_commands"></a> [ssh\_commands](#output\_ssh\_commands) | SSH commands to connect to each VM |
| <a name="output_storage_configuration"></a> [storage\_configuration](#output\_storage\_configuration) | Storage configuration summary |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Talos client configuration (sensitive) |
| <a name="output_talos_version"></a> [talos\_version](#output\_talos\_version) | Talos Linux version deployed |
| <a name="output_talosconfig_path"></a> [talosconfig\_path](#output\_talosconfig\_path) | Path to generated talosconfig file |
| <a name="output_terraform_workspace"></a> [terraform\_workspace](#output\_terraform\_workspace) | Current Terraform workspace |
| <a name="output_traditional_vm_count"></a> [traditional\_vm\_count](#output\_traditional\_vm\_count) | Count of deployed traditional VMs by OS type |
| <a name="output_traditional_vm_ips"></a> [traditional\_vm\_ips](#output\_traditional\_vm\_ips) | Quick lookup of VM IPs (name => first IP) |
| <a name="output_traditional_vms"></a> [traditional\_vms](#output\_traditional\_vms) | All deployed traditional VMs with their details |
| <a name="output_useful_commands"></a> [useful\_commands](#output\_useful\_commands) | Useful commands for managing the cluster |
