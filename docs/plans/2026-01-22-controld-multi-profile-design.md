# ControlD Multi-Profile Support Design

**Date:** 2026-01-22
**Status:** Approved

## Overview

Extend the ControlD DNS management script to support syncing the same domain list to multiple profiles (Default, Infra, IoT). This enables managing consistent DNS rules across different device profiles in ControlD.

## Requirements

- Sync identical domain lists to multiple ControlD profiles
- Maintain backward compatibility with single-profile mode
- Support selective profile targeting via CLI flag
- Use same folder name across all profiles (home-infra)
- Continue on error - report summary at end

## Target Profiles

- **Default** - Main profile for home network
- **Infra** - Infrastructure devices profile
- **IoT** - IoT devices profile

All profiles will use the same folder: `home-infra`

## Configuration Changes

### Backward Compatible Single-Profile (Current)

```yaml
api_base_url: https://api.controld.com
profile_name: Default
folder_name: home-infra
suffixes:
  - home.arpa
```

### New Multi-Profile Format

```yaml
api_base_url: https://api.controld.com

# List of profiles to sync (replaces profile_name when defined)
profiles:
  - name: Default
    folder_name: home-infra
  - name: Infra
    folder_name: home-infra
  - name: IoT
    folder_name: home-infra

# Default suffixes apply to all profiles
suffixes:
  - home.arpa
```

**Configuration logic:**
- If `profiles:` key exists → multi-profile mode
- If only `profile_name:` exists → single-profile mode (backward compatible)
- `suffixes:` shared across all profiles

## CLI Interface

### Single-Profile Mode (Unchanged)

```bash
./controld-dns.py list              # Lists rules from single profile
./controld-dns.py sync --dry-run    # Syncs to single profile
./controld-dns.py purge --confirm   # Purges single profile
```

### Multi-Profile Mode

```bash
# Sync to ALL profiles defined in config.yaml
./controld-dns.py sync --dry-run
./controld-dns.py sync

# Target specific profile(s) only
./controld-dns.py sync --profile Default
./controld-dns.py sync --profile Default,Infra
./controld-dns.py list --profile IoT

# List all profiles (default in multi-profile mode)
./controld-dns.py list
```

**New CLI options:**
- `--profile PROFILE[,PROFILE...]` - Target specific profile(s)
  - Single-profile mode: ignored
  - Multi-profile mode: filters which profiles to process
  - Default: all profiles in config

## Sync Workflow

### Processing Steps

1. **Parse configuration** - Detect single vs multi-profile mode
2. **Build profile list** - From `profiles:` array or single `profile_name`
3. **Filter by --profile flag** - If provided, only process matching profiles
4. **Validate profiles exist** - Upfront validation before starting sync
5. **Process each profile sequentially**:
   - Lookup profile and folder in ControlD API
   - Build desired state (same domains for all)
   - Fetch current rules
   - Calculate diff (add/update/delete)
   - Display changes with `[ProfileName]` prefix
   - Apply changes (unless dry-run)
6. **Report summary** - Overall success/failure across all profiles

### Error Handling

**Continue processing on failure:**
```
Syncing to 3 profiles: Default, Infra, IoT

[Default] Looking up profile...
[Default] Folder: home-infra (PK: 12345)
[Default] Would add: 45, update: 0, delete: 2
[Default] ✓ Sync completed

[Infra] Looking up profile...
[Infra] Error: Profile 'Infra' not found
[Infra] ✗ Sync failed

[IoT] Looking up profile...
[IoT] Folder: home-infra (PK: 67890)
[IoT] Would add: 45, update: 0, delete: 0
[IoT] ✓ Sync completed

Summary: 2/3 profiles succeeded, 1 failed
Failed profiles: Infra
```

**Exit codes:**
- 0 - All profiles succeeded
- 1 - One or more profiles failed

## Output Formatting

### Multi-Profile Mode

All output prefixed with `[ProfileName]`:
```
[Default] Looking up profile 'Default'...
[Default] Profile: Default (PK: abc123)
[Default] Folder: home-infra (PK: 12345)
[Default] Sync completed successfully!

[Infra] Looking up profile 'Infra'...
[Infra] Profile: Infra (PK: def456)
...
```

### Single-Profile Mode (Unchanged)

No prefix, same as current behavior:
```
Looking up profile 'Default'...
Profile: Default (PK: abc123)
Folder: home-infra (PK: 12345)
Sync completed successfully!
```

## Implementation Details

### Code Changes

**config loading:**
```python
def load_config(config_path: Path) -> dict:
    config = yaml.safe_load(...)

    # Detect mode and normalize to profiles list
    if "profiles" in config:
        # Multi-profile mode
        profiles = config["profiles"]
    elif "profile_name" in config:
        # Single-profile mode (backward compatible)
        profiles = [{
            "name": config["profile_name"],
            "folder_name": config["folder_name"]
        }]
    else:
        raise ValueError("Config must have 'profiles' or 'profile_name'")

    return {
        "api_base_url": config.get("api_base_url"),
        "profiles": profiles,
        "suffixes": config.get("suffixes", [])
    }
```

**profile filtering:**
```python
def parse_profile_filter(profile_arg: str) -> list[str]:
    """Parse --profile Default,Infra into list."""
    if not profile_arg:
        return []
    return [p.strip() for p in profile_arg.split(",")]

def filter_profiles(all_profiles: list, filter_names: list) -> list:
    """Filter profiles by names. Empty filter = all profiles."""
    if not filter_names:
        return all_profiles
    return [p for p in all_profiles if p["name"] in filter_names]
```

**sync command update:**
```python
def cmd_sync(client, config, domains, dry_run, force, profile_filter):
    profiles = config["profiles"]

    # Filter profiles if --profile specified
    if profile_filter:
        profiles = filter_profiles(profiles, profile_filter)

    # Track results
    results = []

    for profile_config in profiles:
        name = profile_config["name"]
        folder = profile_config["folder_name"]

        try:
            result = sync_single_profile(
                client, name, folder, config["suffixes"],
                domains, dry_run, force
            )
            results.append((name, True, result))
        except Exception as e:
            results.append((name, False, str(e)))

    # Print summary
    print_summary(results)

    # Exit 1 if any failures
    return 0 if all(success for _, success, _ in results) else 1
```

## Migration Path

### For Existing Users

**Current config.yaml:**
```yaml
profile_name: Default
folder_name: home-infra
suffixes:
  - home.arpa
```

**To enable multi-profile, replace with:**
```yaml
profiles:
  - name: Default
    folder_name: home-infra
  - name: Infra
    folder_name: home-infra
  - name: IoT
    folder_name: home-infra
suffixes:
  - home.arpa
```

No code changes needed - just config file update.

## Testing Plan

1. **Backward compatibility:**
   - Test with old config format (profile_name)
   - Verify single-profile mode works unchanged

2. **Multi-profile mode:**
   - Test sync to all 3 profiles
   - Test --profile flag filtering
   - Test with one profile missing (error handling)
   - Test dry-run with multiple profiles

3. **Edge cases:**
   - Config with both `profiles` and `profile_name` (profiles wins)
   - Empty profiles list
   - Invalid profile names in --profile flag

## Dependencies

No new dependencies required. Uses existing:
- Python 3 standard library
- PyYAML (already in nix-shell)
- SOPS (for token decryption)

---

**Last Updated:** 2026-01-22
