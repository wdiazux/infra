# Security Strategy

This document explains the security posture and architectural decisions for the homelab infrastructure.

---

## Philosophy

This is a **single-node, single-user homelab** with a practical security approach:

**Core Principle**: Balance security hardening with homelab usability.

- ✅ **Implement**: Defense-in-depth layers that prevent common attacks
- ✅ **Implement**: Secrets encryption, network isolation for sensitive data
- ⚠️ **Skip**: Enterprise multi-tenancy controls, extensive RBAC
- ⚠️ **Skip**: Compliance frameworks (SOC2, HIPAA, PCI-DSS)

**Threat Model**:
- Primary concern: Compromised container lateral movement
- Secondary concern: Accidental data exposure
- Out of scope: Advanced persistent threats (APTs), nation-state actors

---

## Security Layers

### Layer 1: Secrets Management ✅ IMPLEMENTED

| Component | Status | Description |
|-----------|--------|-------------|
| **SOPS + Age** | ✅ Active | All secrets encrypted at rest with Age keys |
| **Age Key Storage** | ✅ Active | Private key stored outside cluster (`~/.config/sops/age/`) |
| **Git Encryption** | ✅ Active | Secrets never committed in plaintext |
| **FluxCD Integration** | ✅ Active | Automatic decryption during deployment |

**Configuration**: `secrets/*.enc.yaml`

**Decisions**:
- ✅ Age over GPG (simpler, modern)
- ⚠️ Single Age key (acceptable for single-user homelab)
- ⚠️ Terraform state contains decoded secrets (local only, not committed)

**See**: `docs/operations/secrets.md`

---

### Layer 2: Network Isolation ✅ IMPLEMENTED

**Status**: NetworkPolicies deployed (as of 2026-01-22)

**Implementation**: `kubernetes/infrastructure/security/network-policies.yaml`

#### Protected Namespaces

| Namespace | Sensitivity | Policy |
|-----------|-------------|--------|
| **ai** | Medium | Default-deny egress, allow DNS + required connections |
| **media** | High | Isolated Immich (photos), Emby, Navidrome |
| **management** | High | Isolated Paperless (documents), Wallos (bills) |
| **backup** | Critical | Velero + MinIO isolated from apps |
| **forgejo** | High | Git server isolated, runner has internet access |
| **automation** | Medium | Home Assistant + n8n need broad access (devices, APIs) |

#### Policy Design Principles

1. **Default-Deny Egress**: All namespaces start with egress blocked (except DNS)
2. **Explicit Allow**: Required communication paths explicitly allowed
3. **Broad Allow for Automation**: Home Assistant and n8n need external API access
4. **CI/CD Exception**: Forgejo runner needs internet for builds

**Example** (AI namespace):
```yaml
# Default: Block all egress except DNS
- Ollama can be accessed by Open WebUI
- Ollama can download models (HTTPS)
- ComfyUI can be accessed externally (LoadBalancer)
- No lateral movement to other namespaces
```

**Verification**:
```bash
# Test NetworkPolicy enforcement
kubectl get networkpolicies -A
kubectl describe networkpolicy -n media media-default-deny-egress

# Check Cilium policy enforcement
kubectl -n kube-system exec ds/cilium -- cilium policy get
```

**Decision**: NetworkPolicies added after initial review (2026-01-22). Previously, trusted environment model was used.

---

### Layer 3: Container Security ⚠️ SELECTIVE

#### Security Contexts ✅ MOSTLY IMPLEMENTED

**Status**: 40/43 deployments have securityContext defined (93%)

| Configuration | Usage | Rationale |
|---------------|-------|-----------|
| `runAsNonRoot: true` | 95% of apps | Prevent root exploits |
| `fsGroup: 1000` | Apps with PVCs | Consistent file permissions |
| `readOnlyRootFilesystem` | Not used | Breaks many apps (tmp writes) |
| `capabilities: drop: [ALL]` | Not used | Overly restrictive for homelab |

#### Privileged Containers ✅ JUSTIFIED

**Policy**: Only use `privileged: true` when **technically required**, not for convenience.

