#!/bin/bash
set -euo pipefail

# build-debian.sh - Build a Debian package using debian/ directory
# Usage: build-debian.sh <source-dir> <output-dir> <config-file>

SOURCE_DIR="$1"
OUTPUT_DIR="$2"
CONFIG_FILE="$3"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

echo "[build-debian] Building Debian package from $SOURCE_DIR..."

# Verify debian/ exists
if [ ! -d "$SOURCE_DIR/debian" ]; then
    echo "ERROR: debian/ directory not found in $SOURCE_DIR" >&2
    exit 1
fi

# Verify debian/control exists
if [ ! -f "$SOURCE_DIR/debian/control" ]; then
    echo "ERROR: debian/control not found in $SOURCE_DIR/debian/" >&2
    exit 1
fi

# Change to source directory
cd "$SOURCE_DIR"

# Build the package
# -us -uc: Don't sign source/changes (we're not uploading to Debian)
# -b: Binary-only build (no source package)
# DEB_BUILD_OPTIONS=parallel=N: Enable parallel build (works with CDBS)
echo "[build-debian] Running dpkg-buildpackage with $(nproc) parallel jobs..."
export DEB_BUILD_OPTIONS="parallel=$(nproc)"
dpkg-buildpackage -us -uc -b

# Find the parent directory where .deb files were created
PARENT_DIR="$(dirname "$SOURCE_DIR")"

echo "[build-debian] Build completed, collecting packages..."

# Move all .deb files to output directory
DEB_COUNT=0
for deb in "$PARENT_DIR"/*.deb; do
    if [ -f "$deb" ]; then
        echo "[build-debian]   $(basename "$deb")"
        mv "$deb" "$OUTPUT_DIR/"
        ((DEB_COUNT++))
    fi
done

# Also collect .buildinfo and .changes files for reference
for file in "$PARENT_DIR"/*.{buildinfo,changes}; do
    if [ -f "$file" ]; then
        mv "$file" "$OUTPUT_DIR/"
    fi
done

if [ $DEB_COUNT -eq 0 ]; then
    echo "ERROR: No .deb files were created!" >&2
    exit 1
fi

echo "[build-debian] Successfully built $DEB_COUNT package(s)"
