## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.3 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2.4 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.92.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.1.1 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.10.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_helm.template"></a> [helm.template](#provider\_helm.template) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.36.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.92.0 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.1.1 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.forgejo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.longhorn](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_manifest.nvidia_device_plugin](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_manifest.nvidia_runtimeclass](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace.forgejo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.longhorn](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.longhorn_backup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [local_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.create_sops_age_secret](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_bootstrap](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_verify](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.forgejo_create_repo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.forgejo_generate_token](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.label_node_for_longhorn](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.remove_control_plane_taint](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_cilium](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_forgejo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_kubernetes](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_static_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_vm_dhcp](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [proxmox_virtual_environment_vm.talos_node](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [talos_cluster_kubeconfig.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [helm_template.cilium](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [local_file.forgejo_flux_token](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.talos_dhcp_ip](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [proxmox_virtual_environment_vms.talos_template](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_vms) | data source |
| [sops_file.git_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [sops_file.nas_backup_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [sops_file.proxmox_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [talos_client_configuration.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_scheduling_on_control_plane"></a> [allow\_scheduling\_on\_control\_plane](#input\_allow\_scheduling\_on\_control\_plane) | Allow pod scheduling on control plane (required for single-node) | `bool` | `true` | no |
| <a name="input_auto_bootstrap"></a> [auto\_bootstrap](#input\_auto\_bootstrap) | Automatically bootstrap the cluster | `bool` | `true` | no |
| <a name="input_auto_install_gpu_device_plugin"></a> [auto\_install\_gpu\_device\_plugin](#input\_auto\_install\_gpu\_device\_plugin) | Automatically install NVIDIA device plugin after bootstrap | `bool` | `true` | no |
| <a name="input_cilium_lb_pool_cidr"></a> [cilium\_lb\_pool\_cidr](#input\_cilium\_lb\_pool\_cidr) | CIDR for Cilium L2 LoadBalancer IP pool | `string` | `"10.10.2.240/28"` | no |
| <a name="input_cilium_version"></a> [cilium\_version](#input\_cilium\_version) | Cilium Helm chart version | `string` | `"1.18.5"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint (defaults to node IP) | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Talos/Kubernetes cluster name | `string` | `"homelab-k8s"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the Proxmox VM | `string` | `"Talos Linux single-node Kubernetes cluster with NVIDIA GPU support"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers for the node | `list(string)` | <pre>[<br/>  "10.10.2.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_enable_fluxcd"></a> [enable\_fluxcd](#input\_enable\_fluxcd) | Enable FluxCD GitOps bootstrap | `bool` | `true` | no |
| <a name="input_enable_forgejo"></a> [enable\_forgejo](#input\_enable\_forgejo) | Enable in-cluster Forgejo deployment | `bool` | `true` | no |
| <a name="input_enable_gpu_passthrough"></a> [enable\_gpu\_passthrough](#input\_enable\_gpu\_passthrough) | Enable NVIDIA GPU passthrough | `bool` | `true` | no |
| <a name="input_enable_longhorn_backups"></a> [enable\_longhorn\_backups](#input\_enable\_longhorn\_backups) | Enable Longhorn NFS backups (requires secrets/nas-backup-creds.enc.yaml) | `bool` | `true` | no |
| <a name="input_enable_qemu_agent"></a> [enable\_qemu\_agent](#input\_enable\_qemu\_agent) | Enable QEMU guest agent | `bool` | `true` | no |
| <a name="input_fluxcd_path"></a> [fluxcd\_path](#input\_fluxcd\_path) | Path in repository for FluxCD cluster config | `string` | `"kubernetes/clusters/homelab"` | no |
| <a name="input_fluxcd_webhook_ip"></a> [fluxcd\_webhook\_ip](#input\_fluxcd\_webhook\_ip) | Static IP for FluxCD webhook receiver LoadBalancer | `string` | `"10.10.2.14"` | no |
| <a name="input_forgejo_chart_version"></a> [forgejo\_chart\_version](#input\_forgejo\_chart\_version) | Forgejo Helm chart version | `string` | `"10.0.0"` | no |
| <a name="input_forgejo_create_repo"></a> [forgejo\_create\_repo](#input\_forgejo\_create\_repo) | Automatically create the FluxCD repository in Forgejo | `bool` | `true` | no |
| <a name="input_forgejo_ip"></a> [forgejo\_ip](#input\_forgejo\_ip) | Static IP for Forgejo LoadBalancer (HTTP and SSH) | `string` | `"10.10.2.13"` | no |
| <a name="input_generate_kubeconfig"></a> [generate\_kubeconfig](#input\_generate\_kubeconfig) | Generate kubeconfig file after bootstrap | `bool` | `true` | no |
| <a name="input_git_branch"></a> [git\_branch](#input\_git\_branch) | Git branch for FluxCD | `string` | `"main"` | no |
| <a name="input_git_hostname"></a> [git\_hostname](#input\_git\_hostname) | Git server hostname for FluxCD (used with forgejo/gitea) | `string` | `"git.home-infra.net"` | no |
| <a name="input_git_owner"></a> [git\_owner](#input\_git\_owner) | Git owner (username or organization) for FluxCD | `string` | `""` | no |
| <a name="input_git_personal"></a> [git\_personal](#input\_git\_personal) | Use personal account (not organization) | `bool` | `true` | no |
| <a name="input_git_private"></a> [git\_private](#input\_git\_private) | Repository is private | `bool` | `false` | no |
| <a name="input_git_repository"></a> [git\_repository](#input\_git\_repository) | Git repository name for FluxCD | `string` | `"infra"` | no |
| <a name="input_git_token"></a> [git\_token](#input\_git\_token) | Git personal access token for FluxCD bootstrap | `string` | `""` | no |
| <a name="input_gpu_mapping"></a> [gpu\_mapping](#input\_gpu\_mapping) | GPU resource mapping name from Proxmox | `string` | `"nvidia-gpu"` | no |
| <a name="input_gpu_pcie"></a> [gpu\_pcie](#input\_gpu\_pcie) | Enable PCIe passthrough mode | `bool` | `true` | no |
| <a name="input_gpu_rombar"></a> [gpu\_rombar](#input\_gpu\_rombar) | Enable GPU ROM bar | `bool` | `false` | no |
| <a name="input_hubble_ui_ip"></a> [hubble\_ui\_ip](#input\_hubble\_ui\_ip) | Static IP for Cilium Hubble UI LoadBalancer | `string` | `"10.10.2.11"` | no |
| <a name="input_important_services_ip_start"></a> [important\_services\_ip\_start](#input\_important\_services\_ip\_start) | Start IP for important services LoadBalancer pool | `string` | `"10.10.2.11"` | no |
| <a name="input_important_services_ip_stop"></a> [important\_services\_ip\_stop](#input\_important\_services\_ip\_stop) | End IP for important services LoadBalancer pool | `string` | `"10.10.2.20"` | no |
| <a name="input_install_disk"></a> [install\_disk](#input\_install\_disk) | Disk device to install Talos on | `string` | `"/dev/sda"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to deploy | `string` | `"v1.35.0"` | no |
| <a name="input_kubernetes_wait_timeout"></a> [kubernetes\_wait\_timeout](#input\_kubernetes\_wait\_timeout) | Seconds to wait for Kubernetes API | `number` | `300` | no |
| <a name="input_longhorn_ui_ip"></a> [longhorn\_ui\_ip](#input\_longhorn\_ui\_ip) | Static IP for Longhorn UI LoadBalancer | `string` | `"10.10.2.12"` | no |
| <a name="input_longhorn_version"></a> [longhorn\_version](#input\_longhorn\_version) | Longhorn Helm chart version | `string` | `"1.10.1"` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Proxmox network bridge | `string` | `"vmbr0"` | no |
| <a name="input_network_model"></a> [network\_model](#input\_network\_model) | Network interface model | `string` | `"virtio"` | no |
| <a name="input_network_vlan"></a> [network\_vlan](#input\_network\_vlan) | VLAN tag (0 for none) | `number` | `0` | no |
| <a name="input_node_cpu_cores"></a> [node\_cpu\_cores](#input\_node\_cpu\_cores) | Number of CPU cores | `number` | `8` | no |
| <a name="input_node_cpu_sockets"></a> [node\_cpu\_sockets](#input\_node\_cpu\_sockets) | Number of CPU sockets | `number` | `1` | no |
| <a name="input_node_cpu_type"></a> [node\_cpu\_type](#input\_node\_cpu\_type) | CPU type (must be 'host' for Talos) | `string` | `"host"` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Disk size in GB | `number` | `200` | no |
| <a name="input_node_disk_storage"></a> [node\_disk\_storage](#input\_node\_disk\_storage) | Proxmox storage pool for node disk | `string` | `"tank"` | no |
| <a name="input_node_gateway"></a> [node\_gateway](#input\_node\_gateway) | Network gateway for the Talos node | `string` | `"10.10.2.1"` | no |
| <a name="input_node_ip"></a> [node\_ip](#input\_node\_ip) | Static IP address for the Talos node | `string` | `"10.10.2.10"` | no |
| <a name="input_node_memory"></a> [node\_memory](#input\_node\_memory) | Memory in MB | `number` | `32768` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Name for the Talos node VM | `string` | `"talos-node"` | no |
| <a name="input_node_netmask"></a> [node\_netmask](#input\_node\_netmask) | Network netmask (CIDR notation) | `number` | `24` | no |
| <a name="input_node_vm_id"></a> [node\_vm\_id](#input\_node\_vm\_id) | Proxmox VM ID for the Talos node | `number` | `1000` | no |
| <a name="input_ntp_servers"></a> [ntp\_servers](#input\_ntp\_servers) | NTP servers for time synchronization | `list(string)` | <pre>[<br/>  "time.cloudflare.com"<br/>]</pre> | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | Proxmox node name where VMs will be created | `string` | `"pve"` | no |
| <a name="input_reset_on_destroy"></a> [reset\_on\_destroy](#input\_reset\_on\_destroy) | Wipe Talos node when destroying | `bool` | `false` | no |
| <a name="input_sops_age_key_file"></a> [sops\_age\_key\_file](#input\_sops\_age\_key\_file) | Path to SOPS Age key file for FluxCD secret decryption | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to Proxmox VM | `list(string)` | <pre>[<br/>  "talos",<br/>  "kubernetes",<br/>  "nvidia-gpu"<br/>]</pre> | no |
| <a name="input_talos_config_patches"></a> [talos\_config\_patches](#input\_talos\_config\_patches) | Additional Talos configuration patches (YAML) | `list(string)` | `[]` | no |
| <a name="input_talos_schematic_id"></a> [talos\_schematic\_id](#input\_talos\_schematic\_id) | Talos Factory schematic ID with required system extensions | `string` | `"b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"` | no |
| <a name="input_talos_template_name"></a> [talos\_template\_name](#input\_talos\_template\_name) | Name of the Talos template created by Packer | `string` | `"talos-1.12.1-nvidia-template"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (must match template version) | `string` | `"v1.12.1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_instructions"></a> [access\_instructions](#output\_access\_instructions) | How to access the cluster |
| <a name="output_cilium_lb_pool"></a> [cilium\_lb\_pool](#output\_cilium\_lb\_pool) | Cilium L2 LoadBalancer IP pool CIDR |
| <a name="output_cilium_version"></a> [cilium\_version](#output\_cilium\_version) | Cilium CNI version |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_fluxcd_webhook_url"></a> [fluxcd\_webhook\_url](#output\_fluxcd\_webhook\_url) | FluxCD webhook receiver URL |
| <a name="output_forgejo_http_url"></a> [forgejo\_http\_url](#output\_forgejo\_http\_url) | Forgejo Git server HTTP URL |
| <a name="output_forgejo_ssh_url"></a> [forgejo\_ssh\_url](#output\_forgejo\_ssh\_url) | Forgejo Git server SSH URL |
| <a name="output_gpu_enabled"></a> [gpu\_enabled](#output\_gpu\_enabled) | GPU passthrough enabled |
| <a name="output_hubble_ui_url"></a> [hubble\_ui\_url](#output\_hubble\_ui\_url) | Cilium Hubble UI URL |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig content |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to kubeconfig file |
| <a name="output_kubernetes_version"></a> [kubernetes\_version](#output\_kubernetes\_version) | Kubernetes version |
| <a name="output_longhorn_ui_url"></a> [longhorn\_ui\_url](#output\_longhorn\_ui\_url) | Longhorn storage management UI URL |
| <a name="output_longhorn_version"></a> [longhorn\_version](#output\_longhorn\_version) | Longhorn storage version |
| <a name="output_node_ip"></a> [node\_ip](#output\_node\_ip) | Talos node IP address |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Talos node name |
| <a name="output_node_vm_id"></a> [node\_vm\_id](#output\_node\_vm\_id) | Proxmox VM ID |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Talos client configuration |
| <a name="output_talos_version"></a> [talos\_version](#output\_talos\_version) | Talos Linux version |
| <a name="output_talosconfig_path"></a> [talosconfig\_path](#output\_talosconfig\_path) | Path to talosconfig file |
| <a name="output_useful_commands"></a> [useful\_commands](#output\_useful\_commands) | Useful commands |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.2 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.17.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.36.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.3 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2.4 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.92.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.1.1 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | ~> 0.10.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.17.0 |
| <a name="provider_helm.template"></a> [helm.template](#provider\_helm.template) | 2.17.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.36.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.92.0 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.1.1 |
| <a name="provider_talos"></a> [talos](#provider\_talos) | 0.10.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.forgejo](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.longhorn](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_namespace.forgejo](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.longhorn](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.longhorn_backup](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service.forgejo_http_proxy](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service) | resource |
| [local_file.kubeconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talosconfig](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [null_resource.configure_longhorn_backup_target](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.create_sops_age_secret](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_git_repository](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_git_secret](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_kustomization](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.flux_verify](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.forgejo_create_repo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.forgejo_generate_token](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.forgejo_push_repo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.label_node_for_longhorn](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.nvidia_gpu_setup](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.remove_control_plane_taint](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_cilium](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_forgejo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_kubernetes](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_static_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_vm_dhcp](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [proxmox_virtual_environment_vm.talos_node](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |
| [talos_cluster_kubeconfig.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster_kubeconfig) | resource |
| [talos_machine_bootstrap.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_bootstrap) | resource |
| [talos_machine_configuration_apply.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_configuration_apply) | resource |
| [talos_machine_secrets.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets) | resource |
| [terraform_data.fluxcd_pre_destroy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.forgejo_pre_destroy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.longhorn_pre_destroy](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [helm_template.cilium](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/data-sources/template) | data source |
| [local_file.forgejo_flux_token](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [local_file.talos_dhcp_ip](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |
| [proxmox_virtual_environment_vms.talos_template](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/virtual_environment_vms) | data source |
| [sops_file.git_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [sops_file.nas_backup_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [sops_file.pangolin_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [sops_file.proxmox_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |
| [talos_client_configuration.cluster](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/client_configuration) | data source |
| [talos_machine_configuration.node](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_scheduling_on_control_plane"></a> [allow\_scheduling\_on\_control\_plane](#input\_allow\_scheduling\_on\_control\_plane) | Allow pod scheduling on control plane (required for single-node) | `bool` | `true` | no |
| <a name="input_auto_bootstrap"></a> [auto\_bootstrap](#input\_auto\_bootstrap) | Automatically bootstrap the cluster | `bool` | `true` | no |
| <a name="input_auto_install_gpu_device_plugin"></a> [auto\_install\_gpu\_device\_plugin](#input\_auto\_install\_gpu\_device\_plugin) | Automatically install NVIDIA device plugin after bootstrap | `bool` | `true` | no |
| <a name="input_cilium_lb_pool_cidr"></a> [cilium\_lb\_pool\_cidr](#input\_cilium\_lb\_pool\_cidr) | CIDR for Cilium L2 LoadBalancer IP pool | `string` | `"10.10.2.240/28"` | no |
| <a name="input_cilium_version"></a> [cilium\_version](#input\_cilium\_version) | Cilium Helm chart version | `string` | `"1.18.5"` | no |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | Kubernetes API endpoint (defaults to node IP) | `string` | `""` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Talos/Kubernetes cluster name | `string` | `"homelab-k8s"` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the Proxmox VM | `string` | `"Talos Linux single-node Kubernetes cluster with NVIDIA GPU support"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers for the node | `list(string)` | <pre>[<br/>  "10.10.2.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_enable_fluxcd"></a> [enable\_fluxcd](#input\_enable\_fluxcd) | Enable FluxCD GitOps bootstrap | `bool` | `true` | no |
| <a name="input_enable_forgejo"></a> [enable\_forgejo](#input\_enable\_forgejo) | Enable in-cluster Forgejo deployment | `bool` | `true` | no |
| <a name="input_enable_gpu_passthrough"></a> [enable\_gpu\_passthrough](#input\_enable\_gpu\_passthrough) | Enable NVIDIA GPU passthrough | `bool` | `true` | no |
| <a name="input_enable_longhorn_backups"></a> [enable\_longhorn\_backups](#input\_enable\_longhorn\_backups) | Enable Longhorn NFS backups (requires secrets/nas-backup-creds.enc.yaml) | `bool` | `true` | no |
| <a name="input_enable_pangolin"></a> [enable\_pangolin](#input\_enable\_pangolin) | Enable Pangolin/Newt WireGuard tunnel (requires secrets/pangolin-creds.enc.yaml) | `bool` | `true` | no |
| <a name="input_enable_qemu_agent"></a> [enable\_qemu\_agent](#input\_enable\_qemu\_agent) | Enable QEMU guest agent | `bool` | `true` | no |
| <a name="input_fluxcd_path"></a> [fluxcd\_path](#input\_fluxcd\_path) | Path in repository for FluxCD cluster config | `string` | `"kubernetes/clusters/homelab"` | no |
| <a name="input_fluxcd_webhook_ip"></a> [fluxcd\_webhook\_ip](#input\_fluxcd\_webhook\_ip) | Static IP for FluxCD webhook receiver LoadBalancer | `string` | `"10.10.2.15"` | no |
| <a name="input_forgejo_chart_version"></a> [forgejo\_chart\_version](#input\_forgejo\_chart\_version) | Forgejo Helm chart version | `string` | `"10.0.0"` | no |
| <a name="input_forgejo_create_repo"></a> [forgejo\_create\_repo](#input\_forgejo\_create\_repo) | Automatically create the FluxCD repository in Forgejo | `bool` | `true` | no |
| <a name="input_forgejo_ip"></a> [forgejo\_ip](#input\_forgejo\_ip) | Static IP for Forgejo HTTP LoadBalancer (port 80). Must match kubernetes/forgejo/forgejo-values.yaml | `string` | `"10.10.2.13"` | no |
| <a name="input_forgejo_ssh_ip"></a> [forgejo\_ssh\_ip](#input\_forgejo\_ssh\_ip) | Static IP for Forgejo SSH LoadBalancer | `string` | `"10.10.2.14"` | no |
| <a name="input_generate_kubeconfig"></a> [generate\_kubeconfig](#input\_generate\_kubeconfig) | Generate kubeconfig file after bootstrap | `bool` | `true` | no |
| <a name="input_git_branch"></a> [git\_branch](#input\_git\_branch) | Git branch for FluxCD | `string` | `"main"` | no |
| <a name="input_git_hostname"></a> [git\_hostname](#input\_git\_hostname) | Git server hostname for FluxCD (used with forgejo/gitea) | `string` | `"git.home-infra.net"` | no |
| <a name="input_git_owner"></a> [git\_owner](#input\_git\_owner) | Git owner (username or organization) for FluxCD | `string` | `""` | no |
| <a name="input_git_private"></a> [git\_private](#input\_git\_private) | Repository is private | `bool` | `false` | no |
| <a name="input_git_repository"></a> [git\_repository](#input\_git\_repository) | Git repository name for FluxCD | `string` | `"infra"` | no |
| <a name="input_git_token"></a> [git\_token](#input\_git\_token) | Git personal access token for FluxCD bootstrap | `string` | `""` | no |
| <a name="input_gpu_mapping"></a> [gpu\_mapping](#input\_gpu\_mapping) | GPU resource mapping name from Proxmox | `string` | `"nvidia-gpu"` | no |
| <a name="input_gpu_pcie"></a> [gpu\_pcie](#input\_gpu\_pcie) | Enable PCIe passthrough mode | `bool` | `true` | no |
| <a name="input_gpu_rombar"></a> [gpu\_rombar](#input\_gpu\_rombar) | Enable GPU ROM bar | `bool` | `false` | no |
| <a name="input_hubble_ui_ip"></a> [hubble\_ui\_ip](#input\_hubble\_ui\_ip) | Static IP for Cilium Hubble UI LoadBalancer | `string` | `"10.10.2.11"` | no |
| <a name="input_important_services_ip_start"></a> [important\_services\_ip\_start](#input\_important\_services\_ip\_start) | Start IP for important services LoadBalancer pool | `string` | `"10.10.2.11"` | no |
| <a name="input_important_services_ip_stop"></a> [important\_services\_ip\_stop](#input\_important\_services\_ip\_stop) | End IP for important services LoadBalancer pool | `string` | `"10.10.2.20"` | no |
| <a name="input_install_disk"></a> [install\_disk](#input\_install\_disk) | Disk device to install Talos on | `string` | `"/dev/sda"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version to deploy | `string` | `"v1.35.0"` | no |
| <a name="input_kubernetes_wait_timeout"></a> [kubernetes\_wait\_timeout](#input\_kubernetes\_wait\_timeout) | Seconds to wait for Kubernetes API | `number` | `300` | no |
| <a name="input_longhorn_backup_target"></a> [longhorn\_backup\_target](#input\_longhorn\_backup\_target) | Longhorn backup target URL (NFS) | `string` | `"nfs://10.10.2.5:/mnt/tank/backups"` | no |
| <a name="input_longhorn_ui_ip"></a> [longhorn\_ui\_ip](#input\_longhorn\_ui\_ip) | Static IP for Longhorn UI LoadBalancer | `string` | `"10.10.2.12"` | no |
| <a name="input_longhorn_version"></a> [longhorn\_version](#input\_longhorn\_version) | Longhorn Helm chart version | `string` | `"1.10.1"` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Proxmox network bridge | `string` | `"vmbr0"` | no |
| <a name="input_network_model"></a> [network\_model](#input\_network\_model) | Network interface model | `string` | `"virtio"` | no |
| <a name="input_network_vlan"></a> [network\_vlan](#input\_network\_vlan) | VLAN tag (0 for none) | `number` | `0` | no |
| <a name="input_node_cpu_cores"></a> [node\_cpu\_cores](#input\_node\_cpu\_cores) | Number of CPU cores | `number` | `8` | no |
| <a name="input_node_cpu_sockets"></a> [node\_cpu\_sockets](#input\_node\_cpu\_sockets) | Number of CPU sockets | `number` | `1` | no |
| <a name="input_node_cpu_type"></a> [node\_cpu\_type](#input\_node\_cpu\_type) | CPU type (must be 'host' for Talos) | `string` | `"host"` | no |
| <a name="input_node_disk_size"></a> [node\_disk\_size](#input\_node\_disk\_size) | Disk size in GB | `number` | `200` | no |
| <a name="input_node_disk_storage"></a> [node\_disk\_storage](#input\_node\_disk\_storage) | Proxmox storage pool for node disk | `string` | `"tank"` | no |
| <a name="input_node_gateway"></a> [node\_gateway](#input\_node\_gateway) | Network gateway for the Talos node | `string` | `"10.10.2.1"` | no |
| <a name="input_node_ip"></a> [node\_ip](#input\_node\_ip) | Static IP address for the Talos node | `string` | `"10.10.2.10"` | no |
| <a name="input_node_memory"></a> [node\_memory](#input\_node\_memory) | Memory in MB | `number` | `32768` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Name for the Talos node VM | `string` | `"talos-node"` | no |
| <a name="input_node_netmask"></a> [node\_netmask](#input\_node\_netmask) | Network netmask (CIDR notation) | `number` | `24` | no |
| <a name="input_node_vm_id"></a> [node\_vm\_id](#input\_node\_vm\_id) | Proxmox VM ID for the Talos node | `number` | `1000` | no |
| <a name="input_ntp_servers"></a> [ntp\_servers](#input\_ntp\_servers) | NTP servers for time synchronization | `list(string)` | <pre>[<br/>  "time.cloudflare.com"<br/>]</pre> | no |
| <a name="input_nvidia_device_plugin_version"></a> [nvidia\_device\_plugin\_version](#input\_nvidia\_device\_plugin\_version) | NVIDIA device plugin version | `string` | `"v0.18.1"` | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | Proxmox node name where VMs will be created | `string` | `"pve"` | no |
| <a name="input_reset_on_destroy"></a> [reset\_on\_destroy](#input\_reset\_on\_destroy) | Wipe Talos node when destroying | `bool` | `false` | no |
| <a name="input_sops_age_key_file"></a> [sops\_age\_key\_file](#input\_sops\_age\_key\_file) | Path to SOPS Age key file for FluxCD secret decryption | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to Proxmox VM | `list(string)` | <pre>[<br/>  "talos",<br/>  "kubernetes",<br/>  "nvidia-gpu"<br/>]</pre> | no |
| <a name="input_talos_config_patches"></a> [talos\_config\_patches](#input\_talos\_config\_patches) | Additional Talos configuration patches (YAML) | `list(string)` | `[]` | no |
| <a name="input_talos_schematic_id"></a> [talos\_schematic\_id](#input\_talos\_schematic\_id) | Talos Factory schematic ID with required system extensions | `string` | `"b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"` | no |
| <a name="input_talos_template_name"></a> [talos\_template\_name](#input\_talos\_template\_name) | Name of the Talos template created by Packer | `string` | `"talos-1.12.1-nvidia-template"` | no |
| <a name="input_talos_version"></a> [talos\_version](#input\_talos\_version) | Talos Linux version (must match template version) | `string` | `"v1.12.1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_instructions"></a> [access\_instructions](#output\_access\_instructions) | How to access the cluster |
| <a name="output_cilium_lb_pool"></a> [cilium\_lb\_pool](#output\_cilium\_lb\_pool) | Cilium L2 LoadBalancer IP pool CIDR |
| <a name="output_cilium_version"></a> [cilium\_version](#output\_cilium\_version) | Cilium CNI version |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Kubernetes API endpoint |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Cluster name |
| <a name="output_fluxcd_webhook_url"></a> [fluxcd\_webhook\_url](#output\_fluxcd\_webhook\_url) | FluxCD webhook receiver URL |
| <a name="output_forgejo_http_url"></a> [forgejo\_http\_url](#output\_forgejo\_http\_url) | Forgejo Git server HTTP URL (via proxy on port 80) |
| <a name="output_forgejo_ssh_url"></a> [forgejo\_ssh\_url](#output\_forgejo\_ssh\_url) | Forgejo Git server SSH URL |
| <a name="output_gpu_enabled"></a> [gpu\_enabled](#output\_gpu\_enabled) | GPU passthrough enabled |
| <a name="output_hubble_ui_url"></a> [hubble\_ui\_url](#output\_hubble\_ui\_url) | Cilium Hubble UI URL |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig content |
| <a name="output_kubeconfig_path"></a> [kubeconfig\_path](#output\_kubeconfig\_path) | Path to kubeconfig file |
| <a name="output_kubernetes_version"></a> [kubernetes\_version](#output\_kubernetes\_version) | Kubernetes version |
| <a name="output_longhorn_ui_url"></a> [longhorn\_ui\_url](#output\_longhorn\_ui\_url) | Longhorn storage management UI URL |
| <a name="output_longhorn_version"></a> [longhorn\_version](#output\_longhorn\_version) | Longhorn storage version |
| <a name="output_node_ip"></a> [node\_ip](#output\_node\_ip) | Talos node IP address |
| <a name="output_node_name"></a> [node\_name](#output\_node\_name) | Talos node name |
| <a name="output_node_vm_id"></a> [node\_vm\_id](#output\_node\_vm\_id) | Proxmox VM ID |
| <a name="output_talos_client_configuration"></a> [talos\_client\_configuration](#output\_talos\_client\_configuration) | Talos client configuration |
| <a name="output_talos_version"></a> [talos\_version](#output\_talos\_version) | Talos Linux version |
| <a name="output_talosconfig_path"></a> [talosconfig\_path](#output\_talosconfig\_path) | Path to talosconfig file |
| <a name="output_useful_commands"></a> [useful\_commands](#output\_useful\_commands) | Useful commands |
<!-- END_TF_DOCS -->