| Service | Namespace | Privileged | Justification |
|---------|-----------|------------|---------------|
| **Forgejo Runner** | forgejo | Yes | Docker-in-Docker (DinD) requires privileged mode for CI builds |
| **Home Assistant** | automation | Yes | Device discovery (mDNS/UPnP) + hardware integrations (USB devices) |
| **Velero** | backup | Yes | Backup controller needs host filesystem access |

**Documentation**:
- Forgejo Runner: `docs/services/forgejo-runner.md:115-116`
- Home Assistant: `docs/services/home-assistant.md:49-55`

**Alternative Considered**: Using specific capabilities instead of privileged.
- **Decision**: Rejected - these services need multiple capabilities + host access
- **Risk Mitigation**: Services run in dedicated namespaces with NetworkPolicies

---

### Layer 4: Pod Security Standards ⚠️ NOT IMPLEMENTED

**Status**: Namespace labels for Pod Security Standards not added

**Rationale**: Kubernetes 1.35 supports Pod Security Admission, but:
- `privileged` mode required for 3 critical services (see Layer 3)
- Would require per-namespace exceptions
- Homelab doesn't benefit from admission warnings

**Future**: May add `audit` and `warn` labels without `enforce` for visibility

**Example** (if implemented):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ai
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

---

### Layer 5: Image Security ✅ IMPLEMENTED

| Control | Status | Implementation |
|---------|--------|----------------|
| **Image Pinning** | ✅ Active | Semantic versions for critical services |
| **Immich Version Lock** | ✅ Active | All components same version (prevents migration issues) |
| **`:latest` Policy** | ✅ Documented | Allowed for stable services with exceptions documented |
| **Image Scanning** | ⚠️ Not Implemented | Trivy available but not automated |

**Policy**: Use `:latest` for most services, pin versions for:
- Services with frequent breaking changes (Immich)
- Database images (PostgreSQL, Redis)
- Critical infrastructure (Velero, Cilium)

**See**: `docs/reference/resource-strategy.md#image-versioning-policy`

---

### Layer 6: RBAC (Role-Based Access Control) ⚠️ MINIMAL

**Status**: Default service accounts used, custom RBAC only where required

**Justified Custom RBAC**:
| Service | Namespace | Permissions | Reason |
|---------|-----------|-------------|--------|
| **Forgejo Runner** | forgejo | read pods, secrets | CI pipeline execution |
| **vmagent** | monitoring | read nodes, pods, services | Metrics collection |
| **kube-state-metrics** | monitoring | read all resources | Cluster state metrics |

**Decision**: Single-user homelab doesn't benefit from extensive RBAC.
- ✅ Keep default RBAC for service accounts
- ✅ Add custom RBAC only when service explicitly requires it
- ⚠️ No user-level RBAC (single admin via kubeconfig)

---

## Access Control

### Cluster Access

| Method | User | Authentication | Authorization |
|--------|------|----------------|---------------|
| **kubectl** | wdiaz | Client certificate (kubeconfig) | cluster-admin |
| **talosctl** | wdiaz | Client certificate (talosconfig) | Full Talos API |
| **Kubernetes API** | ServiceAccounts | JWT tokens | Namespace-scoped |

**Kubeconfig Location**: `terraform/talos/kubeconfig`
**Talosconfig Location**: `terraform/talos/talosconfig`

**Decision**: Single admin user is appropriate for homelab.

---

### Service Access

| Service | Exposure | Authentication | Notes |
|---------|----------|----------------|-------|
| **Cilium LoadBalancer** | Local network (10.10.2.0/24) | App-level | Services use internal IPs |
| **Forgejo** | Local network | Built-in auth | User accounts in Forgejo |
| **Immich** | Local network | Built-in auth | Photo access controlled |
| **Grafana** | Local network | Built-in auth | Monitoring dashboards |
| **MinIO Console** | Local network | Credentials in SOPS | Backup management |
| **Hubble UI** | Local network | No auth | Network observability (trusted network) |
| **Longhorn UI** | Local network | No auth | Storage management (trusted network) |

**Network Trust Boundary**: All services assume 10.10.2.0/24 network is trusted.

**Decision**: No public internet exposure, all services internal-only.

---

## Backup Security

### Backup Data Protection

| Backup Type | Location | Encryption | Access Control |
|-------------|----------|------------|----------------|
| **Velero (Kubernetes)** | MinIO → NAS (NFS) | Not encrypted | NFS permissions |
| **Longhorn (Volumes)** | NAS (NFS) | Not encrypted | NFS permissions |
| **SOPS Secrets** | Git (Forgejo) | Age-encrypted | Age key required |
| **Terraform State** | Local | Not encrypted | Filesystem permissions |

