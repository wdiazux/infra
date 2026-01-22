# ControlD Multi-Profile Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add multi-profile support to controld-dns.py to sync identical domain lists to multiple ControlD profiles (Default, Infra, IoT).

**Architecture:** Extend load_config() to normalize single/multi-profile configs into a profiles list. Refactor cmd_list, cmd_sync, cmd_purge to iterate over profiles. Add --profile CLI filter. Prefix output with [ProfileName] in multi-profile mode.

**Tech Stack:** Python 3, PyYAML, ControlD API (existing)

---

## Task 1: Add Profile Filtering Utilities

**Files:**
- Modify: `scripts/controld/controld-dns.py:191-194`

**Step 1: Add parse_profile_filter function**

Add after `load_domains()` function (around line 202):

```python
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
```

**Step 2: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): add profile filtering utilities

Add parse_profile_filter() and filter_profiles() functions for
multi-profile support. These will enable --profile flag filtering.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Update load_config to Support Multi-Profile

**Files:**
- Modify: `scripts/controld/controld-dns.py:191-194`

**Step 1: Rewrite load_config function**

Replace the existing `load_config()` function (lines 191-194):

```python
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
```

**Step 2: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): normalize config to support multi-profile

Update load_config() to detect single vs multi-profile mode and
normalize both into a profiles list. Maintains backward compatibility
with existing single-profile config format.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Refactor cmd_list for Multi-Profile

**Files:**
- Modify: `scripts/controld/controld-dns.py:248-298`

**Step 1: Extract single-profile list logic**

Add new function before `cmd_list()` (around line 248):

```python
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
```

**Step 2: Rewrite cmd_list to iterate profiles**

Replace `cmd_list()` function (lines 248-298):

```python
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
```

**Step 3: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): refactor cmd_list for multi-profile

Extract list_single_profile() and update cmd_list() to iterate
over multiple profiles. Adds [ProfileName] prefix in multi-profile
mode and summary reporting.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Refactor cmd_sync for Multi-Profile

**Files:**
- Modify: `scripts/controld/controld-dns.py:301-415`

**Step 1: Extract single-profile sync logic**

Add new function before `cmd_sync()` (around line 301):

```python
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
```

**Step 2: Rewrite cmd_sync to iterate profiles**

Replace `cmd_sync()` function (lines 301-415):

```python
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
```

**Step 3: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): refactor cmd_sync for multi-profile

Extract sync_single_profile() and update cmd_sync() to iterate
over multiple profiles. Adds profile announcement, [ProfileName]
prefix, and summary reporting.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Refactor cmd_purge for Multi-Profile

**Files:**
- Modify: `scripts/controld/controld-dns.py:418-479`

**Step 1: Extract single-profile purge logic**

Add new function before `cmd_purge()` (around line 418):

```python
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
```

**Step 2: Rewrite cmd_purge to iterate profiles**

Replace `cmd_purge()` function (lines 418-479):

```python
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
```

**Step 3: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): refactor cmd_purge for multi-profile

Extract purge_single_profile() and update cmd_purge() to iterate
over multiple profiles. Adds profile announcement, [ProfileName]
prefix, and summary reporting.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Add --profile CLI Flag

**Files:**
- Modify: `scripts/controld/controld-dns.py:492-593`

**Step 1: Add --profile argument to subparsers**

In the `main()` function, add `--profile` argument to each subparser.

For `list` command (after line 521):

```python
# list command
list_parser = subparsers.add_parser("list", help="List current rules in ControlD")
list_parser.add_argument(
    "--profile",
    type=str,
    help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
)
```

For `sync` command (after line 534):

```python
sync_parser.add_argument(
    "--profile",
    type=str,
    help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
)
```

For `purge` command (after line 547):

```python
purge_parser.add_argument(
    "--profile",
    type=str,
    help="Target specific profile(s) (comma-separated, e.g., Default,Infra)",
)
```

**Step 2: Update command execution to pass profile_filter**

Update the command execution section (lines 574-588):

```python
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
```

**Step 3: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "feat(controld): add --profile CLI flag

Add --profile flag to list, sync, and purge commands to filter
which profiles to operate on. Supports comma-separated values
like --profile Default,Infra.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Update config.yaml for Multi-Profile

**Files:**
- Modify: `scripts/controld/config.yaml`

**Step 1: Replace config with multi-profile format**

Replace entire file content:

