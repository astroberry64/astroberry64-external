#!/bin/bash
set -euo pipefail

# install-build-deps.sh - Install build dependencies for a package
# Usage: install-build-deps.sh <source-dir> <config-file>

SOURCE_DIR="$1"
CONFIG_FILE="$2"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

echo "[install-build-deps] Installing build dependencies..."

# First, ensure basic build tools are installed
BASIC_TOOLS=(
    "build-essential"
    "devscripts"
    "debhelper"
    "fakeroot"
)

echo "[install-build-deps] Checking basic build tools..."
for tool in "${BASIC_TOOLS[@]}"; do
    if ! dpkg -l "$tool" &>/dev/null; then
        echo "[install-build-deps] Installing $tool..."
        sudo apt-get update -qq
        sudo apt-get install -y "$tool"
    fi
done

# Check if this is a debian package (has debian/control)
if [ -f "$SOURCE_DIR/debian/control" ]; then
    echo "[install-build-deps] Found debian/control, using apt-get build-dep..."

    # Update package lists
    sudo apt-get update -qq

    # Install build dependencies
    # Using -y for non-interactive, --no-install-recommends to minimize deps
    sudo apt-get build-dep -y "$SOURCE_DIR"

    echo "[install-build-deps] Build dependencies installed successfully"
else
    echo "[install-build-deps] No debian/control found"

    # For non-debian packages, check if BUILD_DEPS is defined in config
    if [ -n "${BUILD_DEPS:-}" ] && [ ${#BUILD_DEPS[@]} -gt 0 ]; then
        echo "[install-build-deps] Installing BUILD_DEPS from config..."

        # Extract just the package names (remove version constraints)
        PACKAGES=()
        for dep in "${BUILD_DEPS[@]}"; do
            # Extract package name before any space, (, or |
            pkg=$(echo "$dep" | sed 's/[[:space:]].*//' | sed 's/(.*//' | sed 's/|.*//')
            PACKAGES+=("$pkg")
        done

        sudo apt-get update -qq
        sudo apt-get install -y "${PACKAGES[@]}"

        echo "[install-build-deps] BUILD_DEPS installed successfully"
    else
        echo "[install-build-deps] WARNING: No debian/control and no BUILD_DEPS defined"
        echo "[install-build-deps] You may need to install dependencies manually"
    fi
fi
