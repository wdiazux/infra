# PostgreSQL for Forgejo
#
# Deploys Bitnami PostgreSQL as a separate Helm release for Forgejo.
# This provides better stability and allows independent lifecycle management.
#
# Prerequisites:
# - Longhorn storage installed
# - SOPS secrets with PostgreSQL credentials

# ============================================================================
# PostgreSQL Helm Release
# ============================================================================

resource "helm_release" "postgresql" {
  count = var.enable_forgejo ? 1 : 0

  name             = "forgejo-postgres"
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = var.postgresql_version
  namespace        = kubernetes_namespace.forgejo[0].metadata[0].name
  create_namespace = false

  # Authentication
  set = [
    {
      name  = "auth.database"
      value = "forgejo"
    },
    {
      name  = "auth.username"
      value = local.git_secrets.postgresql_username
    },
    # Storage - use Longhorn
    {
      name  = "primary.persistence.storageClass"
      value = "longhorn"
    },
    {
      name  = "primary.persistence.size"
      value = "2Gi"
    },
    # Resources (reasonable for homelab)
    {
      name  = "primary.resources.requests.cpu"
      value = "100m"
    },
    {
      name  = "primary.resources.requests.memory"
      value = "256Mi"
    },
    {
      name  = "primary.resources.limits.cpu"
      value = "500m"
    },
    {
      name  = "primary.resources.limits.memory"
      value = "512Mi"
    },
    # Disable read replicas for single-node cluster
    {
      name  = "readReplicas.replicaCount"
      value = "0"
    },
    # Disable metrics for homelab (optional, enable if you want Prometheus scraping)
    {
      name  = "metrics.enabled"
      value = "false"
    },
  ]

  set_sensitive = [
    {
      name  = "auth.password"
      value = local.git_secrets.postgresql_password
    },
  ]

  wait    = true
  timeout = 600

  depends_on = [
    helm_release.longhorn,
    kubernetes_namespace.forgejo
  ]
}

# ============================================================================
# Wait for PostgreSQL to be Ready
# ============================================================================

resource "null_resource" "wait_for_postgresql" {
  count = var.enable_forgejo ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting for PostgreSQL to be ready..."

      for i in $(seq 1 60); do
        if kubectl --kubeconfig=${local.kubeconfig_path} get pod -n forgejo \
          -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
          # Also check if the pod is ready
          READY=$(kubectl --kubeconfig=${local.kubeconfig_path} get pod -n forgejo \
            -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
          if [ "$READY" = "True" ]; then
            echo "PostgreSQL is ready!"
            exit 0
          fi
        fi
        echo "Waiting for PostgreSQL... ($i/60)"
        sleep 5
      done

      echo "ERROR: Timeout waiting for PostgreSQL"
      exit 1
    EOT
  }

  depends_on = [
    helm_release.postgresql
  ]
}

# ============================================================================
# Notes
# ============================================================================
#
# Connection string for Forgejo:
#   host: forgejo-postgres.forgejo.svc.cluster.local
#   port: 5432
#   database: forgejo
#   user: (from SOPS secret)
#   password: (from SOPS secret)
#
# Manual connection test:
#   kubectl run pg-test --rm -it --restart=Never \
#     --image=postgres:17 \
#     --env="PGPASSWORD=<password>" \
#     -- psql -h forgejo-postgres.forgejo.svc.cluster.local -U <user> -d forgejo
#
# Backup:
#   PostgreSQL data is stored on Longhorn and backed up via NFS
