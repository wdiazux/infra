---
name: k8s-status
description: Check Kubernetes cluster health and status
---

Check Kubernetes cluster status. KUBECONFIG is already set to terraform/talos/kubeconfig.

Run these commands and provide a summary:

1. **Node Status**
   ```bash
   kubectl get nodes -o wide
   ```

2. **Node Resources** (if metrics available)
   ```bash
   kubectl top nodes 2>/dev/null || echo "Metrics server not available"
   ```

3. **Problematic Pods** (not Running or Completed)
   ```bash
   kubectl get pods -A | grep -v -E 'Running|Completed' | head -20
   ```

4. **Recent Warning Events**
   ```bash
   kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp 2>/dev/null | head -15
   ```

5. **Flux Status**
   ```bash
   flux get all -A 2>/dev/null | grep -v "True" | head -20
   ```

6. **Storage Status**
   ```bash
   kubectl get pvc -A | grep -v Bound | head -10
   ```

After running all commands, provide a **Health Summary**:
- Overall cluster status (Healthy/Degraded/Critical)
- Any pods requiring attention
- Any Flux reconciliation issues
- Any storage issues
- Recommended actions (if any)
