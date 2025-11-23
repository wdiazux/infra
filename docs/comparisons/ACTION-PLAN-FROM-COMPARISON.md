# Action Plan: Infrastructure Enhancements

**Based On**: INFRASTRUCTURE-COMPARISON-REPORT.md
**Date**: 2025-11-23
**Priority**: High-value improvements from community best practices

---

## Executive Summary

Based on analysis of 10 leading homelab projects, this action plan prioritizes **3 high-impact enhancements** that will bring this infrastructure into the **top 10%** of open-source homelab implementations.

**Current Status**: ⭐⭐⭐⭐⭐ (5/5) - Production-ready with unique advantages
**Target Status**: ⭐⭐⭐⭐⭐+ (Top 10%) - Industry-leading with full GitOps

---

## Phase 1: FluxCD Bootstrap (Week 1)

**Objective**: Enable GitOps for automated Kubernetes deployments
**Effort**: 2-4 hours
**Impact**: HIGH
**Reference**: onedr0p/cluster-template

### Prerequisites

```bash
# Install flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify flux version
flux --version
```

### Step 1: Bootstrap FluxCD

```bash
# Export GitHub token
export GITHUB_TOKEN=<your-token>

# Bootstrap flux with GitHub
flux bootstrap github \
  --owner=wdiazux \
  --repository=infra \
  --branch=main \
  --path=clusters/homelab \
  --personal \
  --private=false
```

**Expected Output**:
- Creates `clusters/homelab/flux-system/` directory
- Deploys Flux controllers to cluster
- Configures automated reconciliation

### Step 2: Create Flux Directory Structure

```bash
# Create base directory structure
mkdir -p kubernetes/flux-system
mkdir -p kubernetes/apps/{base,homelab}
mkdir -p kubernetes/infrastructure/{base,homelab}
mkdir -p kubernetes/core/{base,homelab}

# Infrastructure layer (Cilium, Longhorn, storage)
mkdir -p kubernetes/infrastructure/base/{cilium,longhorn,storage-classes}

# Core layer (ingress, cert-manager, external-dns)
mkdir -p kubernetes/core/base/{ingress,cert-manager}

# Apps layer (actual applications)
mkdir -p kubernetes/apps/base/{media,monitoring,databases}
```

### Step 3: Create Helm Repositories

Create `kubernetes/infrastructure/base/sources.yaml`:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: longhorn
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.longhorn.io
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: cilium
  namespace: flux-system
spec:
  interval: 1h
  url: https://helm.cilium.io
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: prometheus-community
  namespace: flux-system
spec:
  interval: 1h
  url: https://prometheus-community.github.io/helm-charts
```

### Step 4: Create Longhorn HelmRelease

Create `kubernetes/infrastructure/base/longhorn/helmrelease.yaml`:

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: longhorn
  namespace: longhorn-system
spec:
  interval: 30m
  chart:
    spec:
      chart: longhorn
      version: "1.7.2"
      sourceRef:
        kind: HelmRepository
        name: longhorn
        namespace: flux-system
  install:
    crds: CreateReplace
  upgrade:
    crds: CreateReplace
  valuesFrom:
    - kind: ConfigMap
      name: longhorn-values
      valuesKey: values.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-values
  namespace: longhorn-system
data:
  values.yaml: |
    # Copy content from kubernetes/longhorn/longhorn-values.yaml
    defaultSettings:
      defaultReplicaCount: 1
      defaultDataPath: /var/lib/longhorn
    persistence:
      defaultClass: true
      defaultClassReplicaCount: 1
```

### Step 5: Create Infrastructure Kustomization

Create `kubernetes/infrastructure/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - sources.yaml
  - longhorn/helmrelease.yaml
  - cilium/helmrelease.yaml
  - storage-classes/longhorn-storage-classes.yaml
```

### Step 6: Create Cluster Kustomization

Create `clusters/homelab/infrastructure.yaml`:

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/infrastructure/homelab
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      name: longhorn
      namespace: longhorn-system
    - apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      name: cilium
      namespace: kube-system
```

### Step 7: Commit and Push

```bash
git add clusters/ kubernetes/
git commit -m "feat: Bootstrap FluxCD with Longhorn and Cilium"
git push origin main
```

### Verification

```bash
# Check Flux components
flux check

