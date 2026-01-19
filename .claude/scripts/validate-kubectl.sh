#!/usr/bin/env bash
# validate-kubectl.sh - Safety validation for kubectl commands
# Exit codes:
#   0 = Allow (pass through)
#   2 = Block (hard block or request confirmation)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if not a kubectl command
if [[ ! "$COMMAND" =~ kubectl ]]; then
    exit 0
fi

# Project directory for context
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

# === HARD BLOCKS (exit 2 with stderr message) ===

# Block: kubectl delete namespace
if echo "$COMMAND" | grep -qE 'kubectl\s+delete\s+namespace'; then
    echo "BLOCKED: 'kubectl delete namespace' destroys entire namespace and all resources. This operation is not allowed." >&2
    exit 2
fi

# Block: kubectl delete ns (short form)
if echo "$COMMAND" | grep -qE 'kubectl\s+delete\s+ns\s'; then
    echo "BLOCKED: 'kubectl delete ns' destroys entire namespace and all resources. This operation is not allowed." >&2
    exit 2
fi

# Block: kubectl delete pv (persistent volume)
if echo "$COMMAND" | grep -qE 'kubectl\s+delete\s+pv\b'; then
    echo "BLOCKED: 'kubectl delete pv' permanently destroys persistent volume data. This operation is not allowed." >&2
    exit 2
fi

# Block: kubectl delete pvc --all
if echo "$COMMAND" | grep -qE 'kubectl\s+delete\s+pvc.*--all'; then
    echo "BLOCKED: 'kubectl delete pvc --all' causes bulk data loss. This operation is not allowed." >&2
    exit 2
fi

# === CONFIRMATION REQUIRED (exit 0 with JSON asking for permission) ===

# Confirm: kubectl delete (other resources)
if echo "$COMMAND" | grep -qE 'kubectl\s+delete\s'; then
    RESOURCE=$(echo "$COMMAND" | grep -oE 'kubectl\s+delete\s+\S+' | awk '{print $3}')
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "kubectl delete '$RESOURCE' - Please confirm this deletion is intentional."
  }
}
EOF
    exit 0
fi

# Confirm: kubectl scale to 0 replicas
if echo "$COMMAND" | grep -qE 'kubectl\s+scale.*replicas[=\s]+0'; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Scaling to 0 replicas will cause service outage. Please confirm."
  }
}
EOF
    exit 0
fi

# Confirm: kubectl drain
if echo "$COMMAND" | grep -qE 'kubectl\s+drain\s'; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "kubectl drain will evict all pods from the node. Please confirm."
  }
}
EOF
    exit 0
fi

# Confirm: kubectl cordon
if echo "$COMMAND" | grep -qE 'kubectl\s+cordon\s'; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "kubectl cordon will prevent new pods from scheduling on the node. Please confirm."
  }
}
EOF
    exit 0
fi

# All other kubectl commands pass through
exit 0