```yaml
# ControlD DNS Management Configuration
# Settings for the controld-dns.py script

api_base_url: https://api.controld.com

# Profiles to sync (same domains to all profiles)
profiles:
  - name: Default
    folder_name: home-infra
  - name: Infra
    folder_name: home-infra
  - name: IoT
    folder_name: home-infra

# Default domain suffixes for internal services
# Each service will get a DNS rule for each suffix unless overridden
# Use per-domain 'suffixes' in domains.yaml for external domains
suffixes:
  - home.arpa
```

**Step 2: Commit**

```bash
git add scripts/controld/config.yaml
git commit -m "feat(controld): enable multi-profile sync for Default, Infra, IoT

Update config.yaml to sync domains to three profiles: Default,
Infra, and IoT. All use the same folder (home-infra).

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Update Documentation

**Files:**
- Modify: `scripts/controld/controld-dns.py:1-15` (docstring)

**Step 1: Update script docstring**

Replace the module docstring (lines 2-15):

```python
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
```

**Step 2: Commit**

```bash
git add scripts/controld/controld-dns.py
git commit -m "docs(controld): update usage examples for multi-profile

Update module docstring with examples showing --profile flag and
multi-profile usage patterns.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Manual Testing

**Files:**
- None (testing only)

**Step 1: Test backward compatibility**

Create a test config with single-profile format:

```bash
cd scripts/controld
cat > test-single-profile.yaml <<'EOF'
api_base_url: https://api.controld.com
profile_name: Default
folder_name: home-infra
suffixes:
  - home.arpa
EOF
```

Run:
```bash
./controld-dns.py --config test-single-profile.yaml list --dry-run
```

Expected: Should work without [ProfileName] prefix, same as before

**Step 2: Test multi-profile list**

Run:
```bash
./controld-dns.py list
```

Expected:
- Lists all three profiles (Default, Infra, IoT)
- Output prefixed with [ProfileName]
- Summary at end

**Step 3: Test --profile filter**

Run:
```bash
./controld-dns.py list --profile Default
```

Expected:
- Lists only Default profile
- Still shows [Default] prefix since config has 3 profiles

**Step 4: Test multi-profile sync dry-run**

Run:
```bash
./controld-dns.py sync --dry-run
```

Expected:
- Shows sync preview for all 3 profiles
- Prefixed with [ProfileName]
- Summary showing 3/3 profiles

**Step 5: Test selective sync**

Run:
```bash
./controld-dns.py sync --profile IoT --dry-run
```

Expected:
- Shows sync preview for IoT only
- Still prefixed (multi-profile mode detected)

**Step 6: Clean up test file**

```bash
rm test-single-profile.yaml
```

**Step 7: Commit (if any test fixes needed)**

Only commit if bugs were found and fixed during testing.

---

## Task 10: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md` (if needed)

**Step 1: Check if CLAUDE.md mentions controld script**

Run:
```bash
grep -i "controld" CLAUDE.md
```

**Step 2: Update if relevant section exists**

If CLAUDE.md has a section about DNS or ControlD, update to mention multi-profile support.

Otherwise, skip this step.

**Step 3: Commit if changes made**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for controld multi-profile support

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Implementation Checklist

- [ ] Task 1: Add profile filtering utilities
- [ ] Task 2: Update load_config for multi-profile
- [ ] Task 3: Refactor cmd_list
- [ ] Task 4: Refactor cmd_sync
- [ ] Task 5: Refactor cmd_purge
- [ ] Task 6: Add --profile CLI flag
- [ ] Task 7: Update config.yaml
- [ ] Task 8: Update documentation
- [ ] Task 9: Manual testing
- [ ] Task 10: Update CLAUDE.md (if applicable)

## Testing Strategy

1. **Unit-level:** Test each refactored function independently
2. **Integration:** Test full commands with both config formats
3. **Regression:** Verify single-profile mode still works
4. **Multi-profile:** Verify all 3 profiles sync correctly

## Success Criteria

- [ ] Backward compatible with single-profile config
- [ ] Syncs to Default, Infra, IoT profiles simultaneously
- [ ] `--profile` flag filters correctly
- [ ] Output prefixed with [ProfileName] in multi-profile mode
- [ ] Summary reports success/failure across profiles
- [ ] Exit code 0 only if ALL profiles succeed
- [ ] No breaking changes to existing scripts/automation

---

**Estimated Time:** 60-90 minutes

**Dependencies:** None (uses existing Python stdlib + PyYAML)

**Risk Areas:**
- Profile lookup failures (API changes)
- Output formatting edge cases
- Config parsing with unexpected formats

**Rollback Plan:** Revert config.yaml to single-profile format if issues arise
