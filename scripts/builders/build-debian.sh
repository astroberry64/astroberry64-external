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

echo "[build-debian] === Auto-incrementing build number ==="

# Get package name from debian/control
PACKAGE_NAME=$(grep "^Package:" debian/control | head -1 | awk "{print \$2}")
echo "[build-debian] Package: $PACKAGE_NAME"

# Get current version from debian/changelog (handles both formats)
CURRENT_FULL_VERSION=$(dpkg-parsechangelog -S Version)
echo "[build-debian] Current version in git: $CURRENT_FULL_VERSION"

# Extract upstream version (works with "2.6.13dev7" OR "2.6.13dev7-astroberry64.10")
CURRENT_UPSTREAM=$(echo "$CURRENT_FULL_VERSION" | sed "s/-astroberry64\..*//")
echo "[build-debian] Upstream version: $CURRENT_UPSTREAM"

# Fetch latest version from astroberry64-repo
LATEST_REPO_VERSION=$(curl -s "https://astroberry64.github.io/astroberry64-repo/dists/trixie-testing/main/binary-arm64/Packages.gz" | \
  gunzip | \
  awk "/^Package: ${PACKAGE_NAME}\$/,/^Version:/" | \
  grep "^Version:" | \
  head -1 | \
  awk "{print \$2}")

if [ -z "$LATEST_REPO_VERSION" ]; then
  echo "[build-debian] No previous version found in repo, starting at .1"
  NEW_BUILD=1
else
  echo "[build-debian] Latest in repo: $LATEST_REPO_VERSION"

  # Parse repo version parts
  REPO_UPSTREAM=$(echo "$LATEST_REPO_VERSION" | sed "s/-astroberry64\..*//")
  REPO_BUILD=$(echo "$LATEST_REPO_VERSION" | grep -oP "astroberry64\.\K\d+" || echo "0")

  # Compare upstream versions
  if [ "$CURRENT_UPSTREAM" != "$REPO_UPSTREAM" ]; then
    echo "[build-debian] Upstream version changed ($REPO_UPSTREAM → $CURRENT_UPSTREAM), resetting build to .1"
    NEW_BUILD=1
  else
    echo "[build-debian] Upstream version unchanged, incrementing build number"
    NEW_BUILD=$((REPO_BUILD + 1))
  fi
fi

# Create new version string
NEW_VERSION="${CURRENT_UPSTREAM}-astroberry64.${NEW_BUILD}"
echo "[build-debian] New version: $NEW_VERSION"

# Update debian/changelog (in CI only, not committed back to git)
export DEBFULLNAME="Astroberry64 CI"
export DEBEMAIL="ci@astroberry64.github.io"
dch -b -v "$NEW_VERSION" "Automated build #${NEW_BUILD} from CI"

echo ""
echo "[build-debian] Updated debian/changelog (CI ephemeral):"
head -5 debian/changelog
echo ""

# Build the package
# -us -uc: Don't sign source/changes (we're not uploading to Debian)
# -b: Binary-only build (no source package)
# DEB_BUILD_OPTIONS:
#   parallel=N: Enable parallel build (works with CDBS)
#   noautodbgsym: Don't create automatic debug symbol packages (saves space)
echo "[build-debian] Running dpkg-buildpackage with $(nproc) parallel jobs (no debug packages)..."
export DEB_BUILD_OPTIONS="parallel=$(nproc) noautodbgsym"
dpkg-buildpackage -us -uc -b

# Find the parent directory where .deb files were created
PARENT_DIR="$(dirname "$SOURCE_DIR")"

echo "[build-debian] Build completed, collecting packages..."

# Move all .deb files to output directory (skip debug packages)
DEB_COUNT=0
SKIPPED_COUNT=0
for deb in "$PARENT_DIR"/*.deb; do
    if [ -f "$deb" ]; then
        BASENAME=$(basename "$deb")
        # Skip debug packages (dbg, dbgsym)
        if [[ "$BASENAME" =~ -dbg_ ]] || [[ "$BASENAME" =~ -dbgsym_ ]]; then
            echo "[build-debian]   SKIP (debug): $BASENAME"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            rm "$deb"  # Remove debug package
        else
            echo "[build-debian]   $(basename "$deb")"
            mv "$deb" "$OUTPUT_DIR/"
            DEB_COUNT=$((DEB_COUNT + 1))
        fi
    fi
done

if [ $SKIPPED_COUNT -gt 0 ]; then
    echo "[build-debian] Skipped $SKIPPED_COUNT debug package(s) to save space"
fi

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