**Data-at-Rest**: Backups on NAS are not encrypted.
- **Rationale**: NAS is physically secured, encryption would complicate recovery
- **Risk**: If NAS is compromised, backup data is accessible
- **Mitigation**: NAS on isolated network, strong credentials

**See**: `docs/operations/backups.md`

---

## Threat Scenarios & Mitigations

### Scenario 1: Compromised Application Container

**Example**: Attacker exploits vulnerability in Radarr (arr-stack namespace)

**Attack Path**:
1. ✅ **BLOCKED**: Lateral movement to other namespaces (NetworkPolicies)
2. ✅ **BLOCKED**: Access to secrets (SOPS encryption, namespace isolation)
3. ⚠️ **POSSIBLE**: Access to media files (NFS volumes mounted in same namespace)
4. ⚠️ **POSSIBLE**: Egress to internet (arr-stack apps need downloads)

**Mitigation**:
- NetworkPolicy blocks lateral movement
- NFS volumes are read-only where possible
- Monitor for unusual egress patterns (Hubble)

---

### Scenario 2: Forgejo Runner Executes Malicious Workflow

**Example**: Attacker with Forgejo access creates malicious Actions workflow

**Attack Path**:
1. ⚠️ **POSSIBLE**: Privileged container execution (DinD requirement)
2. ✅ **MITIGATED**: Limited to forgejo namespace (NetworkPolicy)
3. ⚠️ **POSSIBLE**: Internet access for package downloads
4. ✅ **BLOCKED**: Cannot access other namespaces

**Mitigation**:
- Forgejo access requires authentication
- Runner isolated to forgejo namespace
- Workflow logs auditable
- Consider: Disable Actions if not actively used

---

### Scenario 3: GPU Workload Exploitation

**Example**: Attacker exploits Ollama or ComfyUI to execute code

**Attack Path**:
1. ⚠️ **POSSIBLE**: GPU access (nvidia runtime required)
2. ✅ **BLOCKED**: Lateral movement (NetworkPolicy)
3. ⚠️ **POSSIBLE**: Model download (HTTPS egress required)
4. ✅ **BLOCKED**: Access to sensitive namespaces (media, management, backup)

**Mitigation**:
- AI namespace isolated via NetworkPolicy
- GPU time-slicing limits blast radius
- No privileged mode (unlike Forgejo runner)

---

### Scenario 4: Secrets Exposure via Terraform State

**Example**: Terraform state file leaked/committed

**Attack Path**:
1. ⚠️ **POSSIBLE**: Proxmox API token exposed
2. ⚠️ **POSSIBLE**: Git credentials exposed
3. ⚠️ **POSSIBLE**: PostgreSQL passwords exposed
4. ✅ **BLOCKED**: Age key not in state (separate file)

**Mitigation**:
- `.gitignore` prevents state file commit
- State stored locally only (no remote backend)
- Age key stored separately (`~/.config/sops/age/keys.txt`)

**Accepted Risk**: Terraform state contains secrets for homelab convenience.

**For production**: Use Terraform Cloud or S3 backend with encryption.

**See**: `CLAUDE.md` - "Skip: remote state" (line 31)

---

## Security Monitoring

### Available Tools

| Tool | Purpose | Location |
|------|---------|----------|
| **Hubble** | Network flow visualization | http://10.10.2.11 |
| **Grafana** | Metrics dashboards | http://10.10.2.23 |
| **VictoriaMetrics** | Metrics storage | http://10.10.2.24 |
| **vmagent** | Metrics collection | Internal |
| **kubectl logs** | Container logs | CLI |

### Monitoring Gaps

| Gap | Impact | Mitigation |
|-----|--------|------------|
| **No centralized logging** | Hard to correlate events | Use `kubectl logs` + Grafana for pod logs |
| **No intrusion detection** | Cannot detect anomalies | Rely on Hubble for network anomalies |
| **No image scanning** | Unknown vulnerabilities | Manual Trivy scans |
| **No audit logs** | Limited forensics | Enable Kubernetes audit logs if needed |

