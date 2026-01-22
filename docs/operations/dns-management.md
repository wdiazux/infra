# DNS Management Scripts

Automation scripts for managing DNS entries and VPN resources across ControlD and Pangolin.

---

## Overview

| Script | Purpose | Config File |
|--------|---------|-------------|
| `generate-dns-config.py` | Auto-generate configs from FluxCD manifests | - |
| `controld-dns.py` | Sync DNS entries to ControlD | `domains.yaml` |
| `pangolin-resources.py` | Sync resources to Pangolin | `resources.yaml` |

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Source of Truth                                 │
│  kubernetes/infrastructure/cluster-vars/cluster-vars.yaml           │
│  (All service IPs defined as IP_* variables)                        │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    generate-dns-config.py                            │
│  Scans cluster-vars.yaml + kubernetes manifests                     │
│  Extracts: service names, IPs, K8s internal DNS                     │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│  scripts/controld/       │  │  scripts/pangolin/       │
│  ├─ config.yaml          │  │  ├─ config.yaml          │
│  └─ domains.yaml (gen)   │  │  └─ resources.yaml (gen) │
└────────────┬─────────────┘  └────────────┬─────────────┘
             │                             │
             ▼                             ▼
┌──────────────────────────┐  ┌──────────────────────────┐
│    controld-dns.py       │  │  pangolin-resources.py   │
│    sync to ControlD API  │  │  sync to Pangolin API    │
└──────────────────────────┘  └──────────────────────────┘
```

---

## Quick Start

```bash
# Enter nix-shell (provides Python + PyYAML)
nix-shell

# 1. Generate configs from FluxCD manifests
./scripts/generate-dns-config.py

# 2. Preview changes to ControlD
./scripts/controld/controld-dns.py sync --dry-run

# 3. Preview changes to Pangolin
./scripts/pangolin/pangolin-resources.py sync --dry-run

# 4. Apply if changes look correct
./scripts/controld/controld-dns.py sync
./scripts/pangolin/pangolin-resources.py sync
```

---

## Scripts

### generate-dns-config.py

Generates `domains.yaml` and `resources.yaml` from FluxCD manifests.

**Location:** `scripts/generate-dns-config.py`

**Source of truth:** `kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`

```bash
# Preview what would be generated
./scripts/generate-dns-config.py --dry-run

# Show diff from current files
./scripts/generate-dns-config.py --diff

# Generate both configs (overwrites existing)
./scripts/generate-dns-config.py

# Generate only one type
./scripts/generate-dns-config.py --controld-only
./scripts/generate-dns-config.py --pangolin-only

# Verbose mode (shows service discovery)
./scripts/generate-dns-config.py --verbose
```

**How it works:**

1. Parses `cluster-vars.yaml` for all `IP_*` variables
2. Scans `kubernetes/apps/base/` for Service manifests using those IPs
3. Extracts: service name, namespace, K8s internal DNS
4. Applies name mappings (e.g., `IP_OPENWEBUI` → `chat`)
5. Generates configs with proper categorization

**Name mappings:**

| IP Variable | DNS Name | Reason |
|-------------|----------|--------|
| IP_OPENWEBUI | chat | User-friendly |
| IP_HOMEASSISTANT | hass | Common abbreviation |
| IP_VICTORIAMETRICS | metrics | Shorter |
| IP_ITTOOLS | tools | Shorter |
| IP_FORGEJO_HTTP | git | Service purpose |
| IP_NAVIDROME | music | Service purpose |
| IP_HOMEPAGE | home | Service purpose |
| IP_IMMICH | photos | Service purpose |
| IP_COMFYUI | comfy | Shorter |

---

### controld-dns.py

Manages DNS entries in ControlD for internal domain resolution.

**Location:** `scripts/controld/controld-dns.py`

**Config files:**
- `scripts/controld/config.yaml` - API settings
- `scripts/controld/domains.yaml` - Domain definitions (auto-generated)

**Token:** `secrets/controld-token.enc.yaml` (SOPS-encrypted)

```bash
# List current rules in ControlD
./scripts/controld/controld-dns.py list

# Preview sync changes
./scripts/controld/controld-dns.py sync --dry-run

