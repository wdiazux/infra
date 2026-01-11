# Deploying Debian 13 VMs from Template

This guide shows how to deploy Debian 13 (Trixie) VMs from the Packer-built template using Terraform.

## Prerequisites

1. ✅ Debian template built with Packer (VM ID 9112: `debian-13-cloud-template`)
2. ✅ Terraform initialized (`terraform init`)
3. ✅ Proxmox credentials configured (via `.envrc` or `terraform.tfvars`)

## SSH Authentication Options

### Option 1: Password Only (Quick Testing)

**Good for**: Testing, development VMs

```hcl
# terraform.tfvars
deploy_debian_vm    = true
debian_template_name = "debian-13-cloud-template"
debian_vm_name      = "debian-dev-01"
debian_vm_id        = 200
debian_ip_address   = "10.10.2.20/24"

# Cloud-init user with password
cloud_init_user     = "admin"
cloud_init_password = "changeme123"  # Change in production!
cloud_init_ssh_keys = []             # Empty for password-only
```

**Connect**: `ssh admin@10.10.2.20` (password: `changeme123`)

### Option 2: SSH Keys Only (Recommended for Production)

**Good for**: Production, security-focused deployments

```hcl
# terraform.tfvars
deploy_debian_vm    = true
debian_template_name = "debian-13-cloud-template"
debian_vm_name      = "debian-prod-01"
debian_vm_id        = 200
debian_ip_address   = "10.10.2.20/24"

# Cloud-init user with SSH key
cloud_init_user     = "admin"
cloud_init_password = ""  # Disable password authentication
cloud_init_ssh_keys = [
  "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
]
```

**Connect**: `ssh admin@10.10.2.20` (uses your private key)

### Option 3: Both Password and SSH Keys (Flexible)

**Good for**: Mixed environments, gradual migration to keys

```hcl
# terraform.tfvars
deploy_debian_vm    = true
debian_template_name = "debian-13-cloud-template"
debian_vm_name      = "debian-app-01"
debian_vm_id        = 200
debian_ip_address   = "10.10.2.20/24"

# Cloud-init user with both password and SSH key
cloud_init_user     = "admin"
cloud_init_password = "backup-password"  # Fallback if key fails
cloud_init_ssh_keys = [
  "ssh-rsa AAAAB3NzaC1yc2E... your-public-key"
]
```

**Connect**:

- Preferred: `ssh admin@10.10.2.20` (uses SSH key)
- Fallback: `ssh -o PreferredAuthentications=password admin@10.10.2.20`

## Complete Deployment Example

### Step 1: Configure Variables

Create or edit `terraform.tfvars`:

```hcl
# Proxmox Connection (or use .envrc)
proxmox_node = "pve"

# Enable Debian VM deployment
deploy_debian_vm = true

# Template Configuration
debian_template_name = "debian-13-cloud-template"

# VM Configuration
debian_vm_name    = "debian-app-01"
debian_vm_id      = 200
debian_cpu_cores  = 4
debian_memory     = 8192  # 8GB RAM
debian_disk_size  = 50    # 50GB disk
debian_disk_storage = "tank"

# Network Configuration
debian_ip_address = "10.10.2.20/24"  # Or "dhcp" for automatic
default_gateway   = "10.10.2.1"
dns_servers       = ["10.10.2.1", "1.1.1.1"]
dns_domain        = "home-infra.net"
network_bridge    = "vmbr0"

# Cloud-init User Configuration
cloud_init_user     = "admin"
cloud_init_password = "SecurePass123!"  # Change this!
cloud_init_ssh_keys = [
  file("~/.ssh/id_rsa.pub")  # Reads your SSH public key
]

# Startup Configuration
debian_on_boot = true  # Start on Proxmox boot
```

### Step 2: Validate Configuration

```bash
cd terraform
terraform validate
```

### Step 3: Plan Deployment

```bash
terraform plan
```

Review the changes:

- ✅ Verifies template exists
- ✅ Shows what will be created
- ✅ Validates configuration

### Step 4: Deploy

```bash
terraform apply
```

Type `yes` to confirm.

### Step 5: Verify Deployment

```bash
# Check Terraform output
terraform show

# Wait for cloud-init to complete (~30-60 seconds)
sleep 60

# Test SSH connection
ssh admin@10.10.2.20
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

### Development VM (Minimal Resources)

```hcl
debian_cpu_cores = 2
debian_memory    = 4096  # 4GB
debian_disk_size = 30    # 30GB
debian_ip_address = "dhcp"
```

### Production VM (Performance Optimized)

```hcl
debian_cpu_type  = "host"  # Better performance
debian_cpu_cores = 8
debian_memory    = 16384   # 16GB
debian_disk_size = 100     # 100GB
debian_ip_address = "10.10.2.20/24"  # Static IP
```

### High-Security VM (SSH Keys Only)

```hcl
cloud_init_password = ""  # Disable password auth
cloud_init_ssh_keys = [
  file("~/.ssh/production.pub")
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
# Set to false in terraform.tfvars
deploy_debian_vm = false

# Apply changes
terraform apply
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

**Last Updated**: 2026-01-06
**Template Version**: debian-13-cloud-template (VM 9112)
**Terraform Module**: proxmox-vm
