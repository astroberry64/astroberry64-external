#!/bin/bash
set -euo pipefail

# clone-from-git.sh - Clone source from git repository
# Usage: clone-from-git.sh <package-name> <work-dir> <config-file>

PACKAGE_NAME="$1"
WORK_DIR="$2"
CONFIG_FILE="$3"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate required variables
if [ -z "${GIT_REPO:-}" ]; then
    echo "ERROR: GIT_REPO not defined in config" >&2
    exit 1
fi

if [ -z "${GIT_TAG:-}" ]; then
    echo "ERROR: GIT_TAG not defined in config" >&2
    exit 1
fi

echo "[clone-from-git] Cloning $GIT_REPO at $GIT_TAG..."

# Clone with specific tag/branch
# Using --depth 1 for faster clone, --branch works with tags too
git clone --depth 1 --branch "$GIT_TAG" "$GIT_REPO" "$WORK_DIR/$PACKAGE_NAME"

echo "[clone-from-git] Clone complete: $WORK_DIR/$PACKAGE_NAME"