# Watch reconciliation
flux get kustomizations --watch

# Check HelmReleases
flux get helmreleases -A

# Verify Longhorn deployment
kubectl get pods -n longhorn-system
```

**Success Criteria**:
- ✅ Flux controllers running
- ✅ HelmReleases reconciled
- ✅ Longhorn pods running
- ✅ Automatic updates from Git

---

## Phase 2: Taskfile Automation (Week 1)

**Objective**: Simplify common workflows
**Effort**: 1-2 hours
**Impact**: MEDIUM
**Reference**: onedr0p/cluster-template

### Step 1: Install Taskfile

```bash
# Install task
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
```

### Step 2: Create Taskfile

Create `/home/user/infra/Taskfile.yaml`:

```yaml
version: '3'

vars:
  CLUSTER_NAME: homelab
  PROXMOX_NODE: pve

tasks:
  # === Packer Tasks ===
  packer:init:
    desc: Initialize all Packer templates
    cmds:
      - for: [talos, debian, ubuntu, arch, nixos, windows]
        cmd: cd packer/{{.ITEM}} && packer init .

  packer:validate:
    desc: Validate all Packer templates
    deps: [packer:init]
    cmds:
      - for: [talos, debian, ubuntu, arch, nixos, windows]
        cmd: cd packer/{{.ITEM}} && packer validate .

  packer:build:all:
    desc: Build all Packer templates
    deps: [packer:validate]
    cmds:
      - task: packer:build:talos
      - task: packer:build:debian
      - task: packer:build:ubuntu
      - task: packer:build:arch
      - task: packer:build:nixos
      - task: packer:build:windows

  packer:build:talos:
    desc: Build Talos template
    dir: packer/talos
    cmds:
      - packer init .
      - packer build .

  packer:build:debian:
    desc: Build Debian template
    dir: packer/debian
    cmds:
      - packer init .
      - packer build .

  # === Terraform Tasks ===
  terraform:init:
    desc: Initialize Terraform
    dir: terraform
    cmds:
      - terraform init

  terraform:validate:
    desc: Validate Terraform
    dir: terraform
    deps: [terraform:init]
    cmds:
      - terraform validate

  terraform:plan:
    desc: Plan Terraform changes
    dir: terraform
    deps: [terraform:init]
    cmds:
      - terraform plan

  terraform:apply:
    desc: Apply Terraform changes
    dir: terraform
    deps: [terraform:plan]
    cmds:
      - terraform apply
    interactive: true

  terraform:destroy:
    desc: Destroy Terraform resources
    dir: terraform
    cmds:
      - terraform destroy
    interactive: true

  # === Talos Tasks ===
  talos:factory:
    desc: Open Talos Factory in browser
    cmds:
      - echo "Opening https://factory.talos.dev/"
      - xdg-open https://factory.talos.dev/ || open https://factory.talos.dev/

  talos:gen-config:
    desc: Generate Talos machine config
    cmds:
      - |
        talosctl gen config {{.CLUSTER_NAME}} https://{{.NODE_IP}}:6443 \
          --config-patch @talos/patches/longhorn-requirements.yaml \
          --config-patch @talos/patches/cilium-requirements.yaml \
          --output-dir ./talos-config
    vars:
      NODE_IP:
        sh: echo ${NODE_IP:-192.168.1.100}

  talos:apply-config:
    desc: Apply Talos machine config
    cmds:
      - talosctl apply-config --nodes {{.NODE_IP}} --file talos-config/controlplane.yaml
    vars:
      NODE_IP:
        sh: echo ${NODE_IP:-192.168.1.100}

  talos:bootstrap:
    desc: Bootstrap Talos cluster
    cmds:
      - talosctl bootstrap -n {{.NODE_IP}}
    vars:
      NODE_IP:
        sh: echo ${NODE_IP:-192.168.1.100}

  talos:kubeconfig:
    desc: Fetch Talos kubeconfig
    cmds:
      - talosctl kubeconfig -n {{.NODE_IP}}
    vars:
      NODE_IP:
        sh: echo ${NODE_IP:-192.168.1.100}

  # === Flux Tasks ===
  flux:check:
    desc: Check Flux prerequisites
    cmds:
      - flux check --pre

  flux:bootstrap:
    desc: Bootstrap Flux
    cmds:
      - |
        flux bootstrap github \
          --owner=${GITHUB_USER} \
          --repository=infra \
          --branch=main \
          --path=clusters/{{.CLUSTER_NAME}} \
          --personal

  flux:reconcile:
    desc: Force Flux reconciliation
    cmds:
      - flux reconcile source git flux-system
      - flux reconcile kustomization flux-system

  # === Kubernetes Tasks ===
  k8s:deploy-longhorn:
    desc: Deploy Longhorn via Helm
    cmds:
      - kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -
      - kubectl label namespace longhorn-system pod-security.kubernetes.io/enforce=privileged pod-security.kubernetes.io/audit=privileged pod-security.kubernetes.io/warn=privileged
      - helm repo add longhorn https://charts.longhorn.io
      - helm repo update
      - helm install longhorn longhorn/longhorn --namespace longhorn-system --version 1.7.2 --values kubernetes/longhorn/longhorn-values.yaml

  k8s:deploy-monitoring:
    desc: Deploy kube-prometheus-stack
    cmds:
      - kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
      - helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      - helm repo update
      - helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring

  # === Ansible Tasks ===
  ansible:baseline:all:
    desc: Run baseline on all VMs
    dir: ansible
    cmds:
      - ansible-playbook -i inventories/production.yml playbooks/day1_all_vms.yml

  ansible:baseline:debian:
    desc: Run Debian baseline
    dir: ansible
    cmds:
      - ansible-playbook -i inventories/production.yml playbooks/day1_debian_baseline.yml

  # === Lint Tasks ===
  lint:all:
    desc: Run all linters
    deps: [lint:terraform, lint:ansible, lint:packer]

  lint:terraform:
    desc: Lint Terraform
    cmds:
      - terraform fmt -check -recursive
      - tflint --init
      - tflint --recursive

  lint:ansible:
    desc: Lint Ansible
    dir: ansible
    cmds:
      - ansible-lint

  lint:packer:
    desc: Validate Packer templates
    cmds:
      - task: packer:validate

  # === Security Tasks ===
  security:scan:
    desc: Run Trivy security scan
    cmds:
      - trivy config .

  security:scan-image:
    desc: Scan Talos image
    cmds:
      - trivy image factory.talos.dev/installer/${TALOS_VERSION}

  # === Documentation Tasks ===
  docs:serve:
    desc: Serve documentation (if using mkdocs)
    cmds:
      - echo "Documentation available in docs/"
      - ls -la docs/

  # === Helper Tasks ===
  help:
    desc: Show available tasks
    cmds:
      - task --list

  clean:
    desc: Clean build artifacts
    cmds:
      - rm -rf packer/*/manifest.json
      - rm -rf terraform/.terraform
      - rm -rf talos-config/
```

### Step 3: Test Taskfile

```bash
# List all tasks
task --list

# Test a simple task
task flux:check

# Test Packer validation
task packer:validate
```

**Success Criteria**:
- ✅ `task --list` shows all tasks
- ✅ Common workflows automated
- ✅ Reduced manual command typing

---

## Phase 3: Monitoring Stack (Week 2)

**Objective**: Deploy cluster observability
**Effort**: 2-3 hours
**Impact**: HIGH
**Reference**: kube-prometheus-stack

### Step 1: Deploy kube-prometheus-stack

```bash
# Create monitoring namespace
kubectl create namespace monitoring

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

### Step 2: Deploy Loki for Logging

```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts

# Install Loki stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

### Step 3: Enable Longhorn Metrics

Update `kubernetes/longhorn/longhorn-values.yaml`:

```yaml
metrics:
  serviceMonitor:
    enabled: true
```

Upgrade Longhorn:

```bash
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --values kubernetes/longhorn/longhorn-values.yaml
```

### Step 4: Access Grafana

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Access at http://localhost:3000
# Username: admin
# Password: admin (or what you set)
```

### Step 5: Import Dashboards

Import these Grafana dashboard IDs:
- **15757**: Kubernetes / Views / Global
- **15758**: Kubernetes / Views / Namespaces
- **15759**: Kubernetes / Views / Pods
- **13032**: Longhorn Dashboard

**Success Criteria**:
- ✅ Prometheus collecting metrics
- ✅ Grafana accessible
- ✅ Loki collecting logs
- ✅ Longhorn metrics visible

---

## Phase 4: CI/CD Pipeline (Week 3)

**Objective**: Automated testing and validation
**Effort**: 4-6 hours
**Impact**: MEDIUM
**Reference**: GitHub Actions

### Step 1: Create Lint Workflow

Create `.github/workflows/lint.yaml`:

```yaml
name: Lint

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      - name: TFLint
        uses: terraform-linters/setup-tflint@v4
      - run: tflint --init
      - run: tflint --recursive

  ansible:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Ansible
        run: pip install ansible ansible-lint
      - name: Ansible Lint
        working-directory: ansible
        run: ansible-lint

  packer:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-packer@v3
      - name: Packer Validate
        run: |
          for dir in packer/*/; do
            cd "$dir"
            packer init .
            packer validate .
            cd -
          done

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: '.'
```

### Step 2: Create Documentation Workflow

Create `.github/workflows/docs.yaml`:

```yaml
name: Documentation

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - '**.md'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Markdown Lint
        uses: DavidAnson/markdownlint-cli2-action@v16
        with:
          globs: '**/*.md'
