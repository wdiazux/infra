# Talos Factory Schematic Generation Guide

**Purpose:** Generate custom Talos Linux images with required system extensions for Proxmox and Longhorn storage

**Prerequisites:**
- Internet access to https://factory.talos.dev/
- Web browser
- Note your desired Talos version (e.g., v1.12.1)

---

## 🎯 Quick Summary

**Required Extensions for This Infrastructure:**
1. `siderolabs/qemu-guest-agent` - **REQUIRED** - Proxmox VM integration
2. `siderolabs/iscsi-tools` - **REQUIRED** - Longhorn storage (iSCSI support)
3. `siderolabs/util-linux-tools` - **REQUIRED** - Longhorn storage (volume management)

**Optional Extensions (for GPU workloads):**
4. `nonfree-kmod-nvidia-production` - OPTIONAL - NVIDIA GPU drivers
5. `nvidia-container-toolkit-production` - OPTIONAL - NVIDIA container runtime

**Result:** 64-character schematic ID (e.g., `376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba`)

---

## 📋 Step-by-Step Instructions

### Step 1: Visit Talos Factory

Open your web browser and navigate to:
```
https://factory.talos.dev/
```

<img src="https://www.talos.dev/v1.11/images/factory-homepage.png" alt="Talos Factory Homepage" width="800"/>

### Step 2: Select Talos Version

1. Click on the **version selector** dropdown
2. Choose **v1.12.1** (or your desired version)
   - Ensure it matches the version in `terraform/variables.tf` (default: v1.12.1)
   - Use stable versions only (avoid alpha/beta for production)

### Step 3: Select Platform

1. Under **Platform**, select **Metal** (for Talos 1.8.0+)
   - For older versions (< 1.8.0), use "Nocloud"
   - Proxmox uses the "Metal" platform for modern Talos versions

### Step 4: Add System Extensions

This is the **most important step**. You must add all required extensions.

#### Required Extensions (Add ALL 3)

1. **Click "Add Extension"**

2. **Extension 1: QEMU Guest Agent**
   - Search for: `qemu-guest-agent`
   - Select: `siderolabs/qemu-guest-agent`
   - Purpose: Enables Proxmox to communicate with the VM
   - **Without this:** Proxmox cannot report VM status, IP address, or shutdown cleanly

3. **Extension 2: iSCSI Tools**
   - Click "Add Extension" again
   - Search for: `iscsi-tools`
   - Select: `siderolabs/iscsi-tools`
   - Purpose: Provides iSCSI support for Longhorn storage
   - **Without this:** Longhorn volumes will fail to attach

4. **Extension 3: Util-Linux Tools**
   - Click "Add Extension" again
   - Search for: `util-linux-tools`
   - Select: `siderolabs/util-linux-tools`
   - Purpose: Provides `fstrim`, `nsenter`, and other tools for Longhorn
   - **Without this:** Longhorn volume operations will fail

#### Optional Extensions (For GPU Workloads)

**Only add these if you're using NVIDIA GPU passthrough:**

5. **Extension 4: NVIDIA GPU Drivers** (Optional)
   - Click "Add Extension"
   - Search for: `nvidia`
   - Select: `nonfree-kmod-nvidia-production`
   - Purpose: NVIDIA proprietary GPU drivers
   - Version: Choose latest production version

6. **Extension 5: NVIDIA Container Toolkit** (Optional)
   - Click "Add Extension"
   - Search for: `nvidia-container`
   - Select: `nvidia-container-toolkit-production`
   - Purpose: NVIDIA container runtime for Kubernetes GPU workloads
   - Version: Choose latest production version

### Step 5: Verify Extensions

**Double-check your selections:**

✅ Required Extensions (ALL must be present):
- [ ] siderolabs/qemu-guest-agent
- [ ] siderolabs/iscsi-tools
- [ ] siderolabs/util-linux-tools

🔵 Optional Extensions (if using GPU):
- [ ] nonfree-kmod-nvidia-production
- [ ] nvidia-container-toolkit-production

### Step 6: Generate Schematic

1. Click the **"Generate"** button
2. Wait a few seconds for processing
3. The page will update with your schematic information

### Step 7: Copy Schematic ID

1. Look for the **Schematic ID** section
2. You'll see a 64-character hexadecimal string like:
   ```
   376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba
   ```
3. **Copy this entire string** - you'll need it for the import script and Terraform

---

## 🔧 Using the Schematic ID

### In Import Script (Template Creation)

Edit `packer/talos/import-talos-image.sh`:

```bash
TALOS_VERSION="v1.12.1"
SCHEMATIC_ID="376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
```

Then run on Proxmox host:
```bash
./import-talos-image.sh
```

### In Terraform (Cluster Deployment)

Edit `terraform/terraform.tfvars`:

```hcl
talos_schematic_id = "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
talos_version      = "v1.12.1"
```

---

## ✅ Verification

After deploying Talos, verify extensions are installed:

```bash
# Connect to Talos node
talosctl -n <node-ip> get extensions

# Expected output should include:
# - qemu-guest-agent
# - iscsi-tools
# - util-linux-tools
# - (if GPU) nonfree-kmod-nvidia
# - (if GPU) nvidia-container-toolkit
```

