#!/usr/bin/env python3
"""
DNS Configuration Generator

Generates configuration files for ControlD DNS and Pangolin VPN by scanning
HTTPRoute manifests. All services route through Gateway API (INGRESS_IP).

Usage:
    ./scripts/generate-dns-config.py --dry-run    # Preview changes
    ./scripts/generate-dns-config.py              # Generate both configs
    ./scripts/generate-dns-config.py --diff       # Show diff from current

Architecture: All web services use ClusterIP and are accessed via Cilium Gateway API.
Only the Gateway itself (10.10.2.20) needs a LoadBalancer IP for HTTPS termination.
"""

import argparse
import difflib
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    print("Or enter nix-shell which includes it.")
    sys.exit(1)


# Gateway API LoadBalancer IP
# All web services route through this IP for HTTPS termination
INGRESS_IP = "10.10.2.20"

# Domain suffixes managed by Gateway API
MANAGED_SUFFIXES = {"home-infra.net", "reynoza.org"}

# Static resources not managed by Kubernetes (external infrastructure)
# These use direct IPs (not routed through Gateway API)
STATIC_RESOURCES = {
    "proxmox": {
        "ip": "10.10.2.2",
        "category": "infrastructure",
        "aliases": ["pve"],
        "suffixes": ["home-infra.net"],
    },
    "nas": {
        "ip": "10.10.2.5",
        "category": "infrastructure",
        "suffixes": ["home-infra.net"],
    },
}

# Category ordering for output
CATEGORY_ORDER = [
    "infrastructure",
    "ai",
    "applications",
    "arr-stack",
]


def get_category_from_path(file_path: str) -> str:
    """Determine category based on file path."""
    if "/ai/" in file_path:
        return "ai"
    elif "/arr-stack/" in file_path:
        return "arr-stack"
    elif "/infrastructure/" in file_path or "/kube-system/" in file_path:
        return "infrastructure"
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


def scan_httproutes(repo_root: Path, verbose: bool = False) -> list[dict]:
    """Scan HTTPRoute manifests to discover services and their hostnames."""
    services = []
    seen_hostnames = set()

    # Scan all directories for HTTPRoute files
    for yaml_file in repo_root.rglob("*httproute*.yaml"):
        if ".git" in str(yaml_file):
            continue

        try:
            content = yaml_file.read_text()
            for doc in yaml.safe_load_all(content):
                if not doc:
                    continue
                if doc.get("kind") != "HTTPRoute":
                    continue

                metadata = doc.get("metadata", {})
                spec = doc.get("spec", {})
                hostnames = spec.get("hostnames", [])

                for hostname in hostnames:
                    if hostname in seen_hostnames:
                        continue
                    seen_hostnames.add(hostname)

                    # Determine if it's a full hostname or needs suffix
                    # Parse the hostname to get service name and suffix
                    parts = hostname.split(".", 1)
                    if len(parts) == 2:
                        name = parts[0]
                        suffix = parts[1]
                    else:
                        name = hostname
                        suffix = "home-infra.net"

                    # Special case: root domain (e.g., home-infra.net)
                    if hostname in MANAGED_SUFFIXES:
                        name = "home"
                        suffix = hostname

                    service = {
                        "name": name,
                        "hostname": hostname,
                        "ip": INGRESS_IP,
                        "suffix": suffix,
                        "category": get_category_from_path(str(yaml_file)),
                        "file": str(yaml_file.relative_to(repo_root)),
                        "namespace": metadata.get("namespace", "unknown"),
                        "is_fqdn": hostname in MANAGED_SUFFIXES,
                    }

                    if verbose:
                        print(f"  {name:<15} {hostname:<35} ({service['file']})")

                    services.append(service)

        except Exception as e:
            if verbose:
                print(f"  Warning: Failed to parse {yaml_file}: {e}")
            continue

    return services


