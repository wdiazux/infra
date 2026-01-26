#!/usr/bin/env bash
set -euo pipefail

# Push local infra repository to Forgejo
#
# Required environment variables:
#   GIT_USER   - Forgejo username
#   GIT_TOKEN  - Forgejo access token
#   FORGEJO_IP - Forgejo LoadBalancer IP
#   REPO_NAME  - Repository name
#   GIT_BRANCH - Target branch name
#   REPO_ROOT  - Path to the git repository root

echo "=== Pushing local infra repository to Forgejo ==="

cd "$REPO_ROOT"

# Verify we're in a git repo
if [ ! -d ".git" ]; then
  echo "ERROR: Not in a git repository. Cannot push to Forgejo."
  exit 1
fi

# Forgejo URL for git operations (using token auth on port 80)
FORGEJO_URL="http://$GIT_USER:$GIT_TOKEN@$FORGEJO_IP/$GIT_USER/$REPO_NAME.git"

# Check if forgejo remote already exists
if git remote get-url forgejo &>/dev/null; then
  echo "Remote 'forgejo' already exists, updating URL..."
  git remote set-url forgejo "$FORGEJO_URL"
else
  echo "Adding 'forgejo' remote..."
  git remote add forgejo "$FORGEJO_URL"
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Ensure we have commits to push
if ! git rev-parse HEAD &>/dev/null; then
  echo "ERROR: No commits in repository"
  exit 1
fi

# Push to Forgejo (force to handle empty repo or diverged history)
echo "Pushing to Forgejo..."
git push -u forgejo "$CURRENT_BRANCH:$GIT_BRANCH" --force

# Also push all branches if main is different from current
if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
  echo "Also pushing $GIT_BRANCH branch..."
  git push forgejo "$GIT_BRANCH" --force 2>/dev/null || true
fi

# Security: Remove token from git remote URL (replace with non-token URL)
# This prevents the token from being exposed in .git/config
SAFE_URL="http://$FORGEJO_IP/$GIT_USER/$REPO_NAME.git"
git remote set-url forgejo "$SAFE_URL"
echo "Git remote URL sanitized (token removed)"

echo "=== Repository pushed to Forgejo successfully ==="
