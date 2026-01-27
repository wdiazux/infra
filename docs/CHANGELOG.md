# Changelog

All notable changes to this project are documented here.

## 2026

### 2026-01-27
- Paperless OIDC fixes
  - Fixed CSRF 403 on login (`PAPERLESS_URL` was `http://` instead of `https://`)
  - Fixed env var ordering for Kubernetes `$(VAR)` substitution (OIDC credentials must be defined before `PAPERLESS_SOCIALACCOUNT_PROVIDERS`)
  - Enabled social auto signup and email authentication for account linking
  - Added `PAPERLESS_ADMIN_MAIL` to SOPS secrets (prevents email mismatch on fresh deploy)
- Immich OIDC fixes
  - Changed Zitadel OIDC app auth method from BASIC to POST (`client_secret_post`)
  - Changed `storageLabelClaim` from `preferred_username` to `email`
  - Cleared stale `oauthId` in database to allow re-linking by email
- OIDC sync job fixes
  - Fixed sync job recreating ALL apps every 15 minutes (Zitadel API does not return `authMethodType` in responses, causing constant mismatch detection)
  - Replaced compare-and-recreate logic with always-update-via-PUT (idempotent, no credential rotation)
- Forgejo OIDC fixes
  - Changed all Zitadel OIDC apps from PKCE to Client Secret (BASIC) auth method
  - Fixed Forgejo Helm chart `existingSecret` usage (removed literal `key` field)
  - Fixed redirect URI case mismatch (`Zitadel` vs `zitadel` in callback path)
  - Added `SAME_SITE=lax` to Forgejo session config for cross-site OAuth2 redirects
  - Added `USERNAME=email` to extract username from email claim

### 2026-01-26
- Terraform code organization and cleanup
  - Extracted 14 inline shell scripts (~600 lines) to `terraform/talos/scripts/` directory
  - Dynamic Talos image factory schematic generation (replaces hardcoded schematic ID)
  - Replaced shell-based Kubernetes polling with `talos_cluster_health` data source
  - Removed Zitadel Terraform provider (OIDC managed via Kubernetes CronJob)
  - Updated `docs/reference/terraform.md` with new architecture
- Kubernetes YAML cleanup
  - Extracted Forgejo runner registration script to ConfigMap
  - Extracted Home Assistant proxy config script to ConfigMap
  - Removed unused `HOST_WHITELIST` env var from SABnzbd
- Zitadel OIDC/SSO review
  - Removed outdated Terraform alternative section from SSO docs
  - Updated forward auth header (now active, not disabled)
  - Fixed stale `enable_zitadel_oidc` reference in oauth2-proxy helmrelease
- Documentation updates
  - Updated `docs/reference/network.md` to reflect Gateway API migration (ClusterIP services)
  - Updated CLAUDE.md with current provider versions and recent changes
  - Verified first-deployment dependency chain

### 2026-01-25
- Migrated web UIs from LoadBalancer to ClusterIP (all via Gateway API at 10.10.2.20)
- Consolidated domains to home-infra.net and reynoza.org
- Auto-generated Forgejo runner tokens (replaces manual registration)
- CiliumNetworkPolicies for Kubernetes API access control

### 2026-01-24
- Zitadel SSO implementation (replaces Logto)
- OIDC setup via Kubernetes CronJob with self-healing (every 15 minutes)
- CoreDNS rewrite for hairpin DNS resolution (auth.home-infra.net)
- oauth2-proxy for forward auth (Cilium Envoy ext_authz)

### 2026-01-22
- Kubernetes resource review and memory limits implementation
  - Added researched memory limits to 21 deployments (no CPU to allow burst on single-node)
  - Heavy apps (4Gi): home-assistant, n8n, paperless-server
  - Medium apps (1-2Gi): radarr, sonarr, sabnzbd, qbittorrent, open-webui, affine, immich, tika
  - Light apps (128Mi-1Gi): navidrome, bazarr, prowlarr, attic, gotenberg, it-tools, homepage
  - Redis instances (256Mi): affine, immich, paperless, obico
  - Added securityContext (fsGroup) to immich-redis, immich-ml, obico-redis
  - Added app.kubernetes.io/part-of label to node-exporter daemonset
  - Generated kubernetes review report: `docs/reviews/2026-01-21-kubernetes-review.md`
  - Updated resource-strategy.md with new memory-only limits policy