---

## 📸 Visual Guide

### Factory Homepage
```
┌─────────────────────────────────────────┐
│  Talos Factory                          │
│                                          │
│  Version: [v1.12.1 ▼]                   │
│  Platform: [Metal ▼]                    │
│                                          │
│  Extensions:                             │
│  [+ Add Extension]                      │
│                                          │
│  [Generate]                             │
└─────────────────────────────────────────┘
```

### After Adding Extensions
```
┌─────────────────────────────────────────┐
│  Talos Factory                          │
│                                          │
│  Version: v1.12.1                       │
│  Platform: Metal                        │
│                                          │
│  Extensions:                             │
│  ✓ siderolabs/qemu-guest-agent          │
│  ✓ siderolabs/iscsi-tools               │
│  ✓ siderolabs/util-linux-tools          │
│  ✓ nonfree-kmod-nvidia-production       │
│  ✓ nvidia-container-toolkit-production  │
│  [+ Add Extension]                      │
│                                          │
│  [Generate]                             │
└─────────────────────────────────────────┘
```

### Schematic Generated
```
┌─────────────────────────────────────────┐
│  Schematic Generated!                   │
│                                          │
│  Schematic ID:                          │
│  376567988ad370138ad8b2698212367b...   │
│  [Copy to Clipboard]                    │
│                                          │
│  Download Links:                        │
│  • Metal ISO                            │
│  • Metal Disk Image                     │
│  • Installer                            │
└─────────────────────────────────────────┘
```

---

## 🚨 Common Mistakes

### ❌ Missing Required Extensions

**Mistake:** Only adding NVIDIA extensions, forgetting qemu-guest-agent and iSCSI tools

**Result:**
- Proxmox cannot communicate with VM
- Longhorn storage completely broken
- Volume attachments fail

**Solution:** Always add ALL THREE required extensions first, then add GPU extensions

### ❌ Wrong Platform Selection

**Mistake:** Selecting "Nocloud" for Talos 1.8.0+

**Result:**
- Boot issues on Proxmox
- Cloud-init compatibility problems

**Solution:** Use "Metal" for Talos 1.8.0+ on Proxmox

### ❌ Version Mismatch

**Mistake:** Using different Talos versions in Packer vs Terraform

**Result:**
- Template won't match cluster configuration
- Unexpected behavior or failures

**Solution:** Keep `talos_version` consistent across:
- packer/talos/import-talos-image.sh
- terraform/terraform.tfvars
- Talos Factory schematic

### ❌ Forgetting to Copy Schematic ID

**Mistake:** Closing browser without copying the 64-character ID

**Result:**
- Must regenerate schematic (wastes time)
- Risk of inconsistency if extensions differ

**Solution:** Copy schematic ID immediately and save it in terraform.tfvars and import-talos-image.sh

---

## 🔄 Regenerating Schematics

**When to regenerate:**
- Adding/removing system extensions
- Changing Talos version
- Updating NVIDIA driver versions
- Enabling/disabling GPU support

**Process:**
1. Return to https://factory.talos.dev/
2. Repeat steps 2-7 with updated selections
3. Copy new schematic ID
4. Update in import-talos-image.sh
5. **Re-run import script** - schematic ID is baked into the image
6. Update in Terraform variables (if cluster not yet deployed)

**Important:** Changing schematic ID after cluster deployment requires full cluster rebuild

---

## 📦 Alternative: Pre-built Images

**For testing only (not recommended for production):**

Talos provides pre-built images without custom extensions at:
```
https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/
```

**Limitations:**
- ❌ No QEMU guest agent
- ❌ No iSCSI support (Longhorn won't work)
- ❌ No GPU drivers
- ✅ Good for testing basic Talos functionality

---

## 🔗 Additional Resources

**Official Documentation:**
- Talos Factory: https://github.com/siderolabs/image-factory
- System Extensions: https://github.com/siderolabs/extensions
- Proxmox Guide: https://www.talos.dev/v1.11/talos-guides/install/virtualized-platforms/proxmox/

**Extension Documentation:**
- QEMU Guest Agent: https://github.com/siderolabs/extensions/tree/main/guest-agents/qemu-guest-agent
- iSCSI Tools: https://github.com/siderolabs/extensions/tree/main/storage/iscsi-tools
- Util-Linux Tools: https://github.com/siderolabs/extensions/tree/main/system/util-linux-tools
- NVIDIA Drivers: https://github.com/siderolabs/extensions/tree/main/video/nonfree-kmod-nvidia

---

## 💡 Pro Tips

1. **Bookmark Your Schematic:** Save the Factory URL with your schematic in browser bookmarks
2. **Document Schematic ID:** Add comment in terraform.tfvars explaining what extensions are included
3. **Version Control:** Commit terraform.tfvars.example with schematic ID for team reference
4. **Test Before Production:** Build test VM with new schematic before full cluster deployment
5. **Monthly Reviews:** Check for updated extension versions quarterly

---

**Guide Version:** 1.1
**Last Updated:** January 11, 2026
**Talos Version:** v1.12.1
**Maintained by:** Infrastructure Team
