#!/usr/bin/env python3
"""
Pangolin Private Resources Management Script

Manages private resources in Pangolin for homelab services.
Creates site resources that are accessible through the Pangolin client.

Usage:
    ./scripts/pangolin/pangolin-resources.py list
    ./scripts/pangolin/pangolin-resources.py list-clients
    ./scripts/pangolin/pangolin-resources.py sync --dry-run
    ./scripts/pangolin/pangolin-resources.py sync
    ./scripts/pangolin/pangolin-resources.py sync --clients Ronaldo      # adds to default clients
    ./scripts/pangolin/pangolin-resources.py sync --no-default-clients   # skip default clients
    ./scripts/pangolin/pangolin-resources.py sync --force-client-update  # update clients on all resources

Default clients are configured in config.yaml (default_clients list).
If a default client doesn't exist in Pangolin, it's skipped with a warning.

API key is automatically loaded from secrets/pangolin-creds.enc.yaml via SOPS.
Override with PANGOLIN_API_KEY env var or --token-file argument.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install with: pip install pyyaml")
    print("Or enter nix-shell which includes it.")
    sys.exit(1)


class PangolinClient:
    """Client for Pangolin Integration API."""

    def __init__(self, api_key: str, base_url: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.max_retries = 3
        self.retry_delay = 2

    def _request(
        self, method: str, endpoint: str, data: dict | None = None
    ) -> dict:
        """Make an API request with retry logic."""
        url = f"{self.base_url}/v1{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
        }

        body = None
        if data is not None:
            headers["Content-Type"] = "application/json"
            body = json.dumps(data).encode()

        for attempt in range(self.max_retries):
            try:
                req = urllib.request.Request(url, data=body, headers=headers, method=method)
                with urllib.request.urlopen(req, timeout=30) as response:
                    return json.loads(response.read().decode())
            except urllib.error.HTTPError as e:
                if e.code == 429:  # Rate limited
                    wait = self.retry_delay * (attempt + 1)
                    print(f"  Rate limited, waiting {wait}s...")
                    time.sleep(wait)
                    continue
                error_body = e.read().decode() if e.fp else ""
                raise RuntimeError(f"API error {e.code}: {error_body}") from e
            except urllib.error.URLError as e:
                if attempt < self.max_retries - 1:
                    time.sleep(self.retry_delay)
                    continue
                raise RuntimeError(f"Network error: {e.reason}") from e

        raise RuntimeError("Max retries exceeded")

    def get_orgs(self) -> list[dict]:
        """Get all organizations."""
        resp = self._request("GET", "/orgs")
        return resp.get("data", {}).get("orgs", [])

    def get_org(self, org_id: str) -> dict | None:
        """Get a specific organization by ID."""
        try:
            resp = self._request("GET", f"/org/{org_id}")
            return resp.get("data", {})
        except RuntimeError:
            return None

    def get_sites(self, org_id: str) -> list[dict]:
        """Get all sites for an organization."""
        resp = self._request("GET", f"/org/{org_id}/sites")
        return resp.get("data", {}).get("sites", [])

    def get_site_by_name(self, org_id: str, name: str) -> dict | None:
        """Find a site by name."""
        sites = self.get_sites(org_id)
        for site in sites:
            if site.get("name", "").lower() == name.lower():
                return site
        return None

    def get_site_resources(self, org_id: str, site_id: int) -> list[dict]:
        """Get all private resources for a site."""
        resp = self._request("GET", f"/org/{org_id}/site/{site_id}/resources")
        return resp.get("data", {}).get("siteResources", [])

    def get_all_site_resources(self, org_id: str) -> list[dict]:
        """Get all private resources for an organization."""
        resp = self._request("GET", f"/org/{org_id}/site-resources")
        return resp.get("data", {}).get("siteResources", [])

    def create_site_resource(
        self,
        org_id: str,
        name: str,
        site_id: int,
        mode: str,
        destination: str,
        alias: str | None = None,
        tcp_ports: str = "*",
        udp_ports: str = "*",
        disable_icmp: bool = False,
        enabled: bool = True,
        client_ids: list[int] | None = None,
    ) -> dict:
        """Create a private resource.

        Port format: "*" for all ports, or comma-separated list like "80,443,8000-9000"
        """
        data = {
            "name": name,
            "siteId": site_id,
            "mode": mode,
            "destination": destination,
            "enabled": enabled,
            "userIds": [],
            "roleIds": [],
            "clientIds": client_ids or [],
            "tcpPortRangeString": tcp_ports,
            "udpPortRangeString": udp_ports,
            "disableIcmp": disable_icmp,
        }
        if alias:
            data["alias"] = alias

        return self._request("PUT", f"/org/{org_id}/private-resource", data)

    def update_site_resource(
        self,
        resource_id: int,
        site_id: int,
        name: str | None = None,
        destination: str | None = None,
        alias: str | None = None,
        tcp_ports: str | None = None,
        udp_ports: str | None = None,
        disable_icmp: bool | None = None,
        enabled: bool | None = None,
        client_ids: list[int] | None = None,
    ) -> dict:
        """Update an existing private resource."""
        # Required fields for update
        data = {
            "siteId": site_id,
            "userIds": [],
            "roleIds": [],
            "clientIds": client_ids or [],
        }
        if name is not None:
            data["name"] = name
        if destination is not None:
            data["destination"] = destination
        if alias is not None:
            data["alias"] = alias
        if tcp_ports is not None:
            data["tcpPortRangeString"] = tcp_ports
        if udp_ports is not None:
            data["udpPortRangeString"] = udp_ports
        if disable_icmp is not None:
            data["disableIcmp"] = disable_icmp
        if enabled is not None:
            data["enabled"] = enabled

        return self._request("POST", f"/site-resource/{resource_id}", data)

    def delete_site_resource(self, resource_id: int) -> dict:
        """Delete a private resource."""
        return self._request("DELETE", f"/site-resource/{resource_id}")

    def get_clients(self, org_id: str) -> list[dict]:
        """Get all clients for an organization."""
        resp = self._request("GET", f"/org/{org_id}/clients")
        return resp.get("data", {}).get("clients", [])

    def get_client_by_name(self, org_id: str, name: str) -> dict | None:
        """Find a client by name (case-insensitive)."""
        clients = self.get_clients(org_id)
        for client in clients:
            if client.get("name", "").lower() == name.lower():
                return client
        return None


def load_token_from_sops(token_file: Path) -> str | None:
    """Load API key from SOPS-encrypted file."""
    if not token_file.exists():
        return None

    try:
        result = subprocess.run(
            ["sops", "-d", str(token_file)],
            capture_output=True,
            text=True,
            check=True,
        )
        data = yaml.safe_load(result.stdout)
        return data.get("pangolin_api_key")
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting token file: {e.stderr}")
        return None
    except FileNotFoundError:
        print("Error: 'sops' command not found. Install SOPS or set PANGOLIN_API_KEY env var.")
        return None


def load_config(config_path: Path) -> dict:
    """Load configuration from YAML file."""
    with open(config_path) as f:
        return yaml.safe_load(f)


def load_resources(resources_path: Path) -> list[dict]:
    """Load resource definitions from YAML file."""
    with open(resources_path) as f:
        data = yaml.safe_load(f)
        return data.get("resources", [])


def build_desired_state(resources: list[dict], config: dict) -> dict[str, dict]:
    """Build desired state from resource definitions.

    Returns a dict mapping resource name to its full config.
    """
    default_suffix = config.get("default_suffix", "home.arpa")
    desired = {}

    for resource in resources:
        name = resource["name"]
        # Support both 'destination' (new) and 'ip' (legacy) field names
        destination = resource.get("destination", resource.get("ip", ""))
        port = resource.get("port", 80)

        # Build alias (FQDN for DNS)
        alias = resource.get("alias")
        if alias is None:
            alias = f"{name}.{default_suffix}"

        # Port configuration ("*" for all, or comma-separated list like "80,443")
        tcp_ports = resource.get("tcp_ports", "*")
        udp_ports = resource.get("udp_ports", "*")
        disable_icmp = resource.get("disable_icmp", False)

        desired[name] = {
            "name": name,
            "destination": destination,
            "alias": alias,
            "tcp_ports": tcp_ports,
            "udp_ports": udp_ports,
            "disable_icmp": disable_icmp,
            "enabled": resource.get("enabled", True),
        }

    return desired


def parse_current_state(resources: list[dict]) -> dict[str, dict]:
    """Parse current resources into name -> config mapping."""
    current = {}
    for resource in resources:
        name = resource.get("name", "")
        current[name] = {
            "id": resource.get("siteResourceId"),
            "siteId": resource.get("siteId"),
            "name": name,
            "destination": resource.get("destination", ""),
            "alias": resource.get("alias", ""),
            "tcp_ports": resource.get("tcpPortRangeString", ""),
            "udp_ports": resource.get("udpPortRangeString", ""),
            "disable_icmp": resource.get("disableIcmp", True),
            "enabled": resource.get("enabled", True),
        }
    return current


def resources_match(desired: dict, current: dict) -> bool:
    """Check if desired and current resource configs match."""
    return (
        desired["destination"] == current["destination"]
        and desired["alias"] == current["alias"]
        and desired["tcp_ports"] == current["tcp_ports"]
        and desired["udp_ports"] == current["udp_ports"]
        and desired["disable_icmp"] == current["disable_icmp"]
        and desired["enabled"] == current["enabled"]
    )


def cmd_list_clients(client: PangolinClient, config: dict) -> int:
    """List all clients in Pangolin."""
    org_id = config["org_id"]
    print(f"Organization: {org_id}")

    print("\nFetching clients...")
    clients = client.get_clients(org_id)

    if not clients:
        print("No clients found.")
        return 0

    print(f"\nClients ({len(clients)} total):")
    print("-" * 60)

    for c in sorted(clients, key=lambda x: x.get("name", "")):
        name = c.get("name", "unknown")
        client_id = c.get("clientId", "?")
        online = "online" if c.get("online") else "offline"
        print(f"  {name:<30} ID: {client_id:<10} ({online})")

    return 0


def cmd_list(client: PangolinClient, config: dict) -> int:
    """List current private resources in Pangolin."""
    site_name = config["site_name"]
    org_id = config["org_id"]
    print(f"Organization: {org_id}")

    print(f"Looking up site '{site_name}'...")
    site = client.get_site_by_name(org_id, site_name)
    if not site:
        print(f"Error: Site '{site_name}' not found")
        print("Available sites:")
        for s in client.get_sites(org_id):
            status = "online" if s.get("online") else "offline"
            print(f"  - {s.get('name', 'unknown')} ({status})")
        return 1

    site_id = site["siteId"]
    status = "online" if site.get("online") else "offline"
    print(f"Site: {site_name} (ID: {site_id}, {status})")

    print("\nFetching private resources...")
    resources = client.get_site_resources(org_id, site_id)

    if not resources:
        print("No private resources found for this site.")
        return 0

    print(f"\nCurrent private resources ({len(resources)} total):")
    print("-" * 80)

    sorted_resources = sorted(resources, key=lambda r: r.get("name", ""))
    for resource in sorted_resources:
        name = resource.get("name", "unknown")
        destination = resource.get("destination", "")
        alias = resource.get("alias", "")
        tcp_ports = resource.get("tcpPortRangeString", "")
        enabled = "enabled" if resource.get("enabled") else "disabled"

        alias_str = f" ({alias})" if alias else ""
        print(f"  {name:<25} -> {destination:<15} TCP:{tcp_ports:<10} {enabled}{alias_str}")

    return 0


def cmd_sync(
    client: PangolinClient,
    config: dict,
    resources: list[dict],
    dry_run: bool = False,
    clients_str: str | None = None,
    no_default_clients: bool = False,
    force_client_update: bool = False,
) -> int:
    """Sync local config with Pangolin."""
    site_name = config["site_name"]
    org_id = config["org_id"]
    print(f"Organization: {org_id}")

    # Build client list from defaults and command line
    client_ids: list[int] = []
    client_names: list[str] = []

    # Add default clients from config (unless disabled)
    default_clients = config.get("default_clients", []) or []
    if not no_default_clients and default_clients:
        client_names.extend(default_clients)

    # Add clients from command line
    if clients_str:
        cli_clients = [name.strip() for name in clients_str.split(",") if name.strip()]
        for name in cli_clients:
            if name not in client_names:
                client_names.append(name)

    # Look up all clients
    if client_names:
        print(f"Looking up {len(client_names)} client(s)...")
        for client_name in client_names:
            pangolin_client = client.get_client_by_name(org_id, client_name)
            if not pangolin_client:
                print(f"  Warning: Client '{client_name}' not found in Pangolin, skipping")
                continue
            client_ids.append(pangolin_client["clientId"])
            source = "(default)" if client_name in default_clients else "(cli)"
            print(f"  Client: {client_name} (ID: {pangolin_client['clientId']}) {source}")

    if force_client_update:
        if client_names:
            print(f"Force client update: will set clients to [{', '.join(client_names)}] on all resources")
        else:
            print("Force client update: will clear clients from all resources")

    print(f"Looking up site '{site_name}'...")
    site = client.get_site_by_name(org_id, site_name)
    if not site:
        print(f"Error: Site '{site_name}' not found")
        return 1

    site_id = site["siteId"]
    print(f"Site: {site_name} (ID: {site_id})")

    # Build desired state
    desired = build_desired_state(resources, config)
    print(f"\nDesired state: {len(desired)} resources")

    # Get current state
    print("Fetching current resources...")
    current_resources = client.get_site_resources(org_id, site_id)
    current = parse_current_state(current_resources)
    print(f"Current state: {len(current)} resources")

    # Calculate changes
    to_add = set(desired.keys()) - set(current.keys())
    to_delete = set(current.keys()) - set(desired.keys())
    existing = set(desired.keys()) & set(current.keys())

    if force_client_update:
        # Force update all existing resources to set clients
        to_update = existing
        to_update_clients_only = {
            name for name in existing
            if resources_match(desired[name], current[name])
        }
    else:
        to_update = {
            name for name in existing
            if not resources_match(desired[name], current[name])
        }
        to_update_clients_only = set()

    # Report changes
    print(f"\n{'Sync preview (dry-run)' if dry_run else 'Sync changes'}:")
    print("-" * 80)

    if not to_add and not to_update and not to_delete:
        print("No changes needed - already in sync!")
        return 0

    for name in sorted(to_add):
        d = desired[name]
        print(f"  [ADD]    {name:<25} -> {d['destination']}")

    for name in sorted(to_update):
        d = desired[name]
        c = current[name]
        changes = []
        if d["destination"] != c["destination"]:
            changes.append(f"dest:{c['destination']}->{d['destination']}")
        if d["alias"] != c["alias"]:
            changes.append(f"alias:{c['alias']}->{d['alias']}")
        if d["tcp_ports"] != c["tcp_ports"]:
            changes.append(f"tcp:{c['tcp_ports']}->{d['tcp_ports']}")
        if name in to_update_clients_only:
            changes.append("clients")
        print(f"  [UPDATE] {name:<25} ({', '.join(changes) if changes else 'clients only'})")

    for name in sorted(to_delete):
        print(f"  [DELETE] {name}")

    print(f"\nWould add: {len(to_add)}, update: {len(to_update)}, delete: {len(to_delete)}")

    if dry_run:
        print("\nDry-run mode - no changes applied.")
        return 0

    # Apply changes
    print("\nApplying changes...")
    errors = 0

    # Delete first
    for name in sorted(to_delete):
        try:
            print(f"  Deleting {name}...", end=" ")
            resource_id = current[name]["id"]
            client.delete_site_resource(resource_id)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then add
    for name in sorted(to_add):
        try:
            d = desired[name]
            print(f"  Adding {name} -> {d['destination']}...", end=" ")
            client.create_site_resource(
                org_id=org_id,
                name=name,
                site_id=site_id,
                mode="host",
                destination=d["destination"],
                alias=d["alias"],
                tcp_ports=d["tcp_ports"],
                udp_ports=d["udp_ports"],
                disable_icmp=d["disable_icmp"],
                enabled=d["enabled"],
                client_ids=client_ids,
            )
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then update
    for name in sorted(to_update):
        try:
            d = desired[name]
            c = current[name]
            print(f"  Updating {name}...", end=" ")
            resource_id = c["id"]
            client.update_site_resource(
                resource_id=resource_id,
                site_id=c["siteId"],
                destination=d["destination"],
                alias=d["alias"],
                tcp_ports=d["tcp_ports"],
                udp_ports=d["udp_ports"],
                disable_icmp=d["disable_icmp"],
                enabled=d["enabled"],
                client_ids=client_ids,
            )
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    if errors:
        print(f"\nCompleted with {errors} errors")
        return 1

    print("\nSync completed successfully!")
    return 0


def cmd_purge(
    client: PangolinClient,
    config: dict,
    dry_run: bool = False,
) -> int:
    """Delete all private resources for the site."""
    site_name = config["site_name"]
    org_id = config["org_id"]
    print(f"Organization: {org_id}")

    print(f"Looking up site '{site_name}'...")
    site = client.get_site_by_name(org_id, site_name)
    if not site:
        print(f"Error: Site '{site_name}' not found")
        return 1

    site_id = site["siteId"]
    print(f"Site: {site_name} (ID: {site_id})")

    print("\nFetching resources...")
    resources = client.get_site_resources(org_id, site_id)

    if not resources:
        print("No resources found - nothing to delete.")
        return 0

    print(f"\nFound {len(resources)} resources to delete:")
    print("-" * 80)
    for resource in sorted(resources, key=lambda r: r.get("name", "")):
        print(f"  [DELETE] {resource.get('name', 'unknown')}")

    if dry_run:
        print(f"\nDry-run mode - would delete {len(resources)} resources.")
        return 0

    print(f"\nDeleting {len(resources)} resources...")
    errors = 0

    for resource in sorted(resources, key=lambda r: r.get("name", "")):
        name = resource.get("name", "unknown")
        resource_id = resource.get("siteResourceId")
        try:
            print(f"  Deleting {name}...", end=" ")
            client.delete_site_resource(resource_id)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    if errors:
        print(f"\nCompleted with {errors} errors")
        return 1

    print("\nPurge completed successfully!")
    return 0


def find_repo_root() -> Path:
    """Find the repository root by looking for .git directory."""
    current = Path(__file__).resolve().parent
    while current != current.parent:
        if (current / ".git").exists():
            return current
        current = current.parent
    return Path(__file__).resolve().parent.parent.parent


def main():
    repo_root = find_repo_root()
    default_token_file = repo_root / "secrets" / "pangolin-creds.enc.yaml"

    parser = argparse.ArgumentParser(
        description="Manage Pangolin private resources for homelab services"
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).parent / "config.yaml",
        help="Path to config.yaml",
    )
    parser.add_argument(
        "--resources",
        type=Path,
        default=Path(__file__).parent / "resources.yaml",
        help="Path to resources.yaml",
    )
    parser.add_argument(
        "--token-file",
        type=Path,
        default=default_token_file,
        help="Path to SOPS-encrypted credentials file (default: secrets/pangolin-creds.enc.yaml)",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # list command
    subparsers.add_parser("list", help="List current private resources in Pangolin")

    # list-clients command
    subparsers.add_parser("list-clients", help="List all clients in Pangolin")

    # sync command
    sync_parser = subparsers.add_parser("sync", help="Sync local config with Pangolin")
    sync_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without applying",
    )
    sync_parser.add_argument(
        "--clients",
        type=str,
        help="Associate resources with clients (comma-separated names, e.g., --clients Messi,Ronaldo)",
    )
    sync_parser.add_argument(
        "--no-default-clients",
        action="store_true",
        help="Skip default clients from config.yaml",
    )
    sync_parser.add_argument(
        "--force-client-update",
        action="store_true",
        help="Force update all resources with the specified clients (or clear if no --clients)",
    )

    # purge command
    purge_parser = subparsers.add_parser("purge", help="Delete all private resources for the site")
    purge_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview deletions without applying",
    )
    purge_parser.add_argument(
        "--confirm",
        action="store_true",
        help="Required flag to confirm deletion",
    )

    args = parser.parse_args()

    # Get API key (env var takes precedence, then SOPS file)
    api_key = os.environ.get("PANGOLIN_API_KEY")
    if not api_key:
        if args.token_file.exists():
            print(f"Loading API key from {args.token_file}...")
            api_key = load_token_from_sops(args.token_file)

    if not api_key:
        print("Error: No API key found")
        print("Options:")
        print(f"  1. Add pangolin_api_key to SOPS-encrypted file: {args.token_file}")
        print("  2. Set PANGOLIN_API_KEY environment variable")
        print("  3. Use --token-file to specify a different file")
        sys.exit(1)

    # Load config
    if not args.config.exists():
        print(f"Error: Config file not found: {args.config}")
        sys.exit(1)

    config = load_config(args.config)
    client = PangolinClient(api_key, config.get("pangolin_url", "https://pangolin.home-infra.net"))

    # Execute command
    if args.command == "list":
        sys.exit(cmd_list(client, config))
    elif args.command == "list-clients":
        sys.exit(cmd_list_clients(client, config))
    elif args.command == "sync":
        if not args.resources.exists():
            print(f"Error: Resources file not found: {args.resources}")
            sys.exit(1)
        resources = load_resources(args.resources)
        sys.exit(cmd_sync(client, config, resources, args.dry_run, args.clients, args.no_default_clients, args.force_client_update))
    elif args.command == "purge":
        if not args.dry_run and not args.confirm:
            print("Error: Purge requires --confirm flag (or use --dry-run to preview)")
            print("Usage: ./pangolin-resources.py purge --confirm")
            sys.exit(1)
        sys.exit(cmd_purge(client, config, args.dry_run))


if __name__ == "__main__":
    main()
