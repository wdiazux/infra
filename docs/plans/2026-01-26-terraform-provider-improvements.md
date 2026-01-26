# Terraform Provider Improvements Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Adopt 3 underutilized Talos provider features to improve maintainability and reduce shell script polling.

**Architecture:** Replace hardcoded schematic IDs with dynamic `talos_image_factory_schematic` + `talos_image_factory_urls`, and replace shell-based cluster health polling with `talos_cluster_health` data source.

**Tech Stack:** Terraform, siderolabs/talos provider ~> 0.10.0

---

## Provider Evaluation Summary (Research Complete)

| Provider | Decision | Rationale |
|----------|----------|-----------|
| Forgejo (`svalabs/forgejo`) | **Skip** | No `forgejo_token` resource - the main pain point. Only replaces repo creation. |
| Cilium (`littlejo/cilium`) | **Skip** | Pre-1.0, can't solve bootstrap ordering. Current inline manifest is the official pattern. |
| cert-manager (`terraform-iaac/cert-manager`) | **Skip** | FluxCD approach is superior (self-healing, Reflector support). |
| Talos (`siderolabs/talos`) | **3 improvements** | Already in use; adopt `image_factory_schematic`, `image_factory_urls`, `cluster_health`. |

---

### Task 1: Dynamic Image Factory Schematic

**Files:**
- Modify: `terraform/talos/config.tf` (add image factory resources)
- Modify: `terraform/talos/variables.tf` (remove `talos_schematic_id` variable)
- Modify: `terraform/talos/vm.tf` (use dynamic installer URL)
- Modify: `terraform/talos/locals.tf` (update talos_installer_image reference)

**Context:** Currently, `variables.tf` has a hardcoded `talos_schematic_id` variable set to `b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321`. This must be manually updated when changing Talos versions or extensions. The provider can generate this dynamically.

**Step 1: Add image factory data source and resource to config.tf**

Add at the top of `terraform/talos/config.tf` (before the existing `data "talos_machine_configuration"`):

```hcl
# ============================================================================
# Image Factory - Dynamic schematic generation
# ============================================================================

# Query available extensions for the current Talos version
data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = [
      "siderolabs/qemu-guest-agent",
      "siderolabs/iscsi-tools",
      "siderolabs/util-linux-tools",
    ]
  }
}

# Query GPU extensions separately (conditional)
data "talos_image_factory_extensions_versions" "gpu" {
  count         = var.enable_gpu_passthrough ? 1 : 0
  talos_version = var.talos_version
  filters = {
    names = [
      "nonfree-kmod-nvidia-production",
    ]
  }
}

# Generate schematic ID from extensions list
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = concat(
          data.talos_image_factory_extensions_versions.this.extensions_info[*].name,
          var.enable_gpu_passthrough ? data.talos_image_factory_extensions_versions.gpu[0].extensions_info[*].name : [],
        )
      }
    }
  })
}

# Generate installer and ISO URLs from schematic
data "talos_image_factory_urls" "this" {
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.this.id
  platform      = "nocloud"
}
```

**Step 2: Update locals.tf to use dynamic schematic**

In `terraform/talos/locals.tf`, find and replace the `talos_installer_image` local:

```hcl
# Old:
talos_installer_image = "${var.talos_schematic_id}:${var.talos_version}"

# New:
talos_installer_image = "${talos_image_factory_schematic.this.id}:${var.talos_version}"
```

**Step 3: Remove the hardcoded schematic variable from variables.tf**

Remove the `talos_schematic_id` variable block from `terraform/talos/variables.tf`:

```hcl
# DELETE this entire block:
variable "talos_schematic_id" {
  description = "Talos Factory schematic ID (includes extensions)"
  type        = string
  default     = "b81082c1666383fec39d911b71e94a3ee21bab3ea039663c6e1aa9beee822321"
}
```

**Step 4: Add schematic outputs**

In `terraform/talos/outputs.tf`, add:

```hcl
output "talos_schematic_id" {
  description = "Dynamically generated Talos Factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "talos_extensions" {
  description = "Talos system extensions included in schematic"
  value = concat(
    data.talos_image_factory_extensions_versions.this.extensions_info[*].name,
    var.enable_gpu_passthrough ? data.talos_image_factory_extensions_versions.gpu[0].extensions_info[*].name : [],
  )
}
```

**Step 5: Validate**

Run: `cd terraform/talos && terraform fmt && terraform validate`
Expected: No errors. The plan should show the new resources being created and the schematic ID should match the current hardcoded value.

Run: `terraform plan -out=tfplan 2>&1 | head -80`
Expected: Plan shows `talos_image_factory_schematic.this` will be created. No destructive changes to existing resources.

**Step 6: Commit**

```bash
git add terraform/talos/config.tf terraform/talos/variables.tf terraform/talos/locals.tf terraform/talos/outputs.tf
git commit -m "feat(terraform): dynamic Talos image factory schematic generation

Replace hardcoded talos_schematic_id with talos_image_factory_schematic
resource. Extensions are now self-documenting in Terraform code and
automatically update when changing Talos versions."
```

---

### Task 2: Replace Shell Polling with talos_cluster_health

**Files:**
- Modify: `terraform/talos/bootstrap.tf` (replace `wait_for_kubernetes` with `talos_cluster_health`)
- Modify: `terraform/talos/helm.tf` (update dependency to use cluster_health)

**Context:** Currently, `bootstrap.tf` has a `null_resource.wait_for_kubernetes` that polls `kubectl get nodes` in a shell loop. The `talos_cluster_health` data source provides a native, more reliable alternative.

**Step 1: Add talos_cluster_health data source to bootstrap.tf**

Replace the `null_resource.wait_for_kubernetes` block in `terraform/talos/bootstrap.tf` with:

```hcl
# Wait for cluster to be healthy (replaces shell-based polling)
data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.cluster.client_configuration
  control_plane_nodes  = [var.node_ip]
  endpoints            = [var.node_ip]

  timeouts = {
    read = "5m"
  }

  depends_on = [
    talos_machine_bootstrap.node,
  ]
}
```

**Step 2: Update dependencies that reference wait_for_kubernetes**

In `terraform/talos/helm.tf`, update the `depends_on` for the Cilium wait to reference `data.talos_cluster_health.this` instead of `null_resource.wait_for_kubernetes`.

Search for `null_resource.wait_for_kubernetes` across all .tf files and update references to `data.talos_cluster_health.this`.

**Step 3: Remove the old null_resource.wait_for_kubernetes**

Delete the entire `null_resource.wait_for_kubernetes` block from `bootstrap.tf`.

**Step 4: Validate**

Run: `cd terraform/talos && terraform fmt && terraform validate`
Expected: No errors.

**Step 5: Commit**

```bash
git add terraform/talos/bootstrap.tf terraform/talos/helm.tf
git commit -m "refactor(terraform): replace shell polling with talos_cluster_health

Use native talos_cluster_health data source instead of null_resource
with kubectl polling loop. More reliable and eliminates shell dependency."
```

---

### Task 3: Update Documentation

**Files:**
- Modify: `docs/reference/terraform.md` (update provider features section)
- Modify: `CLAUDE.md` (update if schematic reference exists)

**Step 1: Update terraform reference docs**

Add a note about the new image factory resources in `docs/reference/terraform.md` if it documents the Talos provider resources.

**Step 2: Commit**

```bash
git add docs/
git commit -m "docs: update Terraform reference for image factory and cluster health"
```

---

## Validation Checklist

- [ ] `terraform fmt` passes
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows no destructive changes to existing infrastructure
- [ ] Schematic ID in plan matches current hardcoded value (for same extensions)
- [ ] All `depends_on` chains are correct
- [ ] No references to removed `talos_schematic_id` variable remain
- [ ] No references to removed `null_resource.wait_for_kubernetes` remain
