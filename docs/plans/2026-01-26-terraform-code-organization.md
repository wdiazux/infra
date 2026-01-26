# Terraform Code Organization Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract inline scripts (10+ lines) from Terraform files into separate shell scripts, and organize Terraform files into logical component folders.

**Architecture:** Create a `scripts/` directory under `terraform/talos/` for extracted shell scripts. Each script receives Terraform variables via environment variables or command-line arguments. The Terraform `local-exec` provisioners call the extracted scripts.

**Tech Stack:** Terraform, Bash

---

## Script Extraction Inventory

### Priority 1: Complex Business Logic (extract first)

| Script | Source File | Lines | Description |
|--------|-------------|-------|-------------|
| `forgejo-generate-token.sh` | `forgejo.tf:170-246` | 77 | API token generation with conflict retry |
| `forgejo-create-repo.sh` | `forgejo.tf:280-342` | 63 | Repository creation via API |
| `forgejo-push-repo.sh` | `forgejo.tf:374-427` | 54 | Git push with token sanitization |
| `nvidia-gpu-setup.sh` | `addons.tf:180-239` | 60 | RuntimeClass + DaemonSet YAML apply |

### Priority 2: Infrastructure Lifecycle (extract second)

| Script | Source File | Lines | Description |
|--------|-------------|-------|-------------|
| `fluxcd-pre-destroy.sh` | `pre-destroy.tf:35-85` | 51 | FluxCD cleanup on destroy |
| `longhorn-pre-destroy.sh` | `pre-destroy.tf:111-168` | 58 | Longhorn cleanup on destroy |
| `zitadel-pre-destroy.sh` | `pre-destroy.tf:287-336` | 50 | Zitadel cleanup on destroy |
| `wait-vm-dhcp.sh` | `apply.tf:14-47` | 34 | Proxmox DHCP IP detection |
| `wait-static-ip.sh` | `apply.tf:98-122` | 25 | Talos static IP verification |

### Priority 3: FluxCD Bootstrap (extract third)

| Script | Source File | Lines | Description |
|--------|-------------|-------|-------------|
| `fluxcd-install.sh` | `fluxcd.tf:65-90` | 26 | FluxCD installation |
| `fluxcd-git-secret.sh` | `fluxcd.tf:114-141` | 28 | Git credentials secret |
| `fluxcd-git-repository.sh` | `fluxcd.tf:166-202` | 37 | GitRepository CRD creation |
| `fluxcd-kustomization.sh` | `fluxcd.tf:222-249` | 28 | Kustomization CRD creation |
| `fluxcd-sops-secret.sh` | `fluxcd.tf:298-321` | 24 | SOPS age key secret |

### Keep Inline (under 20 lines or too simple)

| Script | Source File | Lines | Reason |
|--------|-------------|-------|--------|
| `remove_control_plane_taint` | `addons.tf:22-33` | 12 | Too simple |
| `wait_for_kubernetes` | `bootstrap.tf:61-72` | 12 | Replaced by `talos_cluster_health` in provider plan |
| `wait_for_cilium` | `helm.tf:16-41` | 26 | Borderline - extract if convenient |
| `wait_for_forgejo` | `forgejo.tf:124-149` | 26 | Borderline - extract if convenient |
| `wait_for_postgresql` | `postgresql.tf:96-117` | 22 | Borderline - extract if convenient |
| `label_node_for_longhorn` | `addons.tf:70-86` | 17 | Short, simple |
| `configure_longhorn_backup_target` | `addons.tf:130-151` | 22 | Borderline |
| `flux_verify` | `fluxcd.tf:266-280` | 15 | Diagnostic only |
| `forgejo_pre_destroy` | `pre-destroy.tf:193-217` | 25 | Short, simple |
| `weave_gitops_pre_destroy` | `pre-destroy.tf:243-262` | 20 | Short, simple |

---

### Task 1: Create Scripts Directory Structure

**Files:**
- Create: `terraform/talos/scripts/` (directory)

**Step 1: Create directory**

```bash
mkdir -p terraform/talos/scripts
```

**Step 2: Commit**

```bash
git add terraform/talos/scripts/.gitkeep
git commit -m "chore(terraform): create scripts directory for extracted shell scripts"
```

---

### Task 2: Extract Forgejo Scripts