### 2026-01-21
- Documentation audit and cleanup
  - Fixed wrong IPs in infrastructure.md (VictoriaMetrics, Grafana, n8n, Home Assistant, Open WebUI)
  - Updated VictoriaMetrics/VMAgent versions (v1.111.0 → v1.134.0) and Grafana (11.4.0 → 12.3.1) in monitoring.md
  - Replaced "Stable Diffusion" references with "ComfyUI" in resource-strategy.md
  - Simplified infrastructure.md by removing duplicate version info, linking to services.md instead
  - Updated Last Updated dates across reference documentation

### 2026-01-20
- Velero disaster recovery with MinIO backend (daily/weekly backup schedules)
- Automated snapshot-controller and MinIO bucket initialization
- PodGC configuration for terminated pod cleanup (threshold: 50)
- Kubelet graceful shutdown configuration (60s grace period)
- VMAgent relabeling fixes for duplicate scrape targets
- Packer semantic versioning for templates
- Forgejo Actions security scanning workflow (Trivy, tflint)
- ComfyUI updates (CUDA 12.8, Python 3.12)
- Obico 3D printer monitoring with CUDA 12.3
- Ollama LoadBalancer exposure at 10.10.2.20
- Codebase audit and cleanup (removed Faster-Whisper and librespeed references from planning docs)
- Pre-commit hooks updated to latest versions

### 2026-01-19
- Claude Code optimization: Added custom commands, hooks, and sub-agents in `.claude/`

### 2026-01-17
- Paperless-ngx document management at 10.10.2.36 with PostgreSQL, Redis, Tika, Gotenberg
- Attic Nix binary cache at 10.10.2.29 with PostgreSQL 16 and NFS storage
- Monitoring stack (VictoriaMetrics at 10.10.2.24, Grafana at 10.10.2.23)
- Immich photo backup at 10.10.2.22 with GPU ML
- Home Assistant smart home platform at 10.10.2.25 in automation namespace
- n8n workflow automation with PostgreSQL in automation namespace (10.10.2.26)
- Homelab resource strategy optimization

### 2026-01-16
- AI namespace with GPU time-slicing (Ollama, Open WebUI, Faster-Whisper, Stable Diffusion)
- IP reorganization (Emby→10.10.2.30, Navidrome→10.10.2.31)
- Refactored kubernetes apps structure - organized by namespace (tools/, misc/, arr-stack/, media/)
- Media namespace for streaming services (Emby, Navidrome)
- Duplicate NFS PV pattern for cross-namespace storage
- Arr-stack media automation deployment (SABnzbd, qBittorrent, Prowlarr, Radarr, Sonarr, Bazarr)
- Dual NFS storage (media + downloads), kubeconfig documentation

### 2026-01-15
- Documentation consolidation - reorganized 54 files into structured `docs/` hierarchy

### 2026-01-14
- Service LoadBalancer IPs assigned (Hubble UI, Longhorn, Forgejo, FluxCD webhook)
- Documentation cleanup (removed archive docs)

### 2026-01-11
- Talos switched from Packer to direct disk image import (recommended by Sidero Labs)

### 2026-01-10
- Talos v1.12.1 upgrade
- GPU passthrough config (PCI 07:00)
- Hardware documentation
- Documentation sync guidelines added

### 2026-01-06
- Talos configuration review (timezone, Cilium L2 interface fix)
- Documentation cleanup (removed orphaned roles/baseline, NixOS Ansible playbook)

### 2026-01-05
- NixOS cloud image implementation (using Hydra VMA, declarative config - no Ansible)
- Arch Linux cloud image implementation (converted from ISO to official cloud image)

### 2026-01-04
- Nix + npins dependency management implementation (shell.nix, direnv)

## 2025

### 2025-12-15
- Infrastructure dependencies audit and update (Terraform 1.14.2, Packer 1.14.3)

### 2025-11-23
- Session recovery and comprehensive infrastructure review
- Network configuration update (NAS IP 10.10.2.5, IP allocation table)
- Kubernetes secrets management research (SOPS + FluxCD chosen)

### 2025-11-22
- Longhorn storage manager implementation (single-replica mode)

### 2025-11-18
- Talos as primary platform
- ZFS storage, CI/CD implementation
- Initial CLAUDE.md creation
