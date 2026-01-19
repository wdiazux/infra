#!/usr/bin/env bash
# session-init.sh - Initialize Claude Code session with project context
# Sets environment variables and provides project context

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Set KUBECONFIG environment variable for the session
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "export KUBECONFIG=\"${CWD}/terraform/talos/kubeconfig\"" >> "$CLAUDE_ENV_FILE"
fi

# Return context information for Claude
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "INFRASTRUCTURE PROJECT CONTEXT:\n\n- Single-node homelab on Proxmox VE 9.0\n- Primary platform: Talos Linux (Kubernetes)\n- Network: 10.10.2.0/24 (Infrastructure)\n- KUBECONFIG: terraform/talos/kubeconfig\n\nKey IP ranges:\n- 10.10.2.1-10: Core infrastructure\n- 10.10.2.11-20: Management services\n- 10.10.2.21-150: Applications (LoadBalancer pool)\n- 10.10.2.151-254: Traditional VMs\n\nCustom commands available:\n- /k8s-status - Cluster health check\n- /tf-plan - Terraform plan workflow\n- /tf-apply - Terraform apply workflow\n- /deploy-service - New service deployment\n- /update-service - Update existing service\n- /debug - Systematic troubleshooting\n\nSafety hooks active for kubectl and terraform commands."
  }
}
EOF

exit 0
