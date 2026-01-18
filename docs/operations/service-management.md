# Service Management Operations

Common operations for managing Kubernetes services in the homelab cluster.

## Prerequisites

```bash
# Set kubeconfig
export KUBECONFIG=/home/wdiaz/devland/infra/terraform/talos/kubeconfig

# Verify cluster access
kubectl get nodes
```

## 1. Disable a Service (Temporary)

Scale deployments to zero replicas without deleting resources. Data is preserved.

### Scale Down All Components

```bash
# Example: Disable Paperless-ngx
kubectl scale deployment -n management paperless-server --replicas=0
kubectl scale deployment -n management paperless-redis --replicas=0
kubectl scale deployment -n management paperless-tika --replicas=0
kubectl scale deployment -n management paperless-gotenberg --replicas=0
kubectl scale statefulset -n management paperless-postgres --replicas=0

# Verify all pods are terminated
kubectl get pods -n management -l app.kubernetes.io/part-of=paperless
```

### Scale Down Single Component

```bash
# Scale a specific deployment
kubectl scale deployment -n <namespace> <deployment-name> --replicas=0

# Scale a statefulset
kubectl scale statefulset -n <namespace> <statefulset-name> --replicas=0
```

### Re-enable Service

```bash
# Scale back up
kubectl scale deployment -n management paperless-server --replicas=1
kubectl scale deployment -n management paperless-redis --replicas=1
kubectl scale deployment -n management paperless-tika --replicas=1
kubectl scale deployment -n management paperless-gotenberg --replicas=1
kubectl scale statefulset -n management paperless-postgres --replicas=1

# Watch pods come up
kubectl get pods -n management -l app.kubernetes.io/part-of=paperless -w
```

## 2. Delete a Service (Keep Data)

Remove Kubernetes resources but preserve PersistentVolumeClaims (data).

### Delete Using Kustomize

```bash
# Delete all resources defined in kustomization
kubectl delete -k kubernetes/apps/base/management/paperless/

# Note: PVCs with "Retain" policy will NOT be deleted
```

### Delete Individual Components

```bash
# Delete deployments
kubectl delete deployment -n management paperless-server paperless-redis paperless-tika paperless-gotenberg

# Delete statefulset (keeps PVC by default)
kubectl delete statefulset -n management paperless-postgres

# Delete services
kubectl delete svc -n management paperless paperless-postgres paperless-redis paperless-tika paperless-gotenberg

# Delete configmaps
kubectl delete configmap -n management -l app.kubernetes.io/part-of=paperless

# Delete secrets (be careful - you may need these!)
# kubectl delete secret -n management paperless-secrets
```

### Verify Deletion

```bash
# Check no pods remain
kubectl get pods -n management -l app.kubernetes.io/part-of=paperless

# PVCs should still exist
kubectl get pvc -n management | grep paperless
```

## 3. Delete Service AND Volumes (Complete Removal)

**WARNING:** This permanently deletes all data. Back up first if needed!

### Backup Data First (Optional)

```bash
# For Longhorn volumes - create a backup via UI or CLI
# Access Longhorn UI at http://10.10.2.12

# For database - dump before deletion
kubectl exec -n management paperless-postgres-0 -- pg_dump -U paperless paperless > paperless-backup.sql
```

### Delete Everything Including PVCs

```bash
# Step 1: Delete deployments and statefulsets
kubectl delete deployment -n management paperless-server paperless-redis paperless-tika paperless-gotenberg
kubectl delete statefulset -n management paperless-postgres

# Step 2: Wait for pods to terminate
kubectl wait --for=delete pod -n management -l app.kubernetes.io/part-of=paperless --timeout=60s

# Step 3: Delete PVCs (this deletes Longhorn volumes!)
kubectl delete pvc -n management paperless-data paperless-redis
kubectl delete pvc -n management data-paperless-postgres-0  # StatefulSet PVC

# Step 4: Delete NFS PVC (doesn't delete NFS data, just the claim)
kubectl delete pvc -n management paperless-documents

# Step 5: Delete services and secrets
kubectl delete svc -n management paperless paperless-postgres paperless-redis paperless-tika paperless-gotenberg
kubectl delete secret -n management paperless-secrets

# Step 6: (Optional) Delete NFS PV
kubectl delete pv nfs-documents-paperless
```

