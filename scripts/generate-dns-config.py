#!/usr/bin/env python3
"""
DNS Configuration Generator

Generates configuration files for ControlD DNS and Pangolin VPN from
FluxCD manifests, using cluster-vars.yaml as the source of truth.

Usage:
    ./scripts/generate-dns-config.py --dry-run    # Preview changes
    ./scripts/generate-dns-config.py              # Generate both configs
    ./scripts/generate-dns-config.py --diff       # Show diff from current

Source of truth: kubernetes/infrastructure/cluster-vars/cluster-vars.yaml
"""

import argparse
import difflib
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    print("Or enter nix-shell which includes it.")
    sys.exit(1)


# Ingress Controller IP for HTTPS access
# Services with Ingress resources route their external domains (home-infra.net, reynoza.org)
# through this IP for TLS termination
INGRESS_IP = "10.10.2.20"

# Domain suffixes that should route through Ingress (HTTPS)
# These will resolve to INGRESS_IP instead of the service's LoadBalancer IP
INGRESS_SUFFIXES = {"home-infra.net", "reynoza.org"}


# Name mappings: IP variable suffix -> DNS short name
# Used when the variable name doesn't match the desired DNS name
NAME_MAPPINGS = {
    "OPENWEBUI": "chat",
    "HOMEASSISTANT": "hass",
    "VICTORIAMETRICS": "metrics",
    "ITTOOLS": "tools",
    "FORGEJO_HTTP": "git",
    "NAVIDROME": "music",
    "HOMEPAGE": "home",
    "IMMICH": "photos",
    "COMFYUI": "comfy",
    "COPYPARTY": "files",
    "LOGTO": "auth",
}

# Services that need multiple domain suffixes
MULTI_SUFFIX_SERVICES = {
    "affine": ["home.arpa", "home-infra.net"],
    "auth": ["home.arpa", "home-infra.net"],
    "git": ["home.arpa", "home-infra.net"],
    "gitops": ["home.arpa", "home-infra.net"],
    "chat": ["home.arpa", "home-infra.net"],
    "ollama": ["home.arpa", "home-infra.net"],
    "comfy": ["home.arpa", "home-infra.net"],
    "attic": ["home.arpa", "home-infra.net"],
    "emby": ["home.arpa", "home-infra.net"],
    "music": ["home.arpa", "home-infra.net"],
    "tools": ["home.arpa", "home-infra.net"],
    "ntfy": ["home.arpa", "home-infra.net"],
    "photos": ["home.arpa", "reynoza.org"],
}

# Services with explicit FQDN (no suffix processing)
# Use when the service name would create a bad FQDN (e.g., home.home.arpa)
FQDN_OVERRIDES = {
    "home": ["home.arpa"],  # Homepage accessible at home.arpa (not home.home.arpa)
}

# Additional domains not derived from cluster-vars IP variables
# Format: {short_name: {"suffixes": [...], "ip": "..."}}
# Use "INGRESS" for ip to use INGRESS_IP
ADDITIONAL_DOMAINS = {
    # No additional domains needed - Logto uses single domain with path-based routing
    # auth.home-infra.net serves both Admin Console (/console) and Core API (everything else)
}

# Services to skip (not user-facing or internal only)
SKIP_SERVICES = {
    "FORGEJO_SSH",  # SSH access, not HTTP
    "WEBHOOK",  # FluxCD internal webhook
}

# Infrastructure services that need manual K8s service definitions
# (not auto-discoverable from apps/)
INFRASTRUCTURE_SERVICES = {
    "HUBBLE": {
        "k8s_service": "hubble-ui",
        "namespace": "kube-system",
    },
    "LONGHORN": {
        "k8s_service": "longhorn-frontend",
        "namespace": "longhorn-system",
    },
    "FORGEJO_HTTP": {
        "k8s_service": "forgejo-http",
        "namespace": "forgejo",
    },
    "GITOPS": {
        "k8s_service": "weave-gitops-lb",
        "namespace": "flux-system",
    },
    "MINIO": {
        "k8s_service": "minio-console",
        "namespace": "backup",
    },
}