# Apply changes
./scripts/controld/controld-dns.py sync

# Force recreate all rules
./scripts/controld/controld-dns.py sync --force

# Delete all rules (requires --confirm)
./scripts/controld/controld-dns.py purge --dry-run
./scripts/controld/controld-dns.py purge --confirm
```

**config.yaml format:**

```yaml
api_base_url: https://api.controld.com
profile_name: Default
folder_name: home-infra
suffixes:
  - home.arpa
```

**domains.yaml format:**

```yaml
domains:
  - name: grafana
    ip: 10.10.2.23

  - name: git
    ip: 10.10.2.13
    suffixes: [home.arpa, home-infra.net]

  - name: photos
    ip: 10.10.2.22
    suffixes: [home.arpa, reynoza.org]
```

---

### pangolin-resources.py

Manages private resources in Pangolin for VPN access.

**Location:** `scripts/pangolin/pangolin-resources.py`

**Config files:**
- `scripts/pangolin/config.yaml` - API settings
- `scripts/pangolin/resources.yaml` - Resource definitions (auto-generated)

**API Key:** `secrets/pangolin-creds.enc.yaml` (SOPS-encrypted, field: `pangolin_api_key`)

```bash
# List current resources in Pangolin
./scripts/pangolin/pangolin-resources.py list

# Preview sync changes
./scripts/pangolin/pangolin-resources.py sync --dry-run

# Apply changes
./scripts/pangolin/pangolin-resources.py sync

# Delete all resources (requires --confirm)
./scripts/pangolin/pangolin-resources.py purge --dry-run
./scripts/pangolin/pangolin-resources.py purge --confirm
```

**config.yaml format:**

```yaml
pangolin_url: https://api.home-infra.net
org_id: home-infra
site_name: Talos
default_suffix: home.arpa
```

**resources.yaml format:**

```yaml
resources:
  - name: grafana
    destination: grafana.monitoring.svc.cluster.local

  - name: photos
    destination: immich.media.svc.cluster.local
