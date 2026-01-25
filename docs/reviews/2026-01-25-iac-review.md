# Comprehensive IaC Review - 2026-01-25

## Summary

| Technology | Critical | Warning | Info | Status |
|------------|----------|---------|------|--------|
| Terraform | 0 | 3 | 8 | Production-Ready |
| Kubernetes | 1 | 7 | 10 | Production-Ready |
| FluxCD | 0 | 2 | 5 | Production-Ready |
| Ansible | 0 | 7 | 8 | Production-Ready |
| Packer | 2 | 8 | 9 | Production-Ready* |

**Overall Status**: Production-Ready for homelab use

**Total Findings**: Critical: 3, Warning: 27, Info: 40

**Review Scope**:
- 32 Terraform files
- 100+ Kubernetes manifests
- 81 FluxCD resources
- 15 Ansible playbooks/roles
- 10 Packer template files

---

## Critical Findings

### [PKR-001] Hardcoded API Token in .auto.pkrvars.hcl Files
- **Severity**: Critical (but mitigated)
- **Files**: All `packer/*/*.auto.pkrvars.hcl` files
- **Issue**: Proxmox API token stored in plaintext
- **Mitigation**: Files are in `.gitignore` - not committed
- **Fix**: Use environment variables (`PKR_VAR_proxmox_token`)

### [PKR-002] Weak Default WinRM Password
- **Severity**: Critical
- **File**: `packer/windows/variables.pkr.hcl:143`
- **Issue**: `default = "P@ssw0rd!"` - commonly known password
- **Fix**: Remove default, require via environment variable

### [K8S-001] Init Container Using Outdated Image Tag
- **Severity**: Critical
- **File**: `kubernetes/apps/base/automation/home-assistant/deployment.yaml:42`
- **Issue**: `busybox:1.36` vs project standard `busybox:1.37`
- **Fix**: Update to `busybox:1.37.0`

---

## High Priority Warnings

### Terraform (TF)

| ID | Issue | File | Recommended Action |
|----|-------|------|-------------------|
| TF-001 | Deprecated `load_balancer_ip` | `terraform/talos/weave-gitops.tf:101` | Migrate to Cilium `io.cilium/lb-ipam-ips` annotation |
| TF-002 | Sensitive variable defaults | `terraform/talos/variables-services.tf` | Add validation rules |
| TF-003 | Module version too loose | `terraform/modules/proxmox-vm/terraform.tf` | Change `>= 0.92.0` to `~> 0.92` |

### Kubernetes (K8S)

| ID | Issue | Files | Recommended Action |
|----|-------|-------|-------------------|
| K8S-002 | Missing container security context | 25+ deployments | Add `allowPrivilegeEscalation: false` and `capabilities.drop: ALL` |
| K8S-003 | Rolling tags without policy | copyparty, it-tools, attic, obico | Document exceptions or use SHA-based tags |
| K8S-004 | Missing health probes | `misc/twitch-miner/deployment.yaml` | Add basic liveness probe |

### FluxCD (FLUX)

| ID | Issue | Files | Recommended Action |
|----|-------|-------|-------------------|
| FLUX-001 | Missing `wait: true` | 5 infrastructure Kustomizations | Add `wait: true` for proper sequencing |
| FLUX-002 | Missing health checks | infrastructure-storage | Add Longhorn deployment health check |

### Ansible (ANS)

| ID | Issue | Files | Recommended Action |
|----|-------|-------|-------------------|
| ANS-001 | Shell module without idempotency | `packer_provisioning/tasks/debian_packages.yml` | Add creates/removes |
| ANS-002 | Duplicated CrowdSec tasks | day1_debian_baseline.yml, day1_arch_baseline.yml | Extract to shared role |
| ANS-004 | Hardcoded cloud-init passwords | `playbooks/day0_import_cloud_images.yml` | Use variables |

### Packer (PKR)

| ID | Issue | Files | Recommended Action |
|----|-------|-------|-------------------|
| PKR-003 | Weak SSH passwords | ubuntu, debian, arch templates | Use stronger defaults or variables |
| PKR-004 | Hardcoded DNS server | All Linux templates | Extract to variable |
| PKR-005 | Missing validations | Windows template | Add validation blocks |

---

## Positive Observations

### Security
- SOPS encryption for all secrets
- Comprehensive NetworkPolicies + CiliumNetworkPolicies
- Privileged containers documented and justified
- Pre-destroy cleanup with `terraform_data`

### Architecture
- Modern HCL2 Packer syntax
- Gateway API instead of deprecated Ingress
- FluxCD image automation properly configured
- Consistent labeling conventions

### Best Practices
- All providers use pessimistic version constraints
- Variable validations throughout Terraform
- FQCN used in all Ansible modules
- Manifest post-processors for Packer builds

### Homelab-Appropriate
- Local Terraform state (acceptable)
- Skip resource limits (acceptable)
- Memory ballooning configured
- Single-node optimizations applied

---

## Action Items by Priority

### High (Address Soon)
1. [ ] Update Home Assistant init container to `busybox:1.37.0`
2. [ ] Migrate `load_balancer_ip` to Cilium annotations in weave-gitops.tf
3. [ ] Remove default password from Windows Packer template

### Medium (Next Review Cycle)
4. [ ] Add container security contexts to deployments
5. [ ] Add `wait: true` to FluxCD infrastructure Kustomizations
6. [ ] Extract CrowdSec tasks to shared Ansible role
7. [ ] Add health checks to infrastructure-storage Kustomization
8. [ ] Tighten module version constraint to `~> 0.92`

### Low (When Convenient)
9. [ ] Remove emojis from Ansible debug messages
10. [ ] Add missing tags to Ansible tasks
11. [ ] Add validations to Windows Packer template
12. [ ] Document image tag exceptions consistently

---

## Detected Versions

### Terraform Providers
| Provider | Version | Constraint |
|----------|---------|------------|
| bpg/proxmox | 0.93.0 | ~> 0.93.0 |
| siderolabs/talos | 0.10.0 | ~> 0.10.0 |
| hashicorp/helm | 3.1.1 | ~> 3.1.0 |
| hashicorp/kubernetes | 2.36.0 | ~> 2.36.0 |
| carlpett/sops | 1.1.1 | ~> 1.1.1 |

### Kubernetes
- Version: v1.35.0
- CNI: Cilium (eBPF)
- Storage: Longhorn + NFS CSI

### FluxCD
- HelmRelease: v2
- Kustomization: v1
- Image Automation: v1

### Packer
- Packer: ~> 1.14.3
- Proxmox plugin: >= 1.2.3

---

## Next Review

**Recommended**: 2026-04-25 (quarterly)

**Focus Areas**:
- Review any new deprecation warnings
- Verify container security contexts added
- Check for provider updates
- Review backup verification procedures

---

*Generated by Claude Code comprehensive IaC review*
