#!/bin/bash
# Build and push custom Obico ML API image with CUDA 12 support
#
# Usage:
#   ./build.sh                    # Build only
#   ./build.sh --push             # Build and push to registry
#   ./build.sh --push --latest    # Build and push with :latest tag
#
# Prerequisites:
#   - Docker or Podman with buildx support
#   - NVIDIA Container Toolkit (for GPU testing)
#   - Registry authentication (for push)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${IMAGE_NAME:-ghcr.io/wdiazux/obico-ml-api}"
IMAGE_TAG="${IMAGE_TAG:-cuda12}"
PUSH=false
LATEST=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH=true
            shift
            ;;
        --latest)
            LATEST=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Detect container runtime
if command -v docker &> /dev/null; then
    RUNTIME="docker"
elif command -v podman &> /dev/null; then
    RUNTIME="podman"
else
    echo "Error: Neither docker nor podman found"
    exit 1
fi

echo "Using $RUNTIME as container runtime"
echo "Building ${IMAGE_NAME}:${IMAGE_TAG}..."

cd "$SCRIPT_DIR"

# Build the image
$RUNTIME build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file Dockerfile \
    .

echo "Build complete: ${IMAGE_NAME}:${IMAGE_TAG}"

# Push if requested
if $PUSH; then
    echo "Pushing ${IMAGE_NAME}:${IMAGE_TAG}..."
    $RUNTIME push "${IMAGE_NAME}:${IMAGE_TAG}"

    if $LATEST; then
        echo "Tagging and pushing :latest..."
        $RUNTIME tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:latest"
        $RUNTIME push "${IMAGE_NAME}:latest"
    fi

    echo "Push complete!"
fi

echo "Done!"
