---
name: update-service
description: Update an existing service in the Kubernetes cluster
---

Update existing service: $ARGUMENTS

## Workflow

1. **Identify service location**
   ```bash
   find kubernetes/apps -name "*$ARGUMENTS*" -type d 2>/dev/null
   ```

   If not found, search by namespace:
   ```bash
   ls -la kubernetes/apps/base/*/
   ```

2. **Show current configuration**
   Read the deployment.yaml and service.yaml for the service.
   Show current:
   - Image and tag
   - Environment variables
   - Resource configuration
   - Service type and IP

3. **Ask what changes are needed**
   Common updates:
   - Image version update
   - Environment variable change
   - Configuration change
   - Resource adjustment
   - Add/remove volumes

4. **Make changes**
   Edit the appropriate manifest files.

5. **Commit changes**
   ```bash
   git add kubernetes/apps/base/{namespace}/{service}/
   git commit -m "fix({namespace}): Update {service} - {change description}"
   ```

6. **Trigger Flux reconciliation**
   ```bash
   flux reconcile kustomization flux-system --with-source
   ```

7. **Watch rollout**
   ```bash
   kubectl rollout status deployment/{service} -n {namespace} --timeout=120s
   ```

8. **Verify service health**
   ```bash
   kubectl get pods -n {namespace} -l app={service}
   kubectl logs -n {namespace} -l app={service} --tail=20
   ```

9. **Document rollback** (if needed)
   ```bash
   # To rollback:
   kubectl rollout undo deployment/{service} -n {namespace}
   # Or revert git commit and reconcile
   ```

## Output

After update:
- Confirm what was changed
- Show new pod status
- Provide rollback command if something goes wrong
