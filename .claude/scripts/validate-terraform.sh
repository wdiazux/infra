#!/usr/bin/env bash
# validate-terraform.sh - Safety validation for terraform commands
# Exit codes:
#   0 = Allow (pass through)
#   2 = Block (hard block)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if not a terraform command
if [[ ! "$COMMAND" =~ terraform ]]; then
    exit 0
fi

# === HARD BLOCKS (exit 2 with stderr message) ===

# Block: terraform destroy (any form)
if echo "$COMMAND" | grep -qE 'terraform\s+destroy'; then
    echo "BLOCKED: 'terraform destroy' is not allowed. This would destroy all infrastructure." >&2
    echo "If you need to remove specific resources, use 'terraform state rm' or modify the configuration." >&2
    exit 2
fi

# Block: terraform apply -destroy
if echo "$COMMAND" | grep -qE 'terraform\s+apply.*-destroy'; then
    echo "BLOCKED: 'terraform apply -destroy' is not allowed. This would destroy all infrastructure." >&2
    exit 2
fi

# === WARNINGS (stderr but allow) ===

# Warn: terraform apply -auto-approve
if echo "$COMMAND" | grep -qE 'terraform\s+apply.*-auto-approve'; then
    echo "WARNING: Using -auto-approve bypasses the review step. Make sure you have reviewed the plan." >&2
    exit 0
fi

# === CONFIRMATION REQUIRED ===

# Confirm: terraform apply (without plan file and without -auto-approve)
if echo "$COMMAND" | grep -qE 'terraform\s+apply\s*$'; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "terraform apply without a plan file. Consider running 'terraform plan -out=tfplan' first, then 'terraform apply tfplan'."
  }
}
EOF
    exit 0
fi

# Confirm: terraform apply with plan file
if echo "$COMMAND" | grep -qE 'terraform\s+apply\s+\S+'; then
    # Check if it looks like a plan file (not a flag)
    APPLY_ARG=$(echo "$COMMAND" | grep -oE 'terraform\s+apply\s+\S+' | awk '{print $3}')
    if [[ ! "$APPLY_ARG" =~ ^- ]]; then
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "terraform apply with plan file '$APPLY_ARG'. Please confirm you have reviewed the plan."
  }
}
EOF
        exit 0
    fi
fi

# All other terraform commands pass through (plan, init, validate, fmt, state list/show, etc.)
exit 0
