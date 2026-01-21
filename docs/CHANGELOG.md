# Changelog

All notable changes to this project are documented here.

## 2026

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
