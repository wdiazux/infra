#!/usr/bin/env python3
"""
ControlD DNS Management Script

Manages DNS domains in ControlD for homelab services.
Creates rules that redirect *.home-infra.net and *.home.arpa to local IPs.

Supports syncing to multiple profiles (e.g., Default, Infra, IoT).

Usage:
    # List all profiles
    ./scripts/controld/controld-dns.py list

    # List specific profile
    ./scripts/controld/controld-dns.py list --profile Default

    # Sync to all profiles (defined in config.yaml)
    ./scripts/controld/controld-dns.py sync --dry-run
    ./scripts/controld/controld-dns.py sync

    # Sync to specific profiles only
    ./scripts/controld/controld-dns.py sync --profile Default,Infra

    # Purge all profiles
    ./scripts/controld/controld-dns.py purge --confirm --dry-run

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
    """Load configuration from YAML file.

    Normalizes both single-profile and multi-profile configs into
    a standard format with a 'profiles' list.

    Single-profile format (backward compatible):
        profile_name: Default
        folder_name: home-infra
        suffixes: [home.arpa]

    Multi-profile format:
        profiles:
          - name: Default
            folder_name: home-infra
          - name: Infra
            folder_name: home-infra
        suffixes: [home.arpa]

    Returns:
        Dict with keys: api_base_url, profiles (list), suffixes (list)
    """
    with open(config_path) as f:
        raw_config = yaml.safe_load(f)

    # Detect mode and normalize to profiles list
    if "profiles" in raw_config:
        # Multi-profile mode
        profiles = raw_config["profiles"]
        if not isinstance(profiles, list) or len(profiles) == 0:
            raise ValueError("Config 'profiles' must be a non-empty list")
    elif "profile_name" in raw_config and "folder_name" in raw_config:
        # Single-profile mode (backward compatible)
        profiles = [{
            "name": raw_config["profile_name"],
            "folder_name": raw_config["folder_name"]
        }]
    else:
        raise ValueError(
            "Config must have either 'profiles' list or both "
            "'profile_name' and 'folder_name'"
        )

    return {
        "api_base_url": raw_config.get("api_base_url", "https://api.controld.com"),
        "profiles": profiles,
        "suffixes": raw_config.get("suffixes", []),
    }


def load_domains(domains_path: Path) -> list[dict]:
    """Load domain definitions from YAML file."""
    with open(domains_path) as f:
        data = yaml.safe_load(f)
        return data.get("domains", [])


def parse_profile_filter(profile_arg: str | None) -> list[str]:
    """Parse --profile Default,Infra into list of profile names.

    Args:
        profile_arg: Comma-separated profile names or None

    Returns:
        List of profile names, empty list if None
    """
    if not profile_arg:
        return []
    return [p.strip() for p in profile_arg.split(",")]


def filter_profiles(all_profiles: list[dict], filter_names: list[str]) -> list[dict]:
    """Filter profiles by names.

    Args:
        all_profiles: List of profile config dicts with 'name' key
        filter_names: List of profile names to keep (empty = keep all)

    Returns:
        Filtered list of profile configs
    """
    if not filter_names:
        return all_profiles
    return [p for p in all_profiles if p["name"] in filter_names]


def build_desired_state(domains: list[dict], default_suffixes: list[str]) -> dict[str, str]:
    """Build desired state from domain definitions.

    Each domain can optionally specify:
    - suffixes: list of suffixes to use (overrides default_suffixes)
    - fqdn: fully qualified domain name (ignores suffixes entirely)
    """
    desired = {}
    for domain in domains:
        name = domain["name"]
        ip = domain["ip"]
        aliases = domain.get("aliases", [])

        # Determine which suffixes to use for this domain
        # Priority: fqdn > suffixes > default_suffixes
        if "fqdn" in domain:
            # Use exact FQDN (no suffix processing)
            fqdns = domain["fqdn"] if isinstance(domain["fqdn"], list) else [domain["fqdn"]]
            for fqdn in fqdns:
                desired[fqdn] = ip
        else:
            # Use per-domain suffixes or fall back to defaults
            suffixes = domain.get("suffixes", default_suffixes)

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


def list_single_profile(
    client: ControlDClient,
    profile_name: str,
    folder_name: str,
    multi_profile_mode: bool = False
) -> int:
    """List rules for a single profile.

    Args:
        client: ControlD API client
        profile_name: Profile name to list
        folder_name: Folder name within profile
        multi_profile_mode: If True, prefix output with [ProfileName]

    Returns:
        0 on success, 1 on error
    """
    prefix = f"[{profile_name}] " if multi_profile_mode else ""

    print(f"{prefix}Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"{prefix}Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"{prefix}Profile: {profile_name} (PK: {profile_id})")

    print(f"{prefix}Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"{prefix}Error: Folder '{folder_name}' not found")
        print(f"{prefix}Available folders:")
        for f in client.get_folders(profile_id):
            print(f"{prefix}  - {f.get('group', 'unknown')}")
        return 1

    folder_id = folder["PK"]
    print(f"{prefix}Folder: {folder_name} (PK: {folder_id})")

    print(f"\n{prefix}Fetching rules...")
    rules = client.get_rules(profile_id, folder_id)

    if not rules:
        print(f"{prefix}No rules found in this folder.")
        return 0

    print(f"\n{prefix}Current rules ({len(rules)} total):")
    print(f"{prefix}" + "-" * 60)

    # Sort by hostname
    sorted_rules = sorted(rules, key=lambda r: r.get("PK", ""))
    for rule in sorted_rules:
        hostname = rule.get("PK", "unknown")
        action = rule.get("action", {})
        action_type = ACTION_NAMES.get(action.get("do", -1), "unknown")
        via = action.get("via", "")
        status = "enabled" if action.get("status") == 1 else "disabled"

        if action_type == "spoof":
            print(f"{prefix}  {hostname:<40} -> {via:<15} ({action_type})")
        else:
            print(f"{prefix}  {hostname:<40} ({action_type}, {status})")

    return 0


def cmd_list(client: ControlDClient, config: dict, profile_filter: list[str]) -> int:
    """List current rules in ControlD for one or more profiles.

    Args:
        client: ControlD API client
        config: Normalized config with 'profiles' list
        profile_filter: List of profile names to list (empty = all)

    Returns:
        0 if all profiles succeeded, 1 if any failed
    """
    profiles = filter_profiles(config["profiles"], profile_filter)
    multi_profile_mode = len(config["profiles"]) > 1

    results = []
    for profile_config in profiles:
        if multi_profile_mode and len(results) > 0:
            print()  # Blank line between profiles

        result = list_single_profile(
            client,
            profile_config["name"],
            profile_config["folder_name"],
            multi_profile_mode
        )
        results.append((profile_config["name"], result == 0))

    # Print summary if multi-profile and multiple profiles processed
    if multi_profile_mode and len(profiles) > 1:
        print("\n" + "=" * 60)
        successes = sum(1 for _, success in results if success)
        failures = len(results) - successes
        print(f"Summary: {successes}/{len(results)} profiles succeeded")
        if failures > 0:
            failed_names = [name for name, success in results if not success]
            print(f"Failed profiles: {', '.join(failed_names)}")

    return 0 if all(success for _, success in results) else 1


def sync_single_profile(
    client: ControlDClient,
    profile_name: str,
    folder_name: str,
    suffixes: list[str],
    domains: list[dict],
    dry_run: bool,
    force: bool,
    multi_profile_mode: bool = False
) -> int:
    """Sync domains to a single profile.

    Args:
        client: ControlD API client
        profile_name: Profile name to sync
        folder_name: Folder name within profile
        suffixes: Default domain suffixes
        domains: Domain definitions
        dry_run: If True, preview without applying
        force: If True, recreate all rules
        multi_profile_mode: If True, prefix output with [ProfileName]

    Returns:
        0 on success, 1 on error
    """
    prefix = f"[{profile_name}] " if multi_profile_mode else ""

    print(f"{prefix}Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"{prefix}Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"{prefix}Profile: {profile_name} (PK: {profile_id})")

    print(f"{prefix}Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"{prefix}Error: Folder '{folder_name}' not found")
        return 1

    folder_id = folder["PK"]
    print(f"{prefix}Folder: {folder_name} (PK: {folder_id})")

    # Build desired state
    desired = build_desired_state(domains, suffixes)
    print(f"\n{prefix}Desired state: {len(desired)} rules")

    # Get current state
    print(f"{prefix}Fetching current rules...")
    rules = client.get_rules(profile_id, folder_id)
    current = parse_current_state(rules)
    print(f"{prefix}Current state: {len(current)} rules")

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
    print(f"\n{prefix}{'Sync preview (dry-run)' if dry_run else 'Sync changes'}:")
    print(f"{prefix}" + "-" * 60)

    if not to_add and not to_update and not to_delete:
        print(f"{prefix}No changes needed - already in sync!")
        return 0

    for hostname in sorted(to_add):
        print(f"{prefix}  [ADD]    {hostname:<40} -> {desired[hostname]}")

    for hostname in sorted(to_update):
        print(f"{prefix}  [UPDATE] {hostname:<40} -> {desired[hostname]} (was {current[hostname]})")

    for hostname in sorted(to_delete):
        print(f"{prefix}  [DELETE] {hostname}")

    print(f"\n{prefix}Would add: {len(to_add)}, update: {len(to_update)}, delete: {len(to_delete)}")

    if dry_run:
        print(f"\n{prefix}Dry-run mode - no changes applied.")
        return 0

    # Apply changes
    print(f"\n{prefix}Applying changes...")
    errors = 0

    # Delete first
    for hostname in sorted(to_delete):
        try:
            print(f"{prefix}  Deleting {hostname}...", end=" ")
            client.delete_rule(profile_id, hostname)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then add
    for hostname in sorted(to_add):
        try:
            print(f"{prefix}  Adding {hostname} -> {desired[hostname]}...", end=" ")
            client.create_rule(profile_id, hostname, desired[hostname], folder_id)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    # Then update
    for hostname in sorted(to_update):
        try:
            print(f"{prefix}  Updating {hostname} -> {desired[hostname]}...", end=" ")
            client.update_rule(profile_id, hostname, desired[hostname], folder_id)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    if errors:
        print(f"\n{prefix}Completed with {errors} errors")
        return 1

    print(f"\n{prefix}Sync completed successfully!")
    return 0


def cmd_sync(
    client: ControlDClient,
    config: dict,
    domains: list[dict],
    dry_run: bool = False,
    force: bool = False,
    profile_filter: list[str] = None,
) -> int:
    """Sync local config with ControlD for one or more profiles.

    Args:
        client: ControlD API client
        config: Normalized config with 'profiles' list
        domains: Domain definitions
        dry_run: If True, preview without applying
        force: If True, recreate all rules
        profile_filter: List of profile names to sync (empty = all)

    Returns:
        0 if all profiles succeeded, 1 if any failed
    """
    profiles = filter_profiles(config["profiles"], profile_filter or [])
    suffixes = config["suffixes"]
    multi_profile_mode = len(config["profiles"]) > 1

    # Announce profiles being synced
    if multi_profile_mode:
        profile_names = [p["name"] for p in profiles]
        print(f"Syncing to {len(profiles)} profile(s): {', '.join(profile_names)}\n")

    results = []
    for profile_config in profiles:
        if multi_profile_mode and len(results) > 0:
            print()  # Blank line between profiles

        result = sync_single_profile(
            client,
            profile_config["name"],
            profile_config["folder_name"],
            suffixes,
            domains,
            dry_run,
            force,
            multi_profile_mode
        )
        results.append((profile_config["name"], result == 0))

    # Print summary if multi-profile and multiple profiles processed
    if multi_profile_mode and len(profiles) > 1:
        print("\n" + "=" * 60)
        successes = sum(1 for _, success in results if success)
        failures = len(results) - successes
        print(f"Summary: {successes}/{len(results)} profiles succeeded")
        if failures > 0:
            failed_names = [name for name, success in results if not success]
            print(f"Failed profiles: {', '.join(failed_names)}")

    return 0 if all(success for _, success in results) else 1


def purge_single_profile(
    client: ControlDClient,
    profile_name: str,
    folder_name: str,
    dry_run: bool,
    multi_profile_mode: bool = False
) -> int:
    """Purge all rules from a single profile folder.

    Args:
        client: ControlD API client
        profile_name: Profile name to purge
        folder_name: Folder name within profile
        dry_run: If True, preview without deleting
        multi_profile_mode: If True, prefix output with [ProfileName]

    Returns:
        0 on success, 1 on error
    """
    prefix = f"[{profile_name}] " if multi_profile_mode else ""

    print(f"{prefix}Looking up profile '{profile_name}'...")
    profile = client.get_profile_by_name(profile_name)
    if not profile:
        print(f"{prefix}Error: Profile '{profile_name}' not found")
        return 1

    profile_id = profile["PK"]
    print(f"{prefix}Profile: {profile_name} (PK: {profile_id})")

    print(f"{prefix}Looking up folder '{folder_name}'...")
    folder = client.get_folder_by_name(profile_id, folder_name)
    if not folder:
        print(f"{prefix}Error: Folder '{folder_name}' not found")
        return 1

    folder_id = folder["PK"]
    print(f"{prefix}Folder: {folder_name} (PK: {folder_id})")

    print(f"\n{prefix}Fetching rules...")
    rules = client.get_rules(profile_id, folder_id)

    if not rules:
        print(f"{prefix}No rules found - nothing to delete.")
        return 0

    hostnames = [rule.get("PK", "") for rule in rules if rule.get("PK")]
    print(f"\n{prefix}Found {len(hostnames)} rules to delete:")
    print(f"{prefix}" + "-" * 60)
    for hostname in sorted(hostnames):
        print(f"{prefix}  [DELETE] {hostname}")

    if dry_run:
        print(f"\n{prefix}Dry-run mode - would delete {len(hostnames)} rules.")
        return 0

    print(f"\n{prefix}Deleting {len(hostnames)} rules...")
    errors = 0

    for hostname in sorted(hostnames):
        try:
            print(f"{prefix}  Deleting {hostname}...", end=" ")
            client.delete_rule(profile_id, hostname)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            errors += 1

    if errors:
        print(f"\n{prefix}Completed with {errors} errors")
        return 1

    print(f"\n{prefix}Purge completed successfully!")
    return 0


def cmd_purge(
    client: ControlDClient,
    config: dict,
    dry_run: bool = False,
    profile_filter: list[str] = None,
) -> int:
    """Delete all rules in folder(s) for one or more profiles.

    Args:
        client: ControlD API client
        config: Normalized config with 'profiles' list
        dry_run: If True, preview without deleting
        profile_filter: List of profile names to purge (empty = all)

    Returns:
        0 if all profiles succeeded, 1 if any failed
    """
    profiles = filter_profiles(config["profiles"], profile_filter or [])
    multi_profile_mode = len(config["profiles"]) > 1

    # Announce profiles being purged
    if multi_profile_mode:
        profile_names = [p["name"] for p in profiles]
        print(f"Purging {len(profiles)} profile(s): {', '.join(profile_names)}\n")

    results = []
    for profile_config in profiles:
        if multi_profile_mode and len(results) > 0:
            print()  # Blank line between profiles

        result = purge_single_profile(
            client,
            profile_config["name"],
            profile_config["folder_name"],
            dry_run,
            multi_profile_mode
        )
        results.append((profile_config["name"], result == 0))

    # Print summary if multi-profile and multiple profiles processed
    if multi_profile_mode and len(profiles) > 1:
        print("\n" + "=" * 60)
        successes = sum(1 for _, success in results if success)
        failures = len(results) - successes
        print(f"Summary: {successes}/{len(results)} profiles succeeded")
        if failures > 0:
            failed_names = [name for name, success in results if not success]
            print(f"Failed profiles: {', '.join(failed_names)}")

    return 0 if all(success for _, success in results) else 1


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
    list_parser = subparsers.add_parser("list", help="List current rules in ControlD")
    list_parser.add_argument(
        "--profile",
        type=str,
        help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
    )

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
    sync_parser.add_argument(
        "--profile",
        type=str,
        help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
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
    purge_parser.add_argument(
        "--profile",
        type=str,
        help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
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
        profile_filter = parse_profile_filter(getattr(args, "profile", None))
        sys.exit(cmd_list(client, config, profile_filter))
    elif args.command == "sync":
        if not args.domains.exists():
            print(f"Error: Domains file not found: {args.domains}")
            sys.exit(1)
        domains = load_domains(args.domains)
        profile_filter = parse_profile_filter(getattr(args, "profile", None))
        sys.exit(cmd_sync(client, config, domains, args.dry_run, args.force, profile_filter))
    elif args.command == "purge":
        if not args.dry_run and not args.confirm:
            print("Error: Purge requires --confirm flag (or use --dry-run to preview)")
            print("Usage: ./controld-dns.py purge --confirm")
            sys.exit(1)
        profile_filter = parse_profile_filter(getattr(args, "profile", None))
        sys.exit(cmd_purge(client, config, args.dry_run, profile_filter))


if __name__ == "__main__":
    main()