**Files:**
- Create: `terraform/talos/scripts/forgejo-generate-token.sh`
- Create: `terraform/talos/scripts/forgejo-create-repo.sh`
- Create: `terraform/talos/scripts/forgejo-push-repo.sh`
- Modify: `terraform/talos/forgejo.tf`

**Step 1: Extract forgejo-generate-token.sh**

Create `terraform/talos/scripts/forgejo-generate-token.sh` with the script contents from `forgejo.tf:170-246`. The script should:
- Accept environment variables: `FORGEJO_IP`, `FORGEJO_ADMIN_USER`, `FORGEJO_ADMIN_PASS`, `TOKEN_FILE`
- Be executable (`chmod +x`)
- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Keep all existing logic (netrc, URL encoding, conflict retry, token extraction)

**Step 2: Extract forgejo-create-repo.sh**

Create `terraform/talos/scripts/forgejo-create-repo.sh` with contents from `forgejo.tf:280-342`. Environment variables: `FORGEJO_IP`, `REPO_NAME`, `REPO_PRIVATE`, `FORGEJO_ADMIN_USER`, `FORGEJO_ADMIN_PASS`.

**Step 3: Extract forgejo-push-repo.sh**

Create `terraform/talos/scripts/forgejo-push-repo.sh` with contents from `forgejo.tf:374-427`. Environment variables: `FORGEJO_IP`, `REPO_NAME`, `GIT_BRANCH`, `GIT_USER`, `GIT_TOKEN`, `REPO_ROOT`.

**Step 4: Update forgejo.tf to call scripts**

Replace each inline `command = <<-EOT ... EOT` with:

```hcl
command = "${path.module}/scripts/forgejo-generate-token.sh"
```

Keep the `environment` blocks that pass Terraform variables as env vars. Add `TOKEN_FILE` and `REPO_ROOT` env vars where needed (currently `${path.module}` references).

**Step 5: Make scripts executable**

```bash
chmod +x terraform/talos/scripts/forgejo-*.sh
```

**Step 6: Validate**

Run: `cd terraform/talos && terraform fmt && terraform validate`
Expected: No errors.

**Step 7: Commit**

```bash
git add terraform/talos/scripts/forgejo-*.sh terraform/talos/forgejo.tf
git commit -m "refactor(terraform): extract Forgejo scripts to separate files

Move token generation (77 lines), repo creation (63 lines), and git
push (54 lines) from inline heredocs to standalone scripts in scripts/."
```

---

### Task 3: Extract NVIDIA GPU Setup Script

**Files:**
- Create: `terraform/talos/scripts/nvidia-gpu-setup.sh`
- Modify: `terraform/talos/addons.tf`

**Step 1: Extract nvidia-gpu-setup.sh**

Create `terraform/talos/scripts/nvidia-gpu-setup.sh` with contents from `addons.tf:180-239`. Environment variables: `KUBECONFIG`, `NVIDIA_DEVICE_PLUGIN_VERSION`.

The script contains embedded Kubernetes YAML for RuntimeClass and DaemonSet. Keep the YAML heredocs in the script - they are the actual content being applied.

**Step 2: Update addons.tf to call script**

Replace the inline command with:

```hcl
command = "${path.module}/scripts/nvidia-gpu-setup.sh"
environment = {
  KUBECONFIG                   = local.kubeconfig_path
  NVIDIA_DEVICE_PLUGIN_VERSION = var.nvidia_device_plugin_version
}
```

**Step 3: Make executable and validate**

```bash
chmod +x terraform/talos/scripts/nvidia-gpu-setup.sh
cd terraform/talos && terraform fmt && terraform validate
```

**Step 4: Commit**

```bash
git add terraform/talos/scripts/nvidia-gpu-setup.sh terraform/talos/addons.tf
git commit -m "refactor(terraform): extract NVIDIA GPU setup to separate script"
```

---

### Task 4: Extract Pre-Destroy Scripts

**Files:**
- Create: `terraform/talos/scripts/fluxcd-pre-destroy.sh`
- Create: `terraform/talos/scripts/longhorn-pre-destroy.sh`
- Create: `terraform/talos/scripts/zitadel-pre-destroy.sh`
- Modify: `terraform/talos/pre-destroy.tf`

**Step 1: Extract fluxcd-pre-destroy.sh**

From `pre-destroy.tf:35-85`. Environment variable: `KUBECONFIG`.

**Step 2: Extract longhorn-pre-destroy.sh**