# Static resources not managed by Kubernetes (external infrastructure)
STATIC_RESOURCES = {
    "proxmox": {
        "ip": "10.10.2.2",
        "category": "infrastructure",
        "aliases": ["pve"],
        # Only home.arpa - Proxmox is internal infrastructure, not exposed via home-infra.net
    },
    "nas": {
        "ip": "10.10.2.5",
        "category": "infrastructure",
    },
}

# Category ordering for output
CATEGORY_ORDER = [
    "infrastructure",
    "ai",
    "applications",
    "arr-stack",
]


# IP range to category mapping
def get_category(ip: str) -> str:
    """Determine category based on IP address."""
    last_octet = int(ip.split(".")[-1])
    # Check AI range (50-59)
    if 50 <= last_octet <= 59:  # AI services
        return "ai"
    elif 11 <= last_octet <= 20:  # Infrastructure (includes Ingress at .20)
        return "infrastructure"
    elif 40 <= last_octet <= 49:
        return "arr-stack"
    else:
        return "applications"


def find_repo_root() -> Path:
    """Find the repository root by looking for .git directory."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    return Path(__file__).resolve().parent.parent


def load_cluster_vars(repo_root: Path) -> dict[str, str]:
    """Load IP variables from cluster-vars.yaml."""
    cluster_vars_path = (
        repo_root / "kubernetes/infrastructure/cluster-vars/cluster-vars.yaml"
    )

    if not cluster_vars_path.exists():
        print(f"Error: cluster-vars.yaml not found at {cluster_vars_path}")
        sys.exit(1)

    with open(cluster_vars_path) as f:
        docs = list(yaml.safe_load_all(f))

    for doc in docs:
        if doc and doc.get("kind") == "ConfigMap":
            return doc.get("data", {})

    print("Error: No ConfigMap found in cluster-vars.yaml")
    sys.exit(1)


def extract_ip_services(cluster_vars: dict[str, str]) -> dict[str, str]:
    """Extract IP_* variables and their values."""
    ip_services = {}
    for key, value in cluster_vars.items():
        if key.startswith("IP_"):
            suffix = key[3:]  # Remove "IP_" prefix
            if suffix not in SKIP_SERVICES:
                ip_services[suffix] = value
    return ip_services


def scan_kubernetes_manifests(repo_root: Path, ip_var_name: str) -> dict | None:
    """Scan kubernetes manifests for a service using the given IP variable."""
    apps_dir = repo_root / "kubernetes/apps/base"
    infra_dir = repo_root / "kubernetes/infrastructure"

    # Search pattern for the IP variable
    patterns = [
        f'"${{IP_{ip_var_name}}}"',
        f"'${{IP_{ip_var_name}}}'",
        f"${{IP_{ip_var_name}}}",
    ]

    # Search in apps directory
    for yaml_file in apps_dir.rglob("*.yaml"):
        try:
            content = yaml_file.read_text()
            if any(p in content for p in patterns):
                # Parse the YAML to extract service info
                for doc in yaml.safe_load_all(content):
                    if doc and doc.get("kind") == "Service":
                        spec = doc.get("spec", {})
                        if spec.get("type") == "LoadBalancer":
                            metadata = doc.get("metadata", {})
                            return {
                                "k8s_service": metadata.get("name"),
                                "namespace": metadata.get("namespace"),
                                "file": str(yaml_file.relative_to(repo_root)),
                            }
        except Exception:
            continue

    # Search in infrastructure directory
    for yaml_file in infra_dir.rglob("*.yaml"):
        try:
            content = yaml_file.read_text()
            if any(p in content for p in patterns):
                for doc in yaml.safe_load_all(content):
                    if doc and doc.get("kind") == "Service":
                        spec = doc.get("spec", {})
                        if spec.get("type") == "LoadBalancer":
                            metadata = doc.get("metadata", {})
                            return {
                                "k8s_service": metadata.get("name"),
                                "namespace": metadata.get("namespace"),
                                "file": str(yaml_file.relative_to(repo_root)),
                            }
        except Exception:
            continue

    return None


def build_service_registry(
    repo_root: Path, ip_services: dict[str, str], verbose: bool = False
) -> list[dict]:
    """Build a complete registry of services with their metadata."""
    services = []

    for var_suffix, ip in sorted(ip_services.items(), key=lambda x: x[1]):
        # Get short name (apply mappings)
        short_name = NAME_MAPPINGS.get(var_suffix, var_suffix.lower())

        # Get K8s service info
        if var_suffix in INFRASTRUCTURE_SERVICES:
            k8s_info = INFRASTRUCTURE_SERVICES[var_suffix]
        else:
            k8s_info = scan_kubernetes_manifests(repo_root, var_suffix)

        if k8s_info is None:
            if verbose:
                print(f"  Warning: No K8s service found for IP_{var_suffix}")
            # Create placeholder for ControlD-only entry
            k8s_info = {
                "k8s_service": short_name,
                "namespace": "unknown",
            }

        # Build K8s internal DNS name
        k8s_dns = f"{k8s_info['k8s_service']}.{k8s_info['namespace']}.svc.cluster.local"

        # Get domain suffixes or FQDN override
        fqdn_override = FQDN_OVERRIDES.get(short_name)
        suffixes = MULTI_SUFFIX_SERVICES.get(short_name, ["home.arpa"])

        service = {
            "name": short_name,
            "ip": ip,
            "var_name": f"IP_{var_suffix}",
            "k8s_service": k8s_info["k8s_service"],
            "namespace": k8s_info["namespace"],
            "k8s_dns": k8s_dns,
            "suffixes": suffixes,
            "fqdn": fqdn_override,  # None if no override
            "category": get_category(ip),
        }

        if verbose:
            file_info = k8s_info.get("file", "infrastructure")
            print(f"  {short_name:<15} {ip:<15} -> {k8s_dns} ({file_info})")

        services.append(service)

    # Add static resources (external infrastructure not managed by Kubernetes)
    for name, info in STATIC_RESOURCES.items():
        service = {
            "name": name,
            "ip": info["ip"],
            "var_name": f"STATIC_{name.upper()}",
            "k8s_service": None,
            "namespace": None,
            "k8s_dns": None,
            "suffixes": info.get("suffixes", ["home.arpa"]),
            "aliases": info.get("aliases", []),
            "fqdn": None,
            "category": info["category"],
        }
        if verbose:
            print(f"  {name:<15} {info['ip']:<15} -> (static)")
        services.append(service)

    # Add additional domains not derived from cluster-vars
    for name, info in ADDITIONAL_DOMAINS.items():
        ip = INGRESS_IP if info["ip"] == "INGRESS" else info["ip"]
        service = {
            "name": name,
            "ip": ip,
            "var_name": f"ADDITIONAL_{name.upper().replace('-', '_')}",
            "k8s_service": None,
            "namespace": None,
            "k8s_dns": None,
            "suffixes": info.get("suffixes", ["home.arpa"]),
            "aliases": [],
            "fqdn": None,
            "category": get_category(ip),
        }
        if verbose:
            print(f"  {name:<15} {ip:<15} -> (additional)")
        services.append(service)

    return services


def generate_controld_config(services: list[dict]) -> str:
    """Generate domains.yaml content for ControlD.

    For services with Ingress (home-infra.net, reynoza.org domains):
    - HTTPS domains route through INGRESS_IP for TLS termination
    - Internal domains (home.arpa) route directly to service LoadBalancer IP
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "# ControlD DNS Domain Definitions",
        "# Auto-generated by generate-dns-config.py",
        f"# Source: kubernetes/infrastructure/cluster-vars/cluster-vars.yaml",
        f"# Generated: {now}",
        "#",
        "# DO NOT EDIT MANUALLY - changes will be overwritten",
        "# To customize: edit cluster-vars.yaml or the generator script",
        "#",
        "# Routing architecture:",
        f"#   *.home-infra.net, *.reynoza.org -> {INGRESS_IP} (Cilium Ingress, HTTPS)",
        "#   *.home.arpa -> direct service LoadBalancer IP (internal, HTTP)",
        "",
        "domains:",
    ]

    # Group by category
    by_category: dict[str, list[dict]] = {}
    for svc in services:
        cat = svc["category"]
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append(svc)

    for category in CATEGORY_ORDER:
        if category not in by_category:
            continue

        # Category header
        header = category.replace("-", " ").title()
        lines.append(f"  # {'=' * 74}")
        lines.append(f"  # {header}")
        lines.append(f"  # {'=' * 74}")

        for svc in sorted(by_category[category], key=lambda x: x["ip"]):
            # Check if this service has any Ingress suffixes
            ingress_suffixes = [s for s in svc["suffixes"] if s in INGRESS_SUFFIXES]
            internal_suffixes = [s for s in svc["suffixes"] if s not in INGRESS_SUFFIXES]

            # If service has Ingress domains, create separate entries
            if ingress_suffixes and internal_suffixes:
                # Entry for internal access (direct to service)
                lines.append(f"  - name: {svc['name']}")
                lines.append(f"    ip: {svc['ip']}")
                if svc.get("aliases"):
                    aliases_str = ", ".join(svc["aliases"])
                    lines.append(f"    aliases: [{aliases_str}]")
                if len(internal_suffixes) == 1 and internal_suffixes[0] == "home.arpa":
                    pass  # default suffix, no need to specify
                else:
                    suffixes_str = ", ".join(internal_suffixes)
                    lines.append(f"    suffixes: [{suffixes_str}]")
                lines.append(f"    # Internal access (direct to service)")
                lines.append("")

                # Entry for HTTPS access (via Ingress)
                lines.append(f"  - name: {svc['name']}")
                lines.append(f"    ip: {INGRESS_IP}")
                suffixes_str = ", ".join(ingress_suffixes)
                lines.append(f"    suffixes: [{suffixes_str}]")
                lines.append(f"    # HTTPS via Ingress")
                lines.append("")
            elif ingress_suffixes:
                # Only Ingress domains - route through Ingress
                lines.append(f"  - name: {svc['name']}")
                lines.append(f"    ip: {INGRESS_IP}")
                if svc.get("aliases"):
                    aliases_str = ", ".join(svc["aliases"])
                    lines.append(f"    aliases: [{aliases_str}]")
                if svc.get("fqdn"):
                    if len(svc["fqdn"]) == 1:
                        lines.append(f"    fqdn: {svc['fqdn'][0]}")
                    else:
                        fqdn_str = ", ".join(svc["fqdn"])
                        lines.append(f"    fqdn: [{fqdn_str}]")
                else:
                    suffixes_str = ", ".join(ingress_suffixes)
                    lines.append(f"    suffixes: [{suffixes_str}]")
                lines.append(f"    # HTTPS via Ingress")
                lines.append("")
            else:
                # No Ingress domains - direct access only
                lines.append(f"  - name: {svc['name']}")
                lines.append(f"    ip: {svc['ip']}")
                if svc.get("aliases"):
                    aliases_str = ", ".join(svc["aliases"])
                    lines.append(f"    aliases: [{aliases_str}]")
                if svc.get("fqdn"):
                    if len(svc["fqdn"]) == 1:
                        lines.append(f"    fqdn: {svc['fqdn'][0]}")
                    else:
                        fqdn_str = ", ".join(svc["fqdn"])
                        lines.append(f"    fqdn: [{fqdn_str}]")
                elif svc["suffixes"] != ["home.arpa"]:
                    suffixes_str = ", ".join(svc["suffixes"])
                    lines.append(f"    suffixes: [{suffixes_str}]")
                lines.append("")

    return "\n".join(lines)


