# FluxCD Bootstrap for Forgejo (HTTP)
#
# Automatically bootstraps FluxCD for GitOps management after the cluster
# is ready. FluxCD will then manage all Kubernetes resources from Git.
#
# NOTE: Standard `flux bootstrap gitea` requires HTTPS. Since in-cluster
# Forgejo runs on HTTP, we use manual installation approach:
# 1. Install FluxCD components with `flux install`
# 2. Create Git credentials secret
# 3. Create GitRepository source (HTTP)
# 4. Create Kustomization to sync from path
#
# Bootstrap Flow:
# 1. Talos cluster ready with Cilium (inline manifest)
# 2. Longhorn installed via Helm
# 3. Forgejo installed via Helm (if enable_forgejo=true)
# 4. Forgejo token auto-generated
# 5. FluxCD installed and configured for HTTP Forgejo
# 6. FluxCD syncs kubernetes/clusters/homelab/
#
# Token Sources:
# - Auto-generated from in-cluster Forgejo (if enable_forgejo=true)
# - OR from SOPS-encrypted git-creds.enc.yaml (external Forgejo)

# ============================================================================
# Computed Values
# ============================================================================

locals {
  # Git token: auto-generated from Forgejo or from SOPS
  fluxcd_git_token = var.enable_forgejo ? (
    try(trimspace(data.local_file.forgejo_flux_token[0].content), "")
    ) : (
    try(local.git_secrets.git_token, var.git_token)
  )

  # Git settings (prefer SOPS, fall back to variables)
  fluxcd_git_repository = try(local.git_secrets.git_repository, var.git_repository)

  # Git owner: use Forgejo admin when in-cluster, otherwise from SOPS/variables
  # This ensures repo owner matches who created the repo
  fluxcd_git_owner = var.enable_forgejo ? (
    try(local.git_secrets.forgejo_admin_username, "forgejo_admin")
    ) : (
    try(local.git_secrets.git_owner, var.git_owner)
  )

  # HTTP URL for in-cluster Forgejo via proxy (used when enable_forgejo=true)
  forgejo_http_url = "http://${var.forgejo_proxy_ip}/${local.fluxcd_git_owner}/${local.fluxcd_git_repository}.git"
}

# ============================================================================
# FluxCD Installation (Controllers)
# ============================================================================

resource "null_resource" "flux_install" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    # Re-run if we want to update flux
    flux_version = "latest"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Installing FluxCD Components ==="

      # Validate flux CLI
      if ! command -v flux &> /dev/null; then
        echo "ERROR: flux CLI not found. Install via nix-shell."
        exit 1
      fi

      # Pre-flight check
      flux check --pre --kubeconfig=${local.kubeconfig_path} || true

      # Install FluxCD components
      flux install --kubeconfig=${local.kubeconfig_path} \
        --components-extra=image-reflector-controller,image-automation-controller

      # Wait for controllers to be ready
      echo "Waiting for FluxCD controllers..."
      kubectl --kubeconfig=${local.kubeconfig_path} wait --for=condition=available \
        --timeout=300s deployment/source-controller -n flux-system
      kubectl --kubeconfig=${local.kubeconfig_path} wait --for=condition=available \
        --timeout=300s deployment/kustomize-controller -n flux-system

      echo "=== FluxCD Components Installed ==="
    EOT
  }

  depends_on = [
    helm_release.longhorn,
    null_resource.forgejo_generate_token,
    null_resource.forgejo_push_repo,
    terraform_data.fluxcd_pre_destroy # Pre-destroy runs cleanup before uninstall
  ]
}

# ============================================================================
# FluxCD Git Credentials Secret
# ============================================================================

resource "null_resource" "flux_git_secret" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_owner      = local.fluxcd_git_owner
    git_repository = local.fluxcd_git_repository
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Creating FluxCD Git Credentials ==="

      # Validate git owner
      if [ -z "${local.fluxcd_git_owner}" ]; then
        echo "ERROR: Git owner is empty."
        exit 1
      fi

      # Validate token
      if [ -z "$GIT_TOKEN" ]; then
        echo "ERROR: Git token is empty."
        exit 1
      fi

      # Delete existing secret if present
      kubectl --kubeconfig=${local.kubeconfig_path} delete secret flux-system \
        -n flux-system --ignore-not-found

      # Create git credentials secret
      kubectl --kubeconfig=${local.kubeconfig_path} create secret generic flux-system \
        --namespace=flux-system \
        --from-literal=username="${local.fluxcd_git_owner}" \
        --from-literal=password="$GIT_TOKEN"

      echo "=== FluxCD Git Credentials Created ==="
    EOT

    environment = {
      GIT_TOKEN = local.fluxcd_git_token
    }
  }

  depends_on = [
    null_resource.flux_install
  ]
}

