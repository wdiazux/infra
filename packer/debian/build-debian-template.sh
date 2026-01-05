#!/usr/bin/env bash
# Build Debian 13 Cloud Template with Packer
#
# This script builds a customized Debian template from the cloud image base VM

set -e

echo "======================================================================"
echo "Building Debian 13 Cloud Template with Packer"
echo "======================================================================"
echo ""
echo "Prerequisites:"
echo "  ✓ Base VM 9110 (debian-13-cloud-base) must exist"
echo "  ✓ Environment variables loaded from .envrc"
echo "  ✓ Ansible baseline packages playbook ready"
echo ""
echo "Build Process:"
echo "  1. Initialize Packer plugins"
echo "  2. Validate template configuration"
echo "  3. Clone base VM 9110 → Build VM"
echo "  4. Wait for cloud-init to complete"
echo "  5. Run Ansible to install baseline packages"
echo "  6. Clean up (remove cloud-init data, reset machine-id)"
echo "  7. Convert to template 9112 (debian-13-cloud-template)"
echo ""
echo "Expected build time: 5-10 minutes"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# Step 1: Initialize Packer
echo "==> Initializing Packer plugins..."
packer init .

# Step 2: Validate configuration
echo "==> Validating Packer configuration..."
packer validate .

# Step 3: Build template
echo "==> Building Debian template..."
echo ""
PACKER_LOG=1 packer build \
  -force \
  -on-error=ask \
  .

echo ""
echo "======================================================================"
echo "✅ Debian template build complete!"
echo "======================================================================"
echo ""
echo "Template created: debian-13-cloud-template (VM ID: 9112)"
echo ""
echo "Next steps:"
echo "  1. Verify template in Proxmox UI"
echo "  2. Test deployment with cloud-init"
echo "  3. Configure with Ansible baseline role"
echo ""
