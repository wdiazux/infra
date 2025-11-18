# Task: Automate Golden Image Creation with Terraform, Packer, and Ansible

## Objective

Create Infrastructure-as-Code automation to build golden VM images on Proxmox
9.0 for multiple operating systems using Terraform, Packer, cloud-init, and
Ansible.

## Target Operating Systems

- Debian (latest stable)
- Ubuntu (latest LTS)
- Arch Linux
- NixOS
- Talos
- Windows (specify version)

## Critical Requirements

### 1. Version Research & Compatibility

- Research the **latest versions** of Terraform and Packer
- Verify all code syntax and features are compatible with these latest versions
- Note that documentation and code patterns change between versions—ensure
  compatibility
- Target platform: **Proxmox VE 9.0**

### 2. Code Quality Standards

- Write **simple, optimized, and maintainable** code
- Prioritize **functionality and reliability** over complexity
- Code must be easily understandable
- Include comments explaining key configurations

### 3. Configuration Management

- Use **Ansible** for post-provisioning configuration:
  - Set default username and password
  - Install baseline packages for each OS
  - Apply OS-specific configurations
- Integrate cloud-init where applicable for initial setup

### 4. Documentation Priority

- **Primary source**: Official documentation (Terraform, Packer, Ansible,
  Proxmox)
- Use provided GitHub repositories as **reference examples only**, not templates
  to copy
- Cross-reference blog posts for patterns, but validate against official docs

## Reference Repositories

Use as inspiration, not direct templates:

- [kencx/homelab](https://github.com/kencx/homelab)
- [zimmertr/TJs-Kubernetes-Service](https://github.com/zimmertr/TJs-Kubernetes-Service)
- [sergelogvinov/terraform-talos](https://github.com/sergelogvinov/terraform-talos)
- [dfroberg/cluster](https://github.com/dfroberg/cluster)
- [hcavarsan/homelab](https://github.com/hcavarsan/homelab)
- [chriswayg/packer-proxmox-templates](https://github.com/chriswayg/packer-proxmox-templates)

## Additional Reference Materials

- [Talos Cluster on Proxmox with Terraform](https://olav.ninja/talos-cluster-on-proxmox-with-terraform)
- [Homelab as Code](https://merox.dev/blog/homelab-as-code/)
- [Terraform Proxmox Provider Guide](https://spacelift.io/blog/terraform-proxmox-provider)

## Workflow

### Before Starting Each Task:

1. Research the official documentation for the specific tool/feature
2. Verify the approach is best practice for the latest versions
3. Check reference examples for patterns
4. Validate compatibility with Proxmox 9.0

### Implementation Order:

1. Research and document version requirements
2. Set up Packer templates for each OS
3. Configure cloud-init for initial provisioning
4. Create Ansible playbooks for post-configuration
5. Develop Terraform code to orchestrate the process
6. Test each OS image thoroughly
7. Document the complete workflow

## Deliverables

- Working Packer templates for all target OSs
- Terraform configurations for image building and VM deployment
- Ansible playbooks for system configuration
- Clear documentation with usage instructions
- Version compatibility notes
