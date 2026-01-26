#!/usr/bin/env bash
set -euo pipefail

# Create a repository in Forgejo
#
# Required environment variables:
#   FORGEJO_ADMIN_USER - Forgejo admin username
#   FORGEJO_ADMIN_PASS - Forgejo admin password
#   FORGEJO_IP         - Forgejo LoadBalancer IP
#   REPO_NAME          - Repository name to create
#   REPO_PRIVATE       - "true" or "false"

echo "Creating Forgejo repository: $REPO_NAME..."

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

# URL-encode variables to prevent injection
ENCODED_USER=$(printf '%s' "$FORGEJO_ADMIN_USER" | jq -sRr @uri)
ENCODED_REPO=$(printf '%s' "$REPO_NAME" | jq -sRr @uri)

# Check if repo already exists
REPO_CHECK=$(curl -s -o /dev/null -w "%{http_code}" \
  --netrc-file "$NETRC_FILE" \
  "http://$FORGEJO_HOST/api/v1/repos/$ENCODED_USER/$ENCODED_REPO")

if [ "$REPO_CHECK" = "200" ]; then
  echo "Repository already exists, skipping creation"
  exit 0
fi

# Create JSON payload safely using jq (prevents shell injection)
JSON_PAYLOAD=$(jq -n \
  --arg name "$REPO_NAME" \
  --argjson private "$REPO_PRIVATE" \
  '{name: $name, private: $private, description: "Infrastructure as Code managed by FluxCD"}')

# Create repository
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  --netrc-file "$NETRC_FILE" \
  -d "$JSON_PAYLOAD" \
  "http://$FORGEJO_HOST/api/v1/user/repos")

# Check response using jq for safe parsing
CREATED_NAME=$(echo "$RESPONSE" | jq -r '.name // empty')
if [ "$CREATED_NAME" = "$REPO_NAME" ]; then
  echo "Repository created successfully!"
else
  echo "WARNING: Repository creation response: $RESPONSE"
fi

# Enable Actions for the repository
echo "Enabling Actions for repository..."
curl -s -X PATCH \
  -H "Content-Type: application/json" \
  --netrc-file "$NETRC_FILE" \
  -d '{"has_actions": true}' \
  "http://$FORGEJO_HOST/api/v1/repos/$ENCODED_USER/$ENCODED_REPO" > /dev/null

echo "Actions enabled for repository"