```

---

## Workflow

### What to Update When Adding/Removing Services

| Action | Files to Update | Commands to Run |
|--------|-----------------|-----------------|
| **Add service** | 1. `cluster-vars.yaml` (IP), 2. K8s Service manifest | `generate-dns-config.py`, then sync both |
| **Remove service** | 1. `cluster-vars.yaml` (remove IP), 2. Delete K8s manifest | `generate-dns-config.py`, then sync both |
| **Change IP** | 1. `cluster-vars.yaml` (update IP) | `generate-dns-config.py`, then sync both |
| **Change DNS name** | 1. `generate-dns-config.py` (NAME_MAPPINGS) | `generate-dns-config.py`, then sync both |
| **Add suffix** | 1. `generate-dns-config.py` (MULTI_SUFFIX_SERVICES) | `generate-dns-config.py`, then sync both |

### Adding a New Service

**Files to modify:**

1. **`kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`** - Add IP variable
2. **`kubernetes/apps/base/<namespace>/<app>/service.yaml`** - Create Service manifest
3. **`scripts/generate-dns-config.py`** (optional) - Add name mapping if needed

**Step-by-step:**

1. **Add IP variable to cluster-vars.yaml:**

   ```yaml
   # kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
   data:
     IP_MYSERVICE: "10.10.2.50"
   ```

2. **Create Kubernetes Service with LoadBalancer:**

   ```yaml
   # kubernetes/apps/base/myapp/myservice/service.yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: myservice
     namespace: myapp
     annotations:
       io.cilium/lb-ipam-ips: "${IP_MYSERVICE}"
   spec:
     type: LoadBalancer
     ...
   ```

3. **Regenerate DNS configs:**

   ```bash
   ./scripts/generate-dns-config.py
   ```

4. **Sync to providers:**

   ```bash
   ./scripts/controld/controld-dns.py sync --dry-run
   ./scripts/controld/controld-dns.py sync

   ./scripts/pangolin/pangolin-resources.py sync --dry-run
   ./scripts/pangolin/pangolin-resources.py sync
   ```

### Removing a Service

**Files to modify:**

1. **`kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`** - Remove IP variable
2. **`kubernetes/apps/base/<namespace>/<app>/`** - Delete the entire app directory
3. **`scripts/generate-dns-config.py`** (if applicable) - Remove name mapping

**Step-by-step:**

1. **Remove IP variable from cluster-vars.yaml:**

   ```bash
   # Edit kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
   # Remove the line: IP_MYSERVICE: "10.10.2.50"
   ```

2. **Delete Kubernetes manifests:**

   ```bash
   rm -rf kubernetes/apps/base/myapp/myservice/
   # Also remove from kustomization.yaml if referenced
   ```

3. **Regenerate DNS configs:**

   ```bash
   ./scripts/generate-dns-config.py
   ```

4. **Sync to providers (will delete the DNS entries):**

   ```bash
   ./scripts/controld/controld-dns.py sync --dry-run  # Verify [DELETE] entries
   ./scripts/controld/controld-dns.py sync

   ./scripts/pangolin/pangolin-resources.py sync --dry-run
   ./scripts/pangolin/pangolin-resources.py sync
   ```

### Changing a Service IP

**Files to modify:**

1. **`kubernetes/infrastructure/cluster-vars/cluster-vars.yaml`** - Update IP value

**Step-by-step:**

1. **Update IP in cluster-vars.yaml:**

   ```yaml
   # Change from
   IP_MYSERVICE: "10.10.2.50"
   # To
   IP_MYSERVICE: "10.10.2.55"
   ```

2. **Apply Kubernetes changes:**

   ```bash
   flux reconcile kustomization flux-system --with-source
   ```

3. **Regenerate and sync DNS:**

   ```bash
   ./scripts/generate-dns-config.py
   ./scripts/controld/controld-dns.py sync
   ./scripts/pangolin/pangolin-resources.py sync
   ```

### Custom Name Mapping

If the IP variable name doesn't match the desired DNS name, add a mapping in `generate-dns-config.py`:

```python
NAME_MAPPINGS = {
    "MYSERVICE": "my-alias",  # IP_MYSERVICE -> my-alias.home.arpa
}
```

### Multi-Suffix Services

For services that need multiple domain suffixes:

```python
MULTI_SUFFIX_SERVICES = {
    "my-alias": ["home.arpa", "home-infra.net"],
}
```

---

## Secrets Setup

### ControlD Token

```bash
# Create plaintext file
cat > /tmp/controld-token.yaml << 'EOF'
token: "your-controld-api-token"
EOF

# Encrypt with SOPS
sops -e /tmp/controld-token.yaml > secrets/controld-token.enc.yaml
rm /tmp/controld-token.yaml
```

### Pangolin API Key

```bash
# Create plaintext file
cat > /tmp/pangolin-creds.yaml << 'EOF'
pangolin_api_key: "your-pangolin-api-key"
pangolin_url: "https://207.246.115.3"
pangolin_user: "your-newt-id"
pangolin_token: "your-newt-secret-token"
EOF

# Encrypt with SOPS
sops -e /tmp/pangolin-creds.yaml > secrets/pangolin-creds.enc.yaml
rm /tmp/pangolin-creds.yaml
```

---

## Troubleshooting

### Script fails with "No API token/key found"

```bash
# Check encrypted secrets exist
ls -la secrets/controld-token.enc.yaml
ls -la secrets/pangolin-creds.enc.yaml

# Test SOPS decryption
sops -d secrets/controld-token.enc.yaml
sops -d secrets/pangolin-creds.enc.yaml

# Or set environment variable
export CONTROLD_API_TOKEN="your-token"
export PANGOLIN_API_KEY="your-key"
```

### Generated config missing a service

```bash
# Check if IP variable exists
grep "IP_SERVICENAME" kubernetes/infrastructure/cluster-vars/cluster-vars.yaml

# Check if service manifest uses the variable
grep "IP_SERVICENAME" kubernetes/apps/base/**/*.yaml