def generate_pangolin_config(services: list[dict]) -> str:
    """Generate resources.yaml content for Pangolin."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "# Pangolin Private Resource Definitions",
        "# Auto-generated by generate-dns-config.py",
        f"# Source: kubernetes/infrastructure/cluster-vars/cluster-vars.yaml",
        f"# Generated: {now}",
        "#",
        "# DO NOT EDIT MANUALLY - changes will be overwritten",
        "# To customize: edit cluster-vars.yaml or the generator script",
        "",
        "resources:",
    ]

    # Group by category
    by_category: dict[str, list[dict]] = {}
    for svc in services:
        cat = svc["category"]
        if cat not in by_category:
            by_category[cat] = []
        by_category[cat].append(svc)

    for category in CATEGORY_ORDER:
        if category not in by_category:
            continue

        # Category header
        header = category.replace("-", " ").title()
        lines.append(f"  # {'=' * 74}")
        lines.append(f"  # {header}")
        lines.append(f"  # {'=' * 74}")

        for svc in sorted(by_category[category], key=lambda x: x["ip"]):
            lines.append(f"  - name: {svc['name']}")
            lines.append(f"    destination: {svc['ip']}")
            lines.append("")

    return "\n".join(lines)


def show_diff(current_content: str, new_content: str, filename: str) -> bool:
    """Show diff between current and new content. Returns True if different."""
    current_lines = current_content.splitlines(keepends=True)
    new_lines = new_content.splitlines(keepends=True)

    # Skip timestamp line in comparison
    def strip_generated_line(lines):
        return [l for l in lines if not l.startswith("# Generated:")]

    if strip_generated_line(current_lines) == strip_generated_line(new_lines):
        return False

    diff = difflib.unified_diff(
        current_lines,
        new_lines,
        fromfile=f"a/{filename}",
        tofile=f"b/{filename}",
    )
    print("".join(diff))
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Generate DNS configs from FluxCD manifests"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview what would be generated without writing files",
    )
    parser.add_argument(
        "--diff",
        action="store_true",
        help="Show diff from current files",
    )
    parser.add_argument(
        "--controld-only",
        action="store_true",
        help="Only generate ControlD domains.yaml",
    )
    parser.add_argument(
        "--pangolin-only",
        action="store_true",
        help="Only generate Pangolin resources.yaml",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Show detailed service discovery output",
    )

    args = parser.parse_args()

    repo_root = find_repo_root()
    controld_path = repo_root / "scripts/controld/domains.yaml"
    pangolin_path = repo_root / "scripts/pangolin/resources.yaml"

    print("Loading cluster-vars.yaml...")
    cluster_vars = load_cluster_vars(repo_root)

    print("Extracting IP services...")
    ip_services = extract_ip_services(cluster_vars)
    print(f"Found {len(ip_services)} IP services")

    print("\nScanning Kubernetes manifests...")
    services = build_service_registry(repo_root, ip_services, args.verbose)
    print(f"Discovered {len(services)} services")

    # Generate configs
    generate_controld = not args.pangolin_only
    generate_pangolin = not args.controld_only

    if generate_controld:
        print(f"\n{'=' * 60}")
        print("ControlD domains.yaml")
        print("=" * 60)

        controld_content = generate_controld_config(services)

        if args.diff and controld_path.exists():
            current = controld_path.read_text()
            if not show_diff(
                current, controld_content, "scripts/controld/domains.yaml"
            ):
                print("No changes")
        elif args.dry_run:
            print(controld_content)
        else:
            controld_path.write_text(controld_content)
            print(f"Written to {controld_path}")

    if generate_pangolin:
        print(f"\n{'=' * 60}")
        print("Pangolin resources.yaml")
        print("=" * 60)

        pangolin_content = generate_pangolin_config(services)

        if args.diff and pangolin_path.exists():
            current = pangolin_path.read_text()
            if not show_diff(
                current, pangolin_content, "scripts/pangolin/resources.yaml"
            ):
                print("No changes")
        elif args.dry_run:
            print(pangolin_content)
        else:
            pangolin_path.write_text(pangolin_content)
            print(f"Written to {pangolin_path}")

    if not args.dry_run and not args.diff:
        print("\nDone! Config files generated.")
        print("Run the sync commands to apply:")
        print("  ./scripts/controld/controld-dns.py sync --dry-run")
        print("  ./scripts/pangolin/pangolin-resources.py sync --dry-run")


if __name__ == "__main__":
    main()