def build_service_registry(repo_root: Path, verbose: bool = False) -> list[dict]:
    """Build a complete registry of services from HTTPRoutes and static resources."""
    services = scan_httproutes(repo_root, verbose)

    # Add static resources (external infrastructure not managed by Kubernetes)
    for name, info in STATIC_RESOURCES.items():
        for suffix in info.get("suffixes", ["home-infra.net"]):
            hostname = f"{name}.{suffix}"
            service = {
                "name": name,
                "hostname": hostname,
                "ip": info["ip"],  # Static resources use direct IP
                "suffix": suffix,
                "category": info["category"],
                "file": "static",
                "namespace": None,
                "is_fqdn": False,
                "aliases": info.get("aliases", []),
            }
            if verbose:
                print(f"  {name:<15} {info['ip']:<15} -> (static)")
            services.append(service)

            # Add aliases
            for alias in info.get("aliases", []):
                alias_hostname = f"{alias}.{suffix}"
                alias_service = {
                    "name": alias,
                    "hostname": alias_hostname,
                    "ip": info["ip"],
                    "suffix": suffix,
                    "category": info["category"],
                    "file": "static-alias",
                    "namespace": None,
                    "is_fqdn": False,
                }
                services.append(alias_service)

    return services


def generate_controld_config(services: list[dict]) -> str:
    """Generate domains.yaml content for ControlD.

    All web services route through Gateway API (INGRESS_IP) for HTTPS termination.
    Static resources (proxmox, nas) use their direct IPs.
    """
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "# ControlD DNS Domain Definitions",
        "# Auto-generated by generate-dns-config.py",
        "# Source: HTTPRoute manifests in kubernetes/",
        f"# Generated: {now}",
        "#",
        "# DO NOT EDIT MANUALLY - changes will be overwritten",
        "# To customize: edit HTTPRoutes or the generator script",
        "#",
        "# Routing architecture:",
        f"#   *.home-infra.net, *.reynoza.org -> {INGRESS_IP} (Cilium Gateway API, HTTPS)",
        "#   Static resources (proxmox, nas) -> direct IPs",
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

        for svc in sorted(by_category[category], key=lambda x: x["hostname"]):
            lines.append(f"  - name: {svc['name']}")
            lines.append(f"    ip: {svc['ip']}")

            # Handle FQDN vs suffix-based hostname
            if svc.get("is_fqdn"):
                lines.append(f"    fqdn: {svc['hostname']}")
            else:
                lines.append(f"    suffixes: [{svc['suffix']}]")

            # Add comment about routing
            if svc["ip"] == INGRESS_IP:
                lines.append("    # HTTPS via Gateway API")
            else:
                lines.append("    # Direct IP access")
            lines.append("")

    return "\n".join(lines)


def generate_pangolin_config(services: list[dict]) -> str:
    """Generate resources.yaml content for Pangolin."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines = [
        "# Pangolin Private Resource Definitions",
        "# Auto-generated by generate-dns-config.py",
        "# Source: HTTPRoute manifests in kubernetes/",
        f"# Generated: {now}",
        "#",
        "# DO NOT EDIT MANUALLY - changes will be overwritten",
        "# To customize: edit HTTPRoutes or the generator script",
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

    # Track seen names to avoid duplicates
    seen_names = set()

    for category in CATEGORY_ORDER:
        if category not in by_category:
            continue

        # Category header
        header = category.replace("-", " ").title()
        lines.append(f"  # {'=' * 74}")
        lines.append(f"  # {header}")
        lines.append(f"  # {'=' * 74}")

        for svc in sorted(by_category[category], key=lambda x: x["hostname"]):
            if svc["name"] in seen_names:
                continue
            seen_names.add(svc["name"])

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
        description="Generate DNS configs from HTTPRoute manifests"
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

    print("Scanning HTTPRoute manifests...")
    services = build_service_registry(repo_root, args.verbose)
    print(f"Discovered {len(services)} services/hostnames")

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
