#!/bin/bash
set -euo pipefail

# apply-patches.sh - Apply patches to source code
# Usage: apply-patches.sh <source-dir> <package-dir>

SOURCE_DIR="$1"
PACKAGE_DIR="$2"

echo "[apply-patches] Applying patches from $PACKAGE_DIR/patches/"

DEBIAN_PATCHES="$PACKAGE_DIR/patches/debian"
SOURCE_PATCHES="$PACKAGE_DIR/patches/source"

patch_count=0

# Apply debian/* patches
if [ -d "$DEBIAN_PATCHES" ]; then
    echo "[apply-patches] Applying debian patches..."
    # Apply .patch files
    for patch in "$DEBIAN_PATCHES"/*.patch; do
        if [ -f "$patch" ]; then
            echo "[apply-patches]   Applying $(basename "$patch")..."
            patch -d "$SOURCE_DIR" -p1 < "$patch"
            patch_count=$((patch_count + 1))
        fi
    done
    # Apply .sh scripts
    for script in "$DEBIAN_PATCHES"/*.sh; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            echo "[apply-patches]   Executing $(basename "$script")..."
            cd "$SOURCE_DIR" && "$script"
            patch_count=$((patch_count + 1))
        fi
    done
fi

# Apply source code patches
if [ -d "$SOURCE_PATCHES" ]; then
    echo "[apply-patches] Applying source patches..."
    # Apply .patch files
    for patch in "$SOURCE_PATCHES"/*.patch; do
        if [ -f "$patch" ]; then
            echo "[apply-patches]   Applying $(basename "$patch")..."
            patch -d "$SOURCE_DIR" -p1 < "$patch"
            patch_count=$((patch_count + 1))
        fi
    done
    # Apply .sh scripts
    for script in "$SOURCE_PATCHES"/*.sh; do
        if [ -f "$script" ] && [ -x "$script" ]; then
            echo "[apply-patches]   Executing $(basename "$script")..."
            cd "$SOURCE_DIR" && "$script"
            patch_count=$((patch_count + 1))
        fi
    done
fi

if [ $patch_count -eq 0 ]; then
    echo "[apply-patches] No patches found"
else
    echo "[apply-patches] Applied $patch_count patch(es) successfully"
fi
