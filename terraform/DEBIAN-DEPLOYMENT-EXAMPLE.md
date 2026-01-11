# Deploying Debian 13 VMs from Template

This guide shows how to deploy Debian 13 (Trixie) VMs from the Packer-built template using Terraform.

## Prerequisites

1. ✅ Debian template built with Packer (VM ID 9112: `debian-13-cloud-template`)
2. ✅ Terraform initialized (`terraform init`)
3. ✅ Proxmox credentials configured (via `.envrc` or `terraform.tfvars`)

## New for_each Pattern

Traditional VMs are now deployed using a `for_each` pattern. VM definitions are in `locals-vms.tf`, not in `terraform.tfvars`. This allows:
- Safe add/remove of VMs without cascade destruction
- All VM configs in one central location
- Simple enable/disable with `enabled = true/false`

## SSH Authentication Options

SSH credentials are configured in `terraform.tfvars` (shared across all VMs).

### Option 1: Password Only (Quick Testing)

**Good for**: Testing, development VMs

```hcl
# terraform.tfvars - Shared credentials
cloud_init_user     = "admin"
cloud_init_password = "changeme123"  # Change in production!
cloud_init_ssh_keys = []             # Empty for password-only
```

**Connect**: `ssh admin@10.10.2.12` (password: `changeme123`)

### Option 2: SSH Keys Only (Recommended for Production)

**Good for**: Production, security-focused deployments

```hcl
# terraform.tfvars
cloud_init_user     = "admin"
cloud_init_password = ""  # Disable password authentication
cloud_init_ssh_keys = [
  "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
]
```

**Connect**: `ssh admin@10.10.2.12` (uses your private key)

### Option 3: Both Password and SSH Keys (Flexible)

**Good for**: Mixed environments, gradual migration to keys

```hcl
# terraform.tfvars
cloud_init_user     = "admin"
cloud_init_password = "backup-password"  # Fallback if key fails
cloud_init_ssh_keys = [
  "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
]
```

**Connect**:

- Preferred: `ssh admin@10.10.2.12` (uses SSH key)
- Fallback: `ssh -o PreferredAuthentications=password admin@10.10.2.12`

## Complete Deployment Example

### Step 1: Enable Debian VM in `locals-vms.tf`

Edit `locals-vms.tf` to enable the Debian VM:

```hcl
# In locals-vms.tf
"debian-prod" = {
  enabled       = true   # Set to true to deploy
  description   = "Debian 13 - Production server"
  os_type       = "debian"
  template_name = var.debian_template_name
  vm_id         = 200
  cpu_type      = "host"
  cpu_cores     = 4
  memory        = 8192   # 8GB RAM
  disk_size     = 50     # 50GB disk
  disk_storage  = var.default_storage
  ip_address    = "10.10.2.12/24"  # Or "dhcp" for automatic
  on_boot       = true
  tags          = ["debian", "linux", "production"]
  startup_order = 20
}
```

### Step 2: Configure Shared Settings in `terraform.tfvars`

```hcl
# terraform.tfvars

# Template name (from Packer build)
debian_template_name = "debian-13-cloud-template"

# Network configuration
default_gateway = "10.10.2.1"
dns_servers     = ["8.8.8.8", "8.8.4.4"]
dns_domain      = "local"
network_bridge  = "vmbr0"

# Cloud-init credentials (shared across all Linux VMs)
cloud_init_user     = "admin"
cloud_init_password = "SecurePass123!"  # Change this!
cloud_init_ssh_keys = [
  "ssh-rsa AAAA... your-public-key"
]
```

### Step 3: Validate Configuration

```bash
cd terraform
terraform validate
```

### Step 4: Plan Deployment

```bash
# Plan all changes
terraform plan

# Or plan only Debian VM
terraform plan -target='module.traditional_vm["debian-prod"]'
```

Review the changes:

- ✅ Verifies template exists
- ✅ Shows what will be created
- ✅ Validates configuration

### Step 5: Deploy

```bash
# Deploy all enabled VMs
terraform apply

# Or deploy only Debian VM
terraform apply -target='module.traditional_vm["debian-prod"]'
```

Type `yes` to confirm.

### Step 6: Verify Deployment

```bash
# Check Terraform outputs
terraform output traditional_vms
terraform output traditional_vm_ips
terraform output ssh_commands

# Wait for cloud-init to complete (~30-60 seconds)
sleep 60

# Test SSH connection
ssh admin@10.10.2.12
```