**Decision**: Enterprise monitoring not needed for homelab.

---

## Compliance & Standards

### Not Applicable

This homelab **does not target** these frameworks:
- ❌ PCI-DSS (payment card data)
- ❌ HIPAA (health information)
- ❌ SOC2 (service organization controls)
- ❌ GDPR (European data protection)
- ❌ NIST Cybersecurity Framework
- ❌ CIS Kubernetes Benchmark

**Rationale**: Single-user homelab with no regulated data.

### Informally Followed

| Practice | Adoption | Notes |
|----------|----------|-------|
| **Least Privilege** | Partial | Service accounts minimal, user is admin |
| **Defense in Depth** | Yes | Multiple security layers (secrets, network, container) |
| **Encryption at Rest** | Partial | Secrets encrypted, backups not encrypted |
| **Encryption in Transit** | No | Internal cluster traffic not mTLS |
| **Security Patching** | Manual | FluxCD auto-updates most images |
| **Backup & Recovery** | Yes | Automated Velero + Longhorn backups |

---

## Security Checklist for New Services

When deploying a new service, consider:

- [ ] **Secrets**: Use SOPS-encrypted secrets (not plaintext ConfigMaps)
- [ ] **Namespace**: Place in appropriate namespace (ai, media, management, etc.)
- [ ] **NetworkPolicy**: Add to `network-policies.yaml` if handling sensitive data
- [ ] **SecurityContext**: Set `runAsNonRoot: true`, `fsGroup` if using PVCs
- [ ] **Privileged**: Avoid unless technically required (document justification)
- [ ] **Image Tag**: Pin version for databases and critical services
- [ ] **Resource Limits**: Add memory limits (see `docs/reference/resource-strategy.md`)
- [ ] **Probes**: Add liveness/readiness probes
- [ ] **Backup**: Include in Velero schedule if stateful

---

## Incident Response

### If Container is Compromised

1. **Isolate**: `kubectl delete pod <pod-name>` (restart with clean image)
2. **Investigate**: Check logs (`kubectl logs <pod-name>`)
3. **Audit**: Review Hubble flows for unusual network activity
4. **Patch**: Update image to patched version
5. **Rotate**: Rotate secrets if compromised

### If Credentials are Exposed

1. **Revoke**: Immediately revoke exposed credentials (Proxmox, Git, etc.)
2. **Rotate**: Generate new credentials, update SOPS secrets
3. **Redeploy**: `flux reconcile kustomization apps --with-source`
4. **Audit**: Check access logs for unauthorized usage

### If Age Key is Lost

1. **Prevention**: Age key backed up in password manager (best practice)
2. **Recovery**: If lost, all SOPS secrets are **unrecoverable**
3. **Mitigation**: Generate new Age key, re-encrypt all secrets, redeploy

---

## Future Enhancements (Optional)

Potential security improvements (not currently implemented):

| Enhancement | Benefit | Complexity |
|-------------|---------|------------|
| **Centralized Logging** | Better forensics | Medium |
| **Image Scanning (Trivy automation)** | Detect vulnerabilities | Low |
| **Kubernetes Audit Logs** | Forensics, compliance | Low |
| **mTLS (Cilium Service Mesh)** | Encrypted in-cluster traffic | High |
| **Pod Security Standards enforcement** | Admission control | Medium |
| **External Secrets Operator** | Secrets from Vault/1Password | Medium |
| **Remote Terraform State** | State encryption | Low |

**Decision**: Not implementing currently. Homelab security posture is adequate for threat model.

---

## References

- [CLAUDE.md](../../CLAUDE.md) - Homelab philosophy: "Skip: resource limits, multiple environments, PR reviews"
- [Resource Strategy](./resource-strategy.md) - Memory limits, CPU policy, image versioning
- [Secrets Management](../operations/secrets.md) - SOPS + Age encryption
- [Backups](../operations/backups.md) - Velero, Longhorn backup procedures
- [Network Policies](../../kubernetes/infrastructure/security/network-policies.yaml) - NetworkPolicy definitions
- [Forgejo Runner](../services/forgejo-runner.md) - Privileged mode justification
- [Home Assistant](../services/home-assistant.md) - Privileged mode justification

---

**Last Updated**: 2026-01-22
**Status**: Active - NetworkPolicies deployed, security posture documented
