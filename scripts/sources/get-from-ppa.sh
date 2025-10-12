#!/bin/bash
set -euo pipefail

# get-from-ppa.sh - Download source package from Ubuntu PPA
# Usage: get-from-ppa.sh <package-name> <work-dir> <config-file>

PACKAGE_NAME="$1"
WORK_DIR="$2"
CONFIG_FILE="$3"

# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate required variables
if [ -z "${PPA_NAME:-}" ]; then
    echo "ERROR: PPA_NAME not defined in config" >&2
    exit 1
fi

if [ -z "${PACKAGE_NAME:-}" ]; then
    echo "ERROR: PACKAGE_NAME not defined in config" >&2
    exit 1
fi

# Parse PPA (format: ppa:user/ppa-name)
if [[ ! $PPA_NAME =~ ^ppa:([^/]+)/(.+)$ ]]; then
    echo "ERROR: Invalid PPA format. Expected 'ppa:user/name', got '$PPA_NAME'" >&2
    exit 1
fi

PPA_USER="${BASH_REMATCH[1]}"
PPA_REPO="${BASH_REMATCH[2]}"

echo "[get-from-ppa] Fetching $PACKAGE_NAME from $PPA_NAME..."

# Launchpad PPA URL structure
# https://launchpad.net/~USER/+archive/ubuntu/REPO/+packages?field.name_filter=PACKAGE
LAUNCHPAD_API="https://api.launchpad.net/1.0/~${PPA_USER}/+archive/ubuntu/${PPA_REPO}?ws.op=getPublishedSources&source_name=${PACKAGE_NAME}"

echo "[get-from-ppa] Querying Launchpad API: $LAUNCHPAD_API"

# Query Launchpad API for latest source package
# The API returns JSON with entries sorted by newest first
# We want the latest version for the newest Ubuntu release that has arm64 builds

API_RESPONSE=$(curl -s "$LAUNCHPAD_API")

# Extract the first entry's source_package_name and source_package_version
# Use jq if available, otherwise fall back to basic parsing
if command -v jq &>/dev/null; then
    LATEST_VERSION=$(echo "$API_RESPONSE" | jq -r '.entries[0].source_package_version' 2>/dev/null)
    DSC_URL=$(echo "$API_RESPONSE" | jq -r '.entries[0].source_package_publishing_history_collection_link' 2>/dev/null)
else
    # Basic parsing without jq (fragile, but works for most cases)
    LATEST_VERSION=$(echo "$API_RESPONSE" | grep -o '"source_package_version": "[^"]*"' | head -1 | cut -d'"' -f4)
fi

if [ -z "$LATEST_VERSION" ] || [ "$LATEST_VERSION" = "null" ]; then
    echo "ERROR: Could not find package $PACKAGE_NAME in $PPA_NAME" >&2
    echo "API Response: $API_RESPONSE" >&2
    exit 1
fi

echo "[get-from-ppa] Found version: $LATEST_VERSION"

# Construct .dsc URL
# Launchpad PPA pool structure: http://ppa.launchpad.net/USER/REPO/ubuntu/pool/main/LETTER/PACKAGE/
# Example: http://ppa.launchpad.net/mutlaqja/ppa/ubuntu/pool/main/k/kstars-bleeding/

# Calculate pool prefix (same as Debian)
if [[ $PACKAGE_NAME == lib* ]]; then
    POOL_PREFIX="lib${PACKAGE_NAME:3:1}"
else
    POOL_PREFIX="${PACKAGE_NAME:0:1}"
fi

# Try to download using dget with Launchpad PPA URL
# dget can fetch from PPAs directly
PPA_URL="http://ppa.launchpad.net/${PPA_USER}/${PPA_REPO}/ubuntu"

echo "[get-from-ppa] Attempting to download from PPA pool..."
echo "[get-from-ppa] PPA URL: $PPA_URL"

# Create work directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Remove epoch from version for filename (6:3.7.9 -> 3.7.9)
# Debian packages use epoch in version internally but not in filenames
VERSION_NO_EPOCH="${LATEST_VERSION#*:}"

# Use dget to download source package
# dget will download .dsc + .orig.tar.* + .debian.tar.* and extract
# Filenames never include the epoch
DSC_FILE="${PACKAGE_NAME}_${VERSION_NO_EPOCH}.dsc"
DSC_URL="${PPA_URL}/pool/main/${POOL_PREFIX}/${PACKAGE_NAME}/${DSC_FILE}"

echo "[get-from-ppa] Downloading: $DSC_URL"

if ! dget -u "$DSC_URL" 2>&1; then
    echo "ERROR: Failed to download source package" >&2
    echo "Tried URL: $DSC_URL" >&2
    exit 1
fi

# dget downloads and extracts to directory named: package-version (without epoch)
# Example: kstars-bleeding-3.7.9+202510070847~ubuntu24.04.1
# We need to find the extracted directory and move it to $PACKAGE_NAME

# Find the extracted directory (dget creates it without epoch)
EXTRACTED_DIR="${PACKAGE_NAME}-${VERSION_NO_EPOCH}"

if [ -d "$EXTRACTED_DIR" ]; then
    # Move to standard package name
    if [ -d "$PACKAGE_NAME" ]; then
        rm -rf "$PACKAGE_NAME"
    fi
    mv "$EXTRACTED_DIR" "$PACKAGE_NAME"
    echo "[get-from-ppa] Source extracted to: $WORK_DIR/$PACKAGE_NAME"
else
    echo "ERROR: Expected directory $EXTRACTED_DIR not found after dget" >&2
    ls -la "$WORK_DIR" >&2
    exit 1
fi

echo "[get-from-ppa] Download complete: $WORK_DIR/$PACKAGE_NAME"
