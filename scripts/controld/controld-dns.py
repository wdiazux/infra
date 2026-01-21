#!/usr/bin/env python3
"""
ControlD DNS Management Script

Manages DNS domains in ControlD for homelab services.
Creates rules that redirect *.home-infra.net and *.home.arpa to local IPs.

Usage:
    ./scripts/controld/controld-dns.py list
    ./scripts/controld/controld-dns.py sync --dry-run
    ./scripts/controld/controld-dns.py sync

Token is automatically loaded from secrets/controld-token.enc.yaml via SOPS.
Override with CONTROLD_API_TOKEN env var or --token-file argument.
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

# Action types
ACTION_BLOCK = 0
ACTION_BYPASS = 1
ACTION_SPOOF = 2
ACTION_REDIRECT = 3

ACTION_NAMES = {
    ACTION_BLOCK: "block",
    ACTION_BYPASS: "bypass",
    ACTION_SPOOF: "spoof",
    ACTION_REDIRECT: "redirect",
}


class ControlDClient:
    """Client for ControlD API."""

    def __init__(self, api_token: str, base_url: str = "https://api.controld.com"):
        self.api_token = api_token
        self.base_url = base_url.rstrip("/")
        self.max_retries = 3
        self.retry_delay = 2

    def _request(
        self, method: str, endpoint: str, data: dict | None = None
    ) -> dict:
        """Make an API request with retry logic."""
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Accept": "application/json",
        }

        body = None
        if data:
            headers["Content-Type"] = "application/x-www-form-urlencoded"
            body = urllib.parse.urlencode(data, doseq=True).encode()

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

    def get_profiles(self) -> list[dict]:
        """Get all profiles."""
        resp = self._request("GET", "/profiles")
        return resp.get("body", {}).get("profiles", [])

    def get_profile_by_name(self, name: str) -> dict | None:
        """Find a profile by name."""
        profiles = self.get_profiles()
        for profile in profiles:
            if profile.get("name") == name:
                return profile
        return None

    def get_folders(self, profile_id: str) -> list[dict]:
        """Get all folders (groups) in a profile."""
        resp = self._request("GET", f"/profiles/{profile_id}/groups")
        return resp.get("body", {}).get("groups", [])

    def get_folder_by_name(self, profile_id: str, name: str) -> dict | None:
        """Find a folder by name."""
        folders = self.get_folders(profile_id)
        for folder in folders:
            if folder.get("group") == name:
                return folder
        return None

    def get_rules(self, profile_id: str, folder_id: int = 0) -> list[dict]:
        """Get all rules in a folder."""
        endpoint = f"/profiles/{profile_id}/rules"
        if folder_id:
            endpoint = f"{endpoint}/{folder_id}"
        resp = self._request("GET", endpoint)
        return resp.get("body", {}).get("rules", [])

    def create_rule(
        self,
        profile_id: str,
        hostname: str,
        ip: str,
        folder_id: int = 0,
    ) -> dict:
        """Create a spoof rule."""
        data = {
            "hostnames[]": [hostname],
            "do": ACTION_SPOOF,
            "via": ip,
            "status": 1,
        }
        if folder_id:
            data["group"] = folder_id
        return self._request("POST", f"/profiles/{profile_id}/rules", data)

    def update_rule(
        self,
        profile_id: str,
        hostname: str,
        ip: str,
        folder_id: int = 0,
    ) -> dict:
        """Update an existing rule."""
        data = {
            "hostnames[]": [hostname],
            "do": ACTION_SPOOF,
            "via": ip,
            "status": 1,
        }
        if folder_id:
            data["group"] = folder_id
        return self._request("PUT", f"/profiles/{profile_id}/rules", data)

    def delete_rule(self, profile_id: str, hostname: str) -> dict:
        """Delete a rule by hostname."""
        return self._request("DELETE", f"/profiles/{profile_id}/rules/{hostname}")


def load_token_from_sops(token_file: Path) -> str | None:
    """Load API token from SOPS-encrypted file."""
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
        return data.get("token")
    except subprocess.CalledProcessError as e:
        print(f"Error decrypting token file: {e.stderr}")
        return None
    except FileNotFoundError:
        print("Error: 'sops' command not found. Install SOPS or set CONTROLD_API_TOKEN env var.")
        return None


def load_config(config_path: Path) -> dict:
    """Load configuration from YAML file."""
    with open(config_path) as f:
        return yaml.safe_load(f)


def load_domains(domains_path: Path) -> list[dict]:
    """Load domain definitions from YAML file."""
    with open(domains_path) as f:
        data = yaml.safe_load(f)
        return data.get("domains", [])


def build_desired_state(domains: list[dict], suffixes: list[str]) -> dict[str, str]:
    """Build desired state from domain definitions."""
    desired = {}
    for domain in domains:
        name = domain["name"]
        ip = domain["ip"]
        aliases = domain.get("aliases", [])

        # Add main name and aliases for each suffix
        for suffix in suffixes:
            desired[f"{name}.{suffix}"] = ip
            for alias in aliases:
                desired[f"{alias}.{suffix}"] = ip

    return desired


def parse_current_state(rules: list[dict]) -> dict[str, str]:
    """Parse current rules into hostname -> IP mapping."""
    current = {}
    for rule in rules:
        hostname = rule.get("PK", "")
        action = rule.get("action", {})
        if action.get("do") == ACTION_SPOOF and action.get("status") == 1:
            current[hostname] = action.get("via", "")
    return current


def cmd_list(client: ControlDClient, config: dict) -> int:
    """List current rules in ControlD."""
    profile_name = config["profile_name"]
    folder_name = config["folder_name"]

    print(f"Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"Profile: {profile_name} (PK: {profile_id})")

    print(f"Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"Error: Folder '{folder_name}' not found")
        print("Available folders:")
        for f in client.get_folders(profile_id):
            print(f"  - {f.get('group', 'unknown')}")
        return 1

    folder_id = folder["PK"]
    print(f"Folder: {folder_name} (PK: {folder_id})")

    print("\nFetching rules...")
    rules = client.get_rules(profile_id, folder_id)

    if not rules:
        print("No rules found in this folder.")
        return 0

    print(f"\nCurrent rules ({len(rules)} total):")
    print("-" * 60)

    # Sort by hostname
    sorted_rules = sorted(rules, key=lambda r: r.get("PK", ""))
    for rule in sorted_rules:
        hostname = rule.get("PK", "unknown")
        action = rule.get("action", {})
        action_type = ACTION_NAMES.get(action.get("do", -1), "unknown")
        via = action.get("via", "")
        status = "enabled" if action.get("status") == 1 else "disabled"

        if action_type == "spoof":
            print(f"  {hostname:<40} -> {via:<15} ({action_type})")
        else:
            print(f"  {hostname:<40} ({action_type}, {status})")

    return 0


def cmd_sync(
    client: ControlDClient,
    config: dict,
    domains: list[dict],
    dry_run: bool = False,
    force: bool = False,
) -> int:
    """Sync local config with ControlD."""
    profile_name = config["profile_name"]
    folder_name = config["folder_name"]
    suffixes = config["suffixes"]

    print(f"Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"Profile: {profile_name} (PK: {profile_id})")

    print(f"Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"Error: Folder '{folder_name}' not found")
        return 1

    folder_id = folder["PK"]
    print(f"Folder: {folder_name} (PK: {folder_id})")

    # Build desired state
    desired = build_desired_state(domains, suffixes)
    print(f"\nDesired state: {len(desired)} rules")

    # Get current state
    print("Fetching current rules...")
    rules = client.get_rules(profile_id, folder_id)
    current = parse_current_state(rules)
    print(f"Current state: {len(current)} rules")

    # Calculate changes
    if force:
        to_delete = set(current.keys())
        to_add = set(desired.keys())
        to_update = set()
    else:
        to_add = set(desired.keys()) - set(current.keys())
        to_delete = set(current.keys()) - set(desired.keys())
        to_update = {
            k for k in set(desired.keys()) & set(current.keys()) if desired[k] != current[k]
        }

    # Report changes
    print(f"\n{'Sync preview (dry-run)' if dry_run else 'Sync changes'}:")
    print("-" * 60)

    if not to_add and not to_update and not to_delete:
        print("No changes needed - already in sync!")
        return 0

    for hostname in sorted(to_add):
        print(f"  [ADD]    {hostname:<40} -> {desired[hostname]}")

    for hostname in sorted(to_update):
        print(f"  [UPDATE] {hostname:<40} -> {desired[hostname]} (was {current[hostname]})")

    for hostname in sorted(to_delete):
        print(f"  [DELETE] {hostname}")

    print(f"\nWould add: {len(to_add)}, update: {len(to_update)}, delete: {len(to_delete)}")

    if dry_run:
        print("\nDry-run mode - no changes applied.")
        return 0

    # Apply changes
    print("\nApplying changes...")
    errors = 0

    # Delete first
    for hostname in sorted(to_delete):
        try:
            print(f"  Deleting {hostname}...", end=" ")
            client.delete_rule(profile_id, hostname)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then add
    for hostname in sorted(to_add):
        try:
            print(f"  Adding {hostname} -> {desired[hostname]}...", end=" ")
            client.create_rule(profile_id, hostname, desired[hostname], folder_id)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then update
    for hostname in sorted(to_update):
        try:
            print(f"  Updating {hostname} -> {desired[hostname]}...", end=" ")
            client.update_rule(profile_id, hostname, desired[hostname], folder_id)
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
    client: ControlDClient,
    config: dict,
    dry_run: bool = False,
) -> int:
    """Delete all rules in the folder."""
    profile_name = config["profile_name"]
    folder_name = config["folder_name"]

    print(f"Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"Profile: {profile_name} (PK: {profile_id})")

    print(f"Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"Error: Folder '{folder_name}' not found")
        return 1

    folder_id = folder["PK"]
    print(f"Folder: {folder_name} (PK: {folder_id})")

    print("\nFetching rules...")
    rules = client.get_rules(profile_id, folder_id)

    if not rules:
        print("No rules found - nothing to delete.")
        return 0

    hostnames = [rule.get("PK", "") for rule in rules if rule.get("PK")]
    print(f"\nFound {len(hostnames)} rules to delete:")
    print("-" * 60)
    for hostname in sorted(hostnames):
        print(f"  [DELETE] {hostname}")

    if dry_run:
        print(f"\nDry-run mode - would delete {len(hostnames)} rules.")
        return 0

    print(f"\nDeleting {len(hostnames)} rules...")
    errors = 0

    for hostname in sorted(hostnames):
        try:
            print(f"  Deleting {hostname}...", end=" ")
            client.delete_rule(profile_id, hostname)
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
    default_token_file = repo_root / "secrets" / "controld-token.enc.yaml"

    parser = argparse.ArgumentParser(
        description="Manage ControlD DNS domains for homelab services"
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=Path(__file__).parent / "config.yaml",
        help="Path to config.yaml",
    )
    parser.add_argument(
        "--domains",
        type=Path,
        default=Path(__file__).parent / "domains.yaml",
        help="Path to domains.yaml",
    )
    parser.add_argument(
        "--token-file",
        type=Path,
        default=default_token_file,
        help="Path to SOPS-encrypted token file (default: secrets/controld-token.enc.yaml)",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # list command
    subparsers.add_parser("list", help="List current rules in ControlD")

    # sync command
    sync_parser = subparsers.add_parser("sync", help="Sync local config with ControlD")
    sync_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview changes without applying",
    )
    sync_parser.add_argument(
        "--force",
        action="store_true",
        help="Force recreate all rules",
    )

    # purge command
    purge_parser = subparsers.add_parser("purge", help="Delete all rules in the folder")
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

    # Get API token (env var takes precedence, then SOPS file)
    api_token = os.environ.get("CONTROLD_API_TOKEN")
    if not api_token:
        if args.token_file.exists():
            print(f"Loading token from {args.token_file}...")
            api_token = load_token_from_sops(args.token_file)

    if not api_token:
        print("Error: No API token found")
        print("Options:")
        print(f"  1. Create SOPS-encrypted file: {args.token_file}")
        print("  2. Set CONTROLD_API_TOKEN environment variable")
        print("  3. Use --token-file to specify a different file")
        sys.exit(1)

    # Load config
    if not args.config.exists():
        print(f"Error: Config file not found: {args.config}")
        sys.exit(1)

    config = load_config(args.config)
    client = ControlDClient(api_token, config.get("api_base_url", "https://api.controld.com"))

    # Execute command
    if args.command == "list":
        sys.exit(cmd_list(client, config))
    elif args.command == "sync":
        if not args.domains.exists():
            print(f"Error: Domains file not found: {args.domains}")
            sys.exit(1)
        domains = load_domains(args.domains)
        sys.exit(cmd_sync(client, config, domains, args.dry_run, args.force))
    elif args.command == "purge":
        if not args.dry_run and not args.confirm:
            print("Error: Purge requires --confirm flag (or use --dry-run to preview)")
            print("Usage: ./controld-dns.py purge --confirm")
            sys.exit(1)
        sys.exit(cmd_purge(client, config, args.dry_run))


if __name__ == "__main__":
    main()