### Verify Complete Removal

```bash
# No resources should remain
kubectl get all -n management -l app.kubernetes.io/part-of=paperless
kubectl get pvc -n management | grep paperless
kubectl get pv | grep paperless
```

### Clean NFS Data (Optional)

```bash
# On NAS - remove NFS directory contents
rm -rf /mnt/tank/documents/Paperless/*
```

## 4. Update a Service

### Update Image Version

```bash
# Option 1: Edit deployment directly
kubectl set image deployment/paperless-server -n management paperless=ghcr.io/paperless-ngx/paperless-ngx:v2.21.0

# Option 2: Edit manifest and apply
vim kubernetes/apps/base/management/paperless/server-deployment.yaml
# Change: image: ghcr.io/paperless-ngx/paperless-ngx:v2.21.0
kubectl apply -f kubernetes/apps/base/management/paperless/server-deployment.yaml

# Option 3: Apply entire kustomization
kubectl apply -k kubernetes/apps/base/management/paperless/
```

### Update Configuration

```bash
# Edit configmap
kubectl edit configmap -n management <configmap-name>

# Or edit file and apply
vim kubernetes/apps/base/management/paperless/configmap.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/configmap.yaml

# Restart deployment to pick up changes
kubectl rollout restart deployment -n management paperless-server
```

### Update Secrets

```bash
# Decrypt, edit, re-encrypt
cd kubernetes/apps/base/management/paperless
sops secret.enc.yaml  # Opens in editor, saves encrypted

# Apply updated secret
sops -d secret.enc.yaml | kubectl apply -f -

# Restart deployment to pick up new secrets
kubectl rollout restart deployment -n management paperless-server
```

### Watch Rollout

```bash
# Monitor rollout status
kubectl rollout status deployment/paperless-server -n management

# Check new pods
kubectl get pods -n management -l app.kubernetes.io/name=paperless-server -w
```

## 5. Recreate a Service (Fresh Start)

Complete removal and fresh deployment with new data.

### Quick Recreate (Single Command)

```bash
# Delete and recreate using kustomize
kubectl delete -k kubernetes/apps/base/management/paperless/ --ignore-not-found
kubectl delete pvc -n management paperless-data paperless-redis data-paperless-postgres-0 --ignore-not-found

# Wait for PVC deletion
sleep 10

# Decrypt and apply secrets first
sops -d kubernetes/apps/base/management/paperless/secret.enc.yaml | kubectl apply -f -

# Apply all resources
kubectl apply -k kubernetes/apps/base/management/paperless/

# Watch pods come up
kubectl get pods -n management -l app.kubernetes.io/part-of=paperless -w
```

### Step-by-Step Recreate

```bash
# 1. Delete all resources
kubectl delete deployment -n management paperless-server paperless-redis paperless-tika paperless-gotenberg
kubectl delete statefulset -n management paperless-postgres
kubectl delete svc -n management paperless paperless-postgres paperless-redis paperless-tika paperless-gotenberg

# 2. Wait for pods to terminate
kubectl wait --for=delete pod -n management -l app.kubernetes.io/part-of=paperless --timeout=60s

# 3. Delete PVCs for fresh data
kubectl delete pvc -n management paperless-data paperless-redis data-paperless-postgres-0

# 4. Wait for Longhorn to release volumes
sleep 15

# 5. Apply secrets
sops -d kubernetes/apps/base/management/paperless/secret.enc.yaml | kubectl apply -f -

# 6. Apply all other resources
kubectl apply -f kubernetes/apps/base/management/paperless/pvc.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/postgres-statefulset.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/redis-deployment.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/services.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/tika-deployment.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/gotenberg-deployment.yaml
kubectl apply -f kubernetes/apps/base/management/paperless/server-deployment.yaml

# 7. Verify all pods are running
kubectl get pods -n management -l app.kubernetes.io/part-of=paperless
```

