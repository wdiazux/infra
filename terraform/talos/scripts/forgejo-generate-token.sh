#!/usr/bin/env bash
set -euo pipefail

# Generate Forgejo access token for FluxCD
#
# Required environment variables:
#   FORGEJO_ADMIN_USER - Forgejo admin username
#   FORGEJO_ADMIN_PASS - Forgejo admin password
#   FORGEJO_IP         - Forgejo LoadBalancer IP
#   TOKEN_FILE         - Path to save the generated token

# Pre-flight checks
for cmd in curl jq; do
  if ! command -v $cmd &>/dev/null; then
    echo "ERROR: Required command '$cmd' not found. Install via nix-shell."
    exit 1
  fi
done

echo "Generating Forgejo access token for FluxCD..."

# Use LoadBalancer IP directly
FORGEJO_HOST="$FORGEJO_IP"

# Create temp netrc file with secure permissions from start (avoids race condition)
NETRC_FILE=$(umask 077 && mktemp)
cat > "$NETRC_FILE" << NETRC
machine $FORGEJO_HOST
login $FORGEJO_ADMIN_USER
password $FORGEJO_ADMIN_PASS
NETRC

# Cleanup on exit
trap "rm -f \"$NETRC_FILE\"" EXIT

# Token name with timestamp to avoid conflicts
TOKEN_NAME="flux-$(date +%Y%m%d-%H%M%S)"

# URL-encode the username to prevent injection
ENCODED_USER=$(printf '%s' "$FORGEJO_ADMIN_USER" | jq -sRr @uri)

# Create JSON payload safely using jq (prevents shell injection)
JSON_PAYLOAD=$(jq -n --arg name "$TOKEN_NAME" \
  '{name: $name, scopes: ["write:repository", "write:user", "read:user", "read:organization"]}')

# Create token via Forgejo API (using netrc for secure auth)
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  --netrc-file "$NETRC_FILE" \
  -d "$JSON_PAYLOAD" \
  "http://$FORGEJO_HOST/api/v1/users/$ENCODED_USER/tokens")

# Extract token (sha1 field)
TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "WARNING: Failed to create Forgejo token with name $TOKEN_NAME"
  echo "Response: $RESPONSE"

  # Check if token already exists (409 conflict)
  if echo "$RESPONSE" | grep -q "already exist"; then
    echo "Token with similar name may already exist. Trying with random suffix..."
    TOKEN_NAME="flux-$(date +%s)"
    JSON_PAYLOAD=$(jq -n --arg name "$TOKEN_NAME" \
      '{name: $name, scopes: ["write:repository", "write:user", "read:user", "read:organization"]}')
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      --netrc-file "$NETRC_FILE" \
      -d "$JSON_PAYLOAD" \
      "http://$FORGEJO_HOST/api/v1/users/$ENCODED_USER/tokens")
    TOKEN=$(echo "$RESPONSE" | jq -r '.sha1 // empty')
  fi

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "ERROR: Failed to create Forgejo token."
    exit 1
  fi
fi

# Save token to file for FluxCD bootstrap
echo "$TOKEN" > "$TOKEN_FILE"
chmod 600 "$TOKEN_FILE"

echo "Forgejo access token created successfully: $TOKEN_NAME"