## What Gets Deployed

Your Debian VM includes:

**✅ Pre-installed from Packer template:**

- Debian 13.2 (Trixie)
- Development tools: git 2.47.3, vim 9.1, python3 3.13.5, gcc 14.2.0
- System utilities: htop, tmux, rsync, curl, wget, tree
- Security packages: ufw, unattended-upgrades
- Cloud-init 25.1.4
- QEMU guest agent

**✅ Configured via Cloud-init:**

- User account (username from `cloud_init_user`)
- SSH access (password and/or keys)
- Network configuration (static IP or DHCP)
- Hostname and DNS settings

## Post-Deployment Configuration

### Option 1: Manual SSH Configuration

```bash
ssh admin@10.10.2.20

# Update packages
sudo apt update && sudo apt upgrade -y

# Configure firewall
sudo ufw allow 22/tcp
sudo ufw enable

# Install application-specific packages
sudo apt install nginx postgresql redis-server
```

### Option 2: Ansible Baseline Role

```bash
# Run Ansible baseline configuration
cd ../ansible
ansible-playbook -i inventories/production playbooks/baseline.yml \
  --limit debian-app-01 \
  --ask-become-pass
```

## Common Configurations

All configurations are in `locals-vms.tf`.

### Development VM (Minimal Resources)

```hcl
# In locals-vms.tf
"debian-dev" = {
  enabled    = true
  cpu_cores  = 2
  memory     = 4096      # 4GB
  disk_size  = 30        # 30GB
  ip_address = "dhcp"
  # ...
}
```

### Production VM (Performance Optimized)

```hcl
# In locals-vms.tf
"debian-prod" = {
  enabled    = true
  cpu_type   = "host"    # Better performance
  cpu_cores  = 8
  memory     = 16384     # 16GB
  disk_size  = 100       # 100GB
  ip_address = "10.10.2.12/24"  # Static IP
  # ...
}
```

### High-Security VM (SSH Keys Only)

```hcl
# In terraform.tfvars
cloud_init_password = ""  # Disable password auth
cloud_init_ssh_keys = [
  "ssh-ed25519 AAAA... production-key"
]

# Additional hardening via Ansible after deployment
```

## Troubleshooting

### Issue: Can't SSH to VM

**Check cloud-init status:**

```bash
# Via Proxmox host
ssh root@pve "qm guest cmd 200 network-get-interfaces"

# Or console in Proxmox UI
# Login as cloud_init_user and run:
cloud-init status --long
```

**Common causes:**

1. Cloud-init still running (wait 1-2 minutes)
2. Wrong IP address (check DHCP assignment)
3. SSH key mismatch (use password as fallback)
4. Firewall blocking (check Proxmox host firewall)

### Issue: Template Not Found

```
Error: template 'debian-13-cloud-template' does not exist
```

**Solution:**

```bash
# Verify template exists in Proxmox
curl -k "${PROXMOX_URL}/nodes/pve/qemu/9112/config" \
  -H "Authorization: PVEAPIToken=${PROXMOX_USERNAME}=${PROXMOX_TOKEN}"

# Or check variables match template name
grep debian_template_name terraform.tfvars
```

### Issue: IP Address Conflict

```
Error: VM failed to start
```

**Solution:** Use a different IP or check for conflicts:

```bash
# Ping to check if IP is in use
ping -c 3 10.10.2.20

# Choose unused IP in range 10.10.2.20-239
```

## Cleanup

### Destroy Single VM

```bash
# Option 1: Disable in locals-vms.tf and apply
# Set enabled = false in locals-vms.tf
terraform apply

# Option 2: Target destroy
terraform destroy -target='module.traditional_vm["debian-prod"]'
```

### Destroy Everything

```bash
terraform destroy
```

## Next Steps

After deploying your Debian VM:

1. ✅ Run Ansible baseline role for instance-specific config
2. ✅ Configure application-specific settings
3. ✅ Set up monitoring and backups
4. ✅ Document your deployment

## Resources

- **Packer Template**: `../packer/debian/`
- **Template README**: `../packer/debian/README.md`
- **Ansible Day 1 Playbook**: `../ansible/playbooks/day1_debian_baseline.yml`
- **Terraform Module**: `./modules/proxmox-vm/`

---

**Last Updated**: 2026-01-11
**Template Version**: debian-13-cloud-template (VM 9112)
**Terraform Pattern**: for_each with locals-vms.tf
**Terraform Module**: proxmox-vm