# ============================================================================
# FluxCD GitRepository Source (HTTP)
# ============================================================================

resource "null_resource" "flux_git_repository" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_url  = local.forgejo_http_url
    git_path = var.fluxcd_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Creating FluxCD GitRepository Source ==="
      echo "URL: ${local.forgejo_http_url}"
      echo "Branch: ${var.git_branch}"

      # Create GitRepository pointing to HTTP Forgejo
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 5m
  url: ${local.forgejo_http_url}
  ref:
    branch: ${var.git_branch}
  secretRef:
    name: flux-system
EOF

      # Wait for GitRepository to be ready
      echo "Waiting for GitRepository to sync..."
      for i in $(seq 1 30); do
        STATUS=$(kubectl --kubeconfig=${local.kubeconfig_path} get gitrepository flux-system \
          -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [ "$STATUS" = "True" ]; then
          echo "GitRepository is ready!"
          break
        fi
        echo "Waiting for GitRepository... ($i/30) Status: $STATUS"
        sleep 10
      done

      echo "=== FluxCD GitRepository Created ==="
    EOT
  }

  depends_on = [
    null_resource.flux_git_secret
  ]
}

# ============================================================================
# FluxCD Kustomization (Sync from Path)
# ============================================================================

resource "null_resource" "flux_kustomization" {
  count = var.enable_fluxcd ? 1 : 0

  triggers = {
    git_path = var.fluxcd_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Creating FluxCD Kustomization ==="
      echo "Path: ${var.fluxcd_path}"

      # Create Kustomization to sync from path
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m
  path: ./${var.fluxcd_path}
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
  timeout: 3m
EOF

      echo "=== FluxCD Kustomization Created ==="
    EOT
  }

  depends_on = [
    null_resource.flux_git_repository,
    null_resource.create_sops_age_secret
  ]
}

# ============================================================================
# FluxCD Verification
# ============================================================================

resource "null_resource" "flux_verify" {
  count = var.enable_fluxcd ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for FluxCD to reconcile..."
      sleep 30

      echo "=== FluxCD Status ==="
      kubectl --kubeconfig=${local.kubeconfig_path} get pods -n flux-system

      echo "=== GitRepository Status ==="
      flux get sources git --kubeconfig=${local.kubeconfig_path} -A || true

      echo "=== Kustomizations ==="
      flux get kustomizations --kubeconfig=${local.kubeconfig_path} -A || true

      echo "=== FluxCD Verification Complete ==="
    EOT
  }

  depends_on = [
    null_resource.flux_kustomization
  ]
}

# ============================================================================
# SOPS Age Secret for Application Secrets
# ============================================================================
# Creates the sops-age secret that FluxCD uses to decrypt encrypted secrets.
# This enables GitOps for secrets: encrypt with SOPS, commit to Git, FluxCD decrypts.

resource "null_resource" "create_sops_age_secret" {
  count = var.enable_fluxcd && var.sops_age_key_file != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Creating SOPS Age secret for FluxCD..."

      # Expand tilde in path (shell expansion doesn't work directly)
      SOPS_KEY_FILE="$SOPS_AGE_KEY_FILE"
      if [ ! -f "$SOPS_KEY_FILE" ]; then
        echo "ERROR: SOPS Age key file not found: $SOPS_KEY_FILE"
        exit 1
      fi

      # Check if secret already exists
      if kubectl --kubeconfig=${local.kubeconfig_path} get secret sops-age -n flux-system &>/dev/null; then
        echo "sops-age secret already exists, skipping"
        exit 0
      fi

      # Create the secret
      kubectl --kubeconfig=${local.kubeconfig_path} create secret generic sops-age \
        --namespace=flux-system \
        --from-file=age.agekey="$SOPS_KEY_FILE"

      echo "SOPS Age secret created successfully"
    EOT

    environment = {
      SOPS_AGE_KEY_FILE = pathexpand(var.sops_age_key_file)
    }
  }

  depends_on = [
    null_resource.flux_install
  ]
}