```

### Step 3: Test Workflows Locally

```bash
# Install act for local testing
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Test lint workflow
act -j terraform
act -j ansible
```

**Success Criteria**:
- ✅ Workflows run on push/PR
- ✅ Linting catches errors
- ✅ Security scanning enabled

---

## Success Metrics

### After Phase 1 (FluxCD)
- ✅ GitOps operational
- ✅ Automatic reconciliation from Git
- ✅ Longhorn deployed via Flux

### After Phase 2 (Taskfile)
- ✅ Common tasks automated
- ✅ Reduced manual command typing
- ✅ Consistent workflows

### After Phase 3 (Monitoring)
- ✅ Prometheus collecting metrics
- ✅ Grafana dashboards accessible
- ✅ Loki aggregating logs
- ✅ Longhorn metrics visible

### After Phase 4 (CI/CD)
- ✅ Automated testing on commits
- ✅ Security scanning in pipeline
- ✅ Documentation validation

---

## Timeline

| Week | Phase | Effort | Status |
|------|-------|--------|--------|
| Week 1 | FluxCD Bootstrap | 2-4 hours | 🔲 Pending |
| Week 1 | Taskfile Automation | 1-2 hours | 🔲 Pending |
| Week 2 | Monitoring Stack | 2-3 hours | 🔲 Pending |
| Week 3 | CI/CD Pipeline | 4-6 hours | 🔲 Pending |

**Total Effort**: 9-15 hours over 3 weeks

---

## Optional Enhancements (Future)

### Low Priority (Nice to Have)

1. **Cloudflare Tunnel** (2-3 hours)
   - External access without port forwarding
   - Reference: onedr0p/cluster-template

2. **Pre-commit Hooks** (1-2 hours)
   - Automated code quality checks
   - Reference: pre-commit-terraform

3. **Publish Terraform Modules** (6-8 hours)
   - Contribute to community
   - Reference: Terraform Registry

4. **ArgoCD Alternative** (4-6 hours)
   - Test ArgoCD vs FluxCD
   - Reference: SerhiiMyronets/terraform-talos-gitops-homelab

---

## Conclusion

This action plan will enhance the infrastructure from **production-ready (5/5)** to **industry-leading (top 10%)** by adding:

1. ✅ **GitOps automation** (FluxCD)
2. ✅ **Workflow simplification** (Taskfile)
3. ✅ **Cluster observability** (Monitoring stack)
4. ✅ **Automated testing** (CI/CD pipeline)

All enhancements are **non-breaking** and can be implemented **incrementally** over 3 weeks.

---

**Next Step**: Begin Phase 1 (FluxCD Bootstrap)

**Command**:
```bash
task flux:bootstrap
```

(or manually follow Phase 1 steps if Taskfile not yet implemented)
