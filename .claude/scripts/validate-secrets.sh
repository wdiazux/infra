#!/usr/bin/env bash
# validate-secrets.sh - Prevent accidental secret exposure
# Exit codes:
#   0 = Allow (pass through, may include warnings on stderr)
#   2 = Block (only for clear violations)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip empty commands
if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# === ALLOW: Proper secret handling ===

# Allow sops decryption (proper way to handle secrets)
if echo "$COMMAND" | grep -qE 'sops\s+(-d|--decrypt|edit)'; then
    exit 0
fi

# === WARNINGS (stderr but allow) ===

# Warn: cat on .env files
if echo "$COMMAND" | grep -qE 'cat\s+.*\.env'; then
    echo "WARNING: Reading .env file may expose secrets. Consider using 'sops -d' for encrypted files." >&2
    exit 0
fi

# Warn: cat on files with 'secret' in the name
if echo "$COMMAND" | grep -qiE 'cat\s+.*secret'; then
    echo "WARNING: Reading file with 'secret' in the name. Ensure this won't expose sensitive data." >&2
    exit 0
fi

# Warn: cat on credential files
if echo "$COMMAND" | grep -qiE 'cat\s+.*(credential|password|token|apikey|api_key|api-key)'; then
    echo "WARNING: Reading potential credential file. Ensure this won't expose sensitive data." >&2
    exit 0
fi

# Warn: grep for secrets (might print them)
if echo "$COMMAND" | grep -qiE 'grep\s+.*(password|secret|token|apikey|api_key|api-key|credential)'; then
    echo "WARNING: Searching for sensitive patterns. Output may contain secrets." >&2
    exit 0
fi

# Warn: echo with potential secrets (environment variable expansion)
if echo "$COMMAND" | grep -qiE 'echo\s+.*\$(PASSWORD|SECRET|TOKEN|API_KEY|APIKEY|CREDENTIAL)'; then
    echo "WARNING: Echoing potential secret variable. This may expose sensitive data in logs." >&2
    exit 0
fi

# Warn: printenv for specific secret variables
if echo "$COMMAND" | grep -qiE 'printenv\s+(PASSWORD|SECRET|TOKEN|API_KEY|APIKEY|CREDENTIAL)'; then
    echo "WARNING: Printing environment variable that may contain secrets." >&2
    exit 0
fi

# === BLOCKS ===

# Block: Committing unencrypted secret files
if echo "$COMMAND" | grep -qE 'git\s+add\s+.*\.env[^.]'; then
    # Allow .env.example but block .env
    if ! echo "$COMMAND" | grep -qE '\.env\.(example|sample|template)'; then
        echo "BLOCKED: Adding .env file to git. Use SOPS encryption or add to .gitignore." >&2
        exit 2
    fi
fi

# Block: Committing files in secrets/ that aren't encrypted (.enc.yaml)
if echo "$COMMAND" | grep -qE 'git\s+add\s+.*secrets/.*\.yaml'; then
    if ! echo "$COMMAND" | grep -qE '\.enc\.yaml'; then
        echo "BLOCKED: Adding unencrypted yaml to secrets/. Files must be encrypted with SOPS (.enc.yaml)." >&2
        exit 2
    fi
fi

# All other commands pass through
exit 0