From `pre-destroy.tf:111-168`. Environment variables: `KUBECONFIG`, `NAMESPACE` (default: `longhorn-system`).

**Step 3: Extract zitadel-pre-destroy.sh**

From `pre-destroy.tf:287-336`. Environment variables: `KUBECONFIG`, `NAMESPACE` (default: `auth`).

**Step 4: Update pre-destroy.tf**

Replace each inline command with script call. Keep `on_failure = continue` on the provisioners.

**Step 5: Make executable and validate**

```bash
chmod +x terraform/talos/scripts/*-pre-destroy.sh
cd terraform/talos && terraform fmt && terraform validate
```

**Step 6: Commit**

```bash
git add terraform/talos/scripts/*-pre-destroy.sh terraform/talos/pre-destroy.tf
git commit -m "refactor(terraform): extract pre-destroy cleanup scripts

Move FluxCD (51 lines), Longhorn (58 lines), and Zitadel (50 lines)
destroy-time cleanup from inline heredocs to standalone scripts."
```

---

### Task 5: Extract FluxCD Bootstrap Scripts

**Files:**
- Create: `terraform/talos/scripts/fluxcd-install.sh`
- Create: `terraform/talos/scripts/fluxcd-git-secret.sh`
- Create: `terraform/talos/scripts/fluxcd-git-repository.sh`
- Create: `terraform/talos/scripts/fluxcd-kustomization.sh`
- Create: `terraform/talos/scripts/fluxcd-sops-secret.sh`
- Modify: `terraform/talos/fluxcd.tf`

**Step 1: Extract each FluxCD script**

Each script should accept `KUBECONFIG` as an environment variable. Additional variables:
- `fluxcd-install.sh`: No additional vars (uses flux CLI)
- `fluxcd-git-secret.sh`: `GIT_OWNER`, `GIT_TOKEN`
- `fluxcd-git-repository.sh`: `GIT_URL`, `GIT_BRANCH`
- `fluxcd-kustomization.sh`: `FLUXCD_PATH`
- `fluxcd-sops-secret.sh`: `SOPS_AGE_KEY_FILE`

**Step 2: Update fluxcd.tf to call scripts**

Replace each inline command block with the corresponding script call.

**Step 3: Make executable and validate**

```bash
chmod +x terraform/talos/scripts/fluxcd-*.sh
cd terraform/talos && terraform fmt && terraform validate
```

**Step 4: Commit**

```bash
git add terraform/talos/scripts/fluxcd-*.sh terraform/talos/fluxcd.tf
git commit -m "refactor(terraform): extract FluxCD bootstrap scripts

Move install (26 lines), git-secret (28 lines), git-repository (37 lines),
kustomization (28 lines), and sops-secret (24 lines) to standalone scripts."
```

---

### Task 6: Extract Wait Scripts

**Files:**
- Create: `terraform/talos/scripts/wait-vm-dhcp.sh`
- Create: `terraform/talos/scripts/wait-static-ip.sh`
- Modify: `terraform/talos/apply.tf`

**Step 1: Extract wait-vm-dhcp.sh**

From `apply.tf:14-47`. Environment variables: `PROXMOX_API_TOKEN`, `PROXMOX_URL`, `PROXMOX_NODE`, `VM_ID`, `FALLBACK_IP`, `OUTPUT_FILE`.

**Step 2: Extract wait-static-ip.sh**

From `apply.tf:98-122`. Environment variables: `NODE_IP`, `TALOSCONFIG`, `OUTPUT_FILE`.

**Step 3: Update apply.tf and validate**

```bash
chmod +x terraform/talos/scripts/wait-*.sh
cd terraform/talos && terraform fmt && terraform validate
```

**Step 4: Commit**

```bash
git add terraform/talos/scripts/wait-*.sh terraform/talos/apply.tf
git commit -m "refactor(terraform): extract VM wait scripts

Move DHCP IP detection (34 lines) and static IP verification (25 lines)
to standalone scripts."
```

---

## Validation Checklist

- [ ] All extracted scripts are executable (`chmod +x`)
- [ ] All scripts start with `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] All Terraform variables are passed via `environment` blocks (no secrets in script files)
- [ ] `terraform fmt` passes
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows no changes (scripts produce same behavior)
- [ ] `destroy.sh` still works (references to terraform state resources unchanged)
- [ ] Total: 13 scripts extracted, ~600+ lines moved from .tf to .sh files
