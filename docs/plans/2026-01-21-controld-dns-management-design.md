# ControlD DNS Management Script Design

**Date:** 2026-01-21
**Status:** Approved

## Overview

Python script to manage DNS domains in ControlD for homelab services. Creates DNS rules that redirect `*.home-infra.net` and `*.home.arpa` domains to local service IPs.

## Requirements

- Manage DNS rules in ControlD profile "Default", folder "home-infra"
- Support both `home-infra.net` and `home.arpa` suffixes
- Spoof (redirect) domains to specified IP addresses
- Idempotent sync with dry-run preview
- Separate config files for settings and domains
- SOPS-encrypted API token

## File Structure

```
scripts/controld/
├── controld-dns.py          # Main script
├── config.yaml              # Script settings
└── domains.yaml             # Domain definitions

secrets/
└── controld-token.enc.yaml  # SOPS-encrypted API token
```

## Configuration

**config.yaml** - Script settings:
```yaml
api_base_url: https://api.controld.com
profile_name: Default
folder_name: home-infra
suffixes:
  - home-infra.net
  - home.arpa
```

**domains.yaml** - Domain definitions:
```yaml
domains:
  - name: hubble
    ip: 10.10.2.11
  - name: proxmox
    ip: 10.10.2.2
    aliases: [pve]  # Optional aliases
```

**secrets/controld-token.enc.yaml**:
```yaml
token: "api-token-here"
```

## CLI Interface

```bash
# Set API token
export CONTROLD_API_TOKEN=$(sops -d secrets/controld-token.enc.yaml | yq '.token')

# List current rules
./scripts/controld/controld-dns.py list

# Preview changes (dry-run)
./scripts/controld/controld-dns.py sync --dry-run

# Apply changes
./scripts/controld/controld-dns.py sync

# Force recreate all rules
./scripts/controld/controld-dns.py sync --force
```

## API Workflow

1. **Discovery:**
   - `GET /profiles` → Find profile ID by name
   - `GET /profiles/{id}/groups` → Find folder ID by name
   - `GET /profiles/{id}/rules/{folder}` → Get existing rules

2. **Sync Logic:**
   - Build desired state from domains.yaml
   - Compare with current state from API
   - Calculate: to_add, to_update, to_delete

3. **Apply:**
   - `POST /profiles/{id}/rules` → Create rule
   - `PUT /profiles/{id}/rules` → Update rule
   - `DELETE /profiles/{id}/rules/{host}` → Delete rule

## Domain Mapping

Each domain entry creates rules for both suffixes:
- `hubble` → `hubble.home-infra.net` + `hubble.home.arpa`

Aliases create additional rules:
- `proxmox` with alias `pve` → 4 rules total

## Error Handling

- Retry on rate limits (429) with exponential backoff
- Validate IP addresses before API calls
- Non-zero exit code on failures
- Verbose output for debugging

## Dependencies

- Python 3 (standard library)
- PyYAML (available in nix-shell)
- SOPS for token decryption

---

**Last Updated:** 2026-01-21