# Run with verbose to see discovery
./scripts/generate-dns-config.py --verbose
```

### Sync reports no changes but service not accessible

1. Verify DNS resolution:
   ```bash
   dig servicename.home.arpa
   ```

2. Check ControlD dashboard for rule status

3. Verify Pangolin resource is enabled in dashboard

### Rate limiting

Both scripts have built-in retry logic with exponential backoff. If you see rate limiting:

```bash
# Wait and retry, or reduce batch size by syncing fewer services
./scripts/controld/controld-dns.py list  # Check current state first
```

---

## Pangolin API Reference

The `pangolin-resources.py` script uses the Pangolin Integration API to manage private resources.

### Resource Modes

| Mode | Description | Example |
|------|-------------|---------|
| `host` | Single IP or hostname | `10.10.2.23` or `grafana.monitoring.svc.cluster.local` |
| `cidr` | IP address range | `10.10.2.0/24` |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/orgs` | List organizations |
| GET | `/v1/org/{id}/sites` | List sites in organization |
| GET | `/v1/org/{id}/site/{site_id}/resources` | List private resources for site |
| PUT | `/v1/org/{id}/private-resource` | Create private resource |
| POST | `/site-resource/{id}` | Update private resource |
| DELETE | `/site-resource/{id}` | Delete private resource |

### Creating a Private Resource

```bash
curl -X PUT "https://api.home-infra.net/v1/org/home-infra/private-resource" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "grafana",
    "siteId": 123,
    "mode": "host",
    "destination": "grafana.monitoring.svc.cluster.local",
    "alias": "grafana.home.arpa",
    "enabled": true,
    "tcpPortRangeString": "*",
    "udpPortRangeString": "*",
    "disableIcmp": false,
    "userIds": [],
    "roleIds": [],
    "clientIds": []
  }'
```

### Private Resource Properties

| Property | Required | Description |
|----------|----------|-------------|
| `name` | Yes | Human-readable resource name |
| `siteId` | Yes | Site ID (Newt connector) |
| `mode` | Yes | `host` or `cidr` |
| `destination` | Yes | Target IP, hostname, or CIDR |
| `alias` | No | FQDN for DNS resolution (required for hostname destinations) |
| `tcpPortRangeString` | No | TCP ports (`*` for all, or `80,443,8000-9000`) |
| `udpPortRangeString` | No | UDP ports |
| `disableIcmp` | No | Disable ICMP/ping |
| `enabled` | No | Enable/disable resource |

### Blueprint YAML Format

Private resources can also be defined via YAML blueprints:

```yaml
private-resources:
  grafana:
    name: grafana
    mode: host
    destination: grafana.monitoring.svc.cluster.local
    alias: grafana.home.arpa
    site: Talos
```

---

## ControlD API Reference

The `controld-dns.py` script uses the following ControlD API endpoints:

### Rule Types

| Value | Type | Description |
|-------|------|-------------|
| 0 | BLOCK | Block the domain |
| 1 | BYPASS | Bypass filtering |
| 2 | SPOOF | Return custom IP (used for DNS entries) |
| 3 | REDIRECT | Redirect through proxy |

### Key Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/profiles` | List all profiles |
| GET | `/profiles/{id}/groups` | List folders in profile |
| GET | `/profiles/{id}/rules/{folder}` | List rules in folder |
| POST | `/profiles/{id}/rules` | Create rule(s) |
| PUT | `/profiles/{id}/rules` | Update rule |
| DELETE | `/profiles/{id}/rules/{hostname}` | Delete rule by hostname |

### Creating a SPOOF Rule (DNS Entry)

```bash
curl -X POST "https://api.controld.com/profiles/{profile_id}/rules" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "hostnames[]=grafana.home.arpa" \
  -d "do=2" \
  -d "via=10.10.2.23" \
  -d "status=1" \
  -d "group={folder_id}"
```

### Response Structure

```json
{
  "body": {
    "rules": [
      {
        "PK": "grafana.home.arpa",
        "order": 1,
        "group": 123,
        "action": {
          "do": 2,
          "via": "10.10.2.23",
          "status": 1
        }
      }
    ]
  },
  "success": true
}
```

---

## References

- [ControlD API Documentation](https://docs.controld.com/reference/get-profiles)
- [Pangolin Documentation](https://docs.pangolin.net/)
- [Network Reference](../reference/network.md)
- [Pangolin Setup](../services/pangolin.md)

---

**Last Updated:** 2026-01-21
