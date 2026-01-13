## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.2 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.92.0 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.1.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_sops"></a> [sops](#provider\_sops) | 1.1.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_traditional_vm"></a> [traditional\_vm](#module\_traditional\_vm) | ../modules/proxmox-vm | n/a |

## Resources

| Name | Type |
|------|------|
| [sops_file.proxmox_secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arch_template_name"></a> [arch\_template\_name](#input\_arch\_template\_name) | Arch Linux Packer template name in Proxmox | `string` | `"arch-cloud-template"` | no |
| <a name="input_cloud_init_password"></a> [cloud\_init\_password](#input\_cloud\_init\_password) | Fallback password if not in SOPS secrets (prefer SOPS) | `string` | `""` | no |
| <a name="input_cloud_init_ssh_keys"></a> [cloud\_init\_ssh\_keys](#input\_cloud\_init\_ssh\_keys) | Additional SSH keys (primary key comes from SOPS) | `list(string)` | `[]` | no |
| <a name="input_cloud_init_user"></a> [cloud\_init\_user](#input\_cloud\_init\_user) | Fallback username if not in SOPS secrets | `string` | `"wdiaz"` | no |
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Tags applied to all traditional VMs | `list(string)` | <pre>[<br/>  "traditional-vm",<br/>  "packer-template"<br/>]</pre> | no |
| <a name="input_debian_template_name"></a> [debian\_template\_name](#input\_debian\_template\_name) | Debian Packer template name in Proxmox | `string` | `"debian-13-cloud-template"` | no |
| <a name="input_default_gateway"></a> [default\_gateway](#input\_default\_gateway) | Default gateway for static IP configurations | `string` | `"10.10.2.1"` | no |
| <a name="input_default_storage"></a> [default\_storage](#input\_default\_storage) | Default Proxmox storage pool for VM disks | `string` | `"tank"` | no |
| <a name="input_dns_domain"></a> [dns\_domain](#input\_dns\_domain) | DNS domain | `string` | `"local"` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers | `list(string)` | <pre>[<br/>  "10.10.2.1",<br/>  "8.8.8.8"<br/>]</pre> | no |
| <a name="input_enable_cloud_init"></a> [enable\_cloud\_init](#input\_enable\_cloud\_init) | Enable cloud-init for VM provisioning | `bool` | `true` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Proxmox network bridge | `string` | `"vmbr0"` | no |
| <a name="input_nixos_template_name"></a> [nixos\_template\_name](#input\_nixos\_template\_name) | NixOS Packer template name in Proxmox | `string` | `"nixos-cloud-template"` | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | Proxmox node name where VMs will be created | `string` | `"pve"` | no |
| <a name="input_ubuntu_template_name"></a> [ubuntu\_template\_name](#input\_ubuntu\_template\_name) | Ubuntu Packer template name in Proxmox | `string` | `"ubuntu-2404-cloud-template"` | no |
| <a name="input_windows_admin_password"></a> [windows\_admin\_password](#input\_windows\_admin\_password) | Fallback admin password if not in SOPS secrets (prefer SOPS) | `string` | `""` | no |
| <a name="input_windows_admin_user"></a> [windows\_admin\_user](#input\_windows\_admin\_user) | Fallback admin username if not in SOPS secrets | `string` | `"Administrator"` | no |
| <a name="input_windows_template_name"></a> [windows\_template\_name](#input\_windows\_template\_name) | Windows Packer template name in Proxmox | `string` | `"windows-11-golden-template"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ssh_commands"></a> [ssh\_commands](#output\_ssh\_commands) | SSH commands to connect to each VM |
| <a name="output_summary"></a> [summary](#output\_summary) | Deployment summary |
| <a name="output_vm_count"></a> [vm\_count](#output\_vm\_count) | Count of deployed VMs by OS type |
| <a name="output_vm_ips"></a> [vm\_ips](#output\_vm\_ips) | Quick lookup of VM IPs |
| <a name="output_vms"></a> [vms](#output\_vms) | All deployed traditional VMs |