## Common Patterns by Service Type

### Simple Service (Single Deployment)

```bash
# Disable
kubectl scale deployment -n <ns> <name> --replicas=0

# Delete (keep data)
kubectl delete deployment -n <ns> <name>

# Delete with data
kubectl delete deployment -n <ns> <name>
kubectl delete pvc -n <ns> <pvc-name>

# Update
kubectl set image deployment/<name> -n <ns> <container>=<new-image>

# Recreate
kubectl delete deployment -n <ns> <name>
kubectl delete pvc -n <ns> <pvc-name>
kubectl apply -k kubernetes/apps/base/<ns>/<service>/
```

### Complex Service (Multiple Components)

```bash
# Use labels to target all components
NAMESPACE=management
SERVICE=paperless

# Disable all
kubectl scale deployment -n $NAMESPACE -l app.kubernetes.io/part-of=$SERVICE --replicas=0
kubectl scale statefulset -n $NAMESPACE -l app.kubernetes.io/part-of=$SERVICE --replicas=0

# Delete all (keep data)
kubectl delete deployment,statefulset,svc -n $NAMESPACE -l app.kubernetes.io/part-of=$SERVICE

# Delete with data
kubectl delete deployment,statefulset,svc,pvc -n $NAMESPACE -l app.kubernetes.io/part-of=$SERVICE

# Recreate
kubectl delete -k kubernetes/apps/base/$NAMESPACE/$SERVICE/ --ignore-not-found
kubectl delete pvc -n $NAMESPACE -l app.kubernetes.io/part-of=$SERVICE --ignore-not-found
sleep 10
sops -d kubernetes/apps/base/$NAMESPACE/$SERVICE/secret.enc.yaml | kubectl apply -f -
kubectl apply -k kubernetes/apps/base/$NAMESPACE/$SERVICE/
```

## Troubleshooting

### PVC Stuck in Terminating

```bash
# Check if pods are still using the PVC
kubectl get pods -n <namespace> -o json | jq '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == "<pvc-name>") | .metadata.name'

# Force delete (use with caution)
kubectl delete pvc -n <namespace> <pvc-name> --grace-period=0 --force

# If still stuck, remove finalizer
kubectl patch pvc -n <namespace> <pvc-name> -p '{"metadata":{"finalizers":null}}'
```

### Pod Stuck in Terminating

```bash
# Force delete pod
kubectl delete pod -n <namespace> <pod-name> --grace-period=0 --force
```

### Longhorn Volume Not Deleted

```bash
# Check Longhorn UI at http://10.10.2.12
# Or use kubectl
kubectl get volumes.longhorn.io -A | grep <pvc-name>

# Delete Longhorn volume directly
kubectl delete volumes.longhorn.io -n longhorn-system <volume-name>
```

### Service IP Not Assigned

```bash
# Check Cilium LB-IPAM
kubectl get svc -n <namespace> <service-name> -o yaml | grep -A5 annotations

# Re-annotate to trigger assignment
kubectl annotate svc -n <namespace> <service-name> io.cilium/lb-ipam-ips=<ip> --overwrite

# Restart Cilium if needed
kubectl rollout restart ds/cilium -n kube-system
```

## Quick Reference

| Operation | Command |
|-----------|---------|
| Disable | `kubectl scale deployment -n NS NAME --replicas=0` |
| Enable | `kubectl scale deployment -n NS NAME --replicas=1` |
| Delete (keep data) | `kubectl delete -k kubernetes/apps/base/NS/SVC/` |
| Delete with data | Above + `kubectl delete pvc -n NS -l app.kubernetes.io/part-of=SVC` |
| Update image | `kubectl set image deployment/NAME -n NS CONTAINER=IMAGE` |
| Restart | `kubectl rollout restart deployment -n NS NAME` |
| Recreate | Delete + Apply kustomization |
| Watch pods | `kubectl get pods -n NS -l app.kubernetes.io/part-of=SVC -w` |
| Check logs | `kubectl logs -n NS -l app.kubernetes.io/name=NAME --tail=50` |
