# Pangolin External Access

Pangolin provides secure external access to homelab services without port forwarding.

## Overview

| Component | Description |
|-----------|-------------|
| **Pangolin** | Tunneling service running on Vultr VPS (207.246.115.3) |
| **Newt** | WireGuard client extension for Talos Linux |
| **Purpose** | Expose services externally via custom domains |

### Why Pangolin?

1. **No port forwarding** - Works behind CGNAT, firewalls, dynamic IPs
2. **Custom domains** - Use your own domains (reynoza.org, unix.red)
3. **TLS termination** - Automatic HTTPS certificates
4. **Access control** - Public or private resource configuration

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Internet                                                                 │
│                                                                          │
│   photos.reynoza.org ──► Pangolin VPS (207.246.115.3)                   │
│   unix.red            ──► NixOS + Pangolin Service                      │
│                              │                                           │
│                              │ WireGuard Tunnel                          │
│                              ▼                                           │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │ Homelab (10.10.2.0/24)                                           │  │
│   │                                                                  │  │
│   │   Talos Node (10.10.2.10)                                       │  │
│   │   ├─ Newt Extension (WireGuard client)                          │  │
│   │   └─ Kubernetes Services                                         │  │
│   │       ├─ Immich (10.10.2.22) → photos.reynoza.org               │  │
│   │       ├─ Emby (10.10.2.30) → [external domain TBD]              │  │
│   │       └─ Other services (internal only)                          │  │
│   └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

## Configuration

### Prerequisites

1. Pangolin account and VPS at 207.246.115.3
2. Newt extension in Talos schematic (`siderolabs/newt`)
3. Pangolin credentials (URL, ID, secret)

### Step 1: Obtain Pangolin Credentials

1. Log into Pangolin dashboard at https://207.246.115.3
2. Create a new site/client configuration
3. Obtain:
   - **Endpoint URL** (pangolin_url)
   - **Client ID** (pangolin_user)
   - **Client Secret** (pangolin_token)

### Step 2: Create Encrypted Secrets

```bash
# Create plaintext secret
cat > /tmp/pangolin-creds.yaml << 'EOF'
pangolin_url: "https://207.246.115.3"
pangolin_user: "your-newt-id"
pangolin_token: "your-newt-secret-token"
EOF

# Encrypt with SOPS
sops -e /tmp/pangolin-creds.yaml > secrets/pangolin-creds.enc.yaml

# Remove plaintext
rm /tmp/pangolin-creds.yaml
```

### Step 3: Enable in Terraform

```bash
cd terraform/talos

# Pangolin is enabled by default (enable_pangolin = true)
# To verify:
grep enable_pangolin variables-services.tf

# Apply configuration
terraform apply
```

### Step 4: Verify Connection

```bash
# Check Newt extension is running
talosctl -n 10.10.2.10 services

# Look for 'newt' service status
# Expected: Running

# Check extension logs
talosctl -n 10.10.2.10 logs ext-newt
```

## Exposed Services

### Current Configuration

| Service | Internal IP | External Domain | Access |
|---------|-------------|-----------------|--------|
| Homepage | 10.10.2.21 | home.home-infra.net | Private |
| Immich | 10.10.2.22 | photos.reynoza.org | Private |
| Emby | 10.10.2.30 | TBD | Public (planned) |

### Domain Resolution

External domains resolve through:
1. **ControlD** - Local DNS for home-infra.net, home.arpa
2. **Pangolin** - External DNS for reynoza.org, unix.red
3. **mDNS** - .local domains via router

## Managing Resources

Pangolin uses "resources" to define what's exposed:

### Resource Types

| Type | Description | Use Case |
|------|-------------|----------|
| **Public** | No authentication required | Media streaming (Emby) |
| **Private** | Authentication required | Personal apps (Immich) |

### Configure a Resource

1. Access Pangolin dashboard
2. Navigate to **Resources** > **Add Resource**
3. Configure:
   - **Name**: Service identifier
   - **Domain**: External hostname
   - **Backend**: Internal service URL (e.g., http://10.10.2.22)
   - **Access**: Public or Private

Docs: https://docs.pangolin.net/manage/resources/understanding-resources

## Network Flow

```
1. User visits photos.reynoza.org
      │
      ▼
2. DNS resolves to Pangolin VPS (207.246.115.3)
      │
      ▼
3. Pangolin receives request, authenticates (if private)
      │
      ▼
4. Pangolin routes through WireGuard tunnel to Newt
      │
      ▼
5. Newt (in Talos) forwards to Kubernetes service
      │
      ▼
6. Service responds, traffic flows back through tunnel
```

## Terraform Configuration

### Variables

```hcl
# variables-services.tf
variable "enable_pangolin" {
  description = "Enable Pangolin/Newt WireGuard tunnel"
  type        = bool
  default     = true
}
```

### Extension Config

```hcl
# config.tf (ExtensionServiceConfig for Newt)
environment = [
  "PANGOLIN_ENDPOINT=${pangolin_url}",
  "NEWT_ID=${pangolin_user}",
  "NEWT_SECRET=${pangolin_token}"
]
```

### SOPS Integration

```hcl
# sops.tf
data "sops_file" "pangolin_secrets" {
  count       = var.enable_pangolin ? 1 : 0
  source_file = "${path.module}/../../secrets/pangolin-creds.enc.yaml"
}
```

## Troubleshooting

### Tunnel Not Connecting

```bash
# Check Newt service status
talosctl -n 10.10.2.10 services | grep newt

# View Newt logs
talosctl -n 10.10.2.10 logs ext-newt --tail 100

# Common issues:
# - Invalid credentials (check pangolin-creds.enc.yaml)
# - VPS unreachable (check 207.246.115.3 connectivity)
# - Firewall blocking WireGuard (UDP 51820)
```

### External Domain Not Working

```bash
# Test DNS resolution
dig photos.reynoza.org

# Test from outside network
curl -I https://photos.reynoza.org

# Check Pangolin resource configuration in dashboard
```

### Service Not Accessible

```bash
# Verify service is running
kubectl get svc -A | grep <service-ip>

# Test from inside cluster
kubectl run test --rm -it --image=busybox -- wget -O- http://<service-ip>

# Check Pangolin backend configuration
```

## Security Considerations

1. **WireGuard encryption** - All traffic through tunnel is encrypted
2. **Private resources** - Require authentication for sensitive services
3. **Credential rotation** - Update pangolin-creds.enc.yaml periodically
4. **VPS hardening** - Secure the Pangolin VPS (NixOS configuration)

## References

- [Pangolin Documentation](https://docs.pangolin.net/)
- [Talos Extensions](https://www.talos.dev/latest/talos-guides/configuration/extensions/)
- [WireGuard](https://www.wireguard.com/)
- [Newt Extension](https://github.com/siderolabs/extensions/tree/main/container-runtime/newt)
---

**Last Updated:** 2026-01-20
