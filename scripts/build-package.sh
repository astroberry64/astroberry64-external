#!/bin/bash
set -euo pipefail

# build-package.sh - Main orchestrator for building external packages
# Usage: ./scripts/build-package.sh <package-name>
# Environment: AUTO_DEPLOY=1 to auto-push to trixie-testing (used by GitHub Actions)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$REPO_ROOT/packages"
BUILD_DIR="${BUILD_DIR:-$HOME/astroberry64-external-build}"
OUTPUT_DIR="${OUTPUT_DIR:-$BUILD_DIR/output}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

usage() {
    cat <<EOF
Usage: $0 <package-name>

Build an external package for Debian arm64.

Arguments:
  package-name    Name of package directory in packages/ (e.g., "indi")

Environment Variables:
  BUILD_DIR       Build directory (default: ~/astroberry64-external-build)
  OUTPUT_DIR      Output directory for .deb files (default: BUILD_DIR/output)
  AUTO_DEPLOY     Set to 1 to auto-deploy to trixie-testing APT repo

Examples:
  $0 indi                    # Build INDI locally
  AUTO_DEPLOY=1 $0 indi      # Build and deploy to APT repo

EOF
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

PACKAGE_NAME="$1"
PACKAGE_DIR="$PACKAGES_DIR/$PACKAGE_NAME"
CONFIG_FILE="$PACKAGE_DIR/config.sh"

# Validate package exists
if [ ! -d "$PACKAGE_DIR" ]; then
    log_error "Package directory not found: $PACKAGE_DIR"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    log_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Load package configuration
log_info "Loading configuration for package: $PACKAGE_NAME"
# shellcheck source=/dev/null
source "$CONFIG_FILE"

# Validate required config variables
if [ -z "${SOURCE_TYPE:-}" ]; then
    log_error "SOURCE_TYPE not defined in $CONFIG_FILE"
    exit 1
fi

if [ -z "${BUILD_SYSTEM:-}" ]; then
    log_error "BUILD_SYSTEM not defined in $CONFIG_FILE"
    exit 1
fi

log_info "Package: $PACKAGE_NAME"
log_info "Source type: $SOURCE_TYPE"
log_info "Build system: $BUILD_SYSTEM"

# Create build directories
log_info "Creating build directories..."
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

WORK_DIR="$BUILD_DIR/$PACKAGE_NAME"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

log_info "Work directory: $WORK_DIR"

# Step 1: Fetch source
log_info "Fetching source..."
case "$SOURCE_TYPE" in
    git)
        "$SCRIPT_DIR/sources/clone-from-git.sh" "$PACKAGE_NAME" "$WORK_DIR" "$CONFIG_FILE"
        ;;
    ppa)
        "$SCRIPT_DIR/sources/get-from-ppa.sh" "$PACKAGE_NAME" "$WORK_DIR" "$CONFIG_FILE"
        ;;
    github-release)
        "$SCRIPT_DIR/sources/get-from-github.sh" "$PACKAGE_NAME" "$WORK_DIR" "$CONFIG_FILE"
        ;;
    archived)
        "$SCRIPT_DIR/sources/extract-archived.sh" "$PACKAGE_NAME" "$WORK_DIR" "$CONFIG_FILE"
        ;;
    *)
        log_error "Unknown SOURCE_TYPE: $SOURCE_TYPE"
        exit 1
        ;;
esac

# Find the source directory (should be only directory in WORK_DIR)
SOURCE_DIR=$(find "$WORK_DIR" -maxdepth 1 -type d ! -path "$WORK_DIR" | head -n1)
if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory not found in $WORK_DIR"
    exit 1
fi

log_info "Source directory: $SOURCE_DIR"

# Step 2: Install build dependencies
log_info "Installing build dependencies..."
"$SCRIPT_DIR/install-build-deps.sh" "$SOURCE_DIR" "$CONFIG_FILE"

# Step 3: Apply patches (if any)
if [ -d "$PACKAGE_DIR/patches/debian" ] || [ -d "$PACKAGE_DIR/patches/source" ]; then
    log_info "Applying patches..."
    "$SCRIPT_DIR/apply-patches.sh" "$SOURCE_DIR" "$PACKAGE_DIR"
else
    log_info "No patches to apply"
fi

# Step 4: Build package
log_info "Building package..."
case "$BUILD_SYSTEM" in
    debian)
        "$SCRIPT_DIR/builders/build-debian.sh" "$SOURCE_DIR" "$OUTPUT_DIR" "$CONFIG_FILE"
        ;;
    cmake)
        "$SCRIPT_DIR/builders/build-cmake.sh" "$SOURCE_DIR" "$OUTPUT_DIR" "$CONFIG_FILE"
        ;;
    autotools)
        "$SCRIPT_DIR/builders/build-autotools.sh" "$SOURCE_DIR" "$OUTPUT_DIR" "$CONFIG_FILE"
        ;;
    make)
        "$SCRIPT_DIR/builders/build-make.sh" "$SOURCE_DIR" "$OUTPUT_DIR" "$CONFIG_FILE"
        ;;
    *)
        log_error "Unknown BUILD_SYSTEM: $BUILD_SYSTEM"
        exit 1
        ;;
esac

# Step 5: List built packages
log_success "Build completed!"
log_info "Built packages:"
find "$OUTPUT_DIR" -name "*.deb" -type f -printf "  %f\n"

# Step 6: Optional deployment
# Set REPO_DIR for use in deployment messages
REPO_DIR="${ASTROBERRY64_REPO:-$HOME/src/astroberry64-repo}"

if [ "${AUTO_DEPLOY:-0}" = "1" ]; then
    log_info "AUTO_DEPLOY=1, deploying to trixie-testing..."

    # Check if we have the astroberry64-repo available
    if [ ! -d "$REPO_DIR" ]; then
        log_error "astroberry64-repo not found at: $REPO_DIR"
        log_error "Set ASTROBERRY64_REPO environment variable or clone it"
        exit 1
    fi

    if [ ! -f "$REPO_DIR/add-package.sh" ]; then
        log_error "add-package.sh not found in $REPO_DIR"
        exit 1
    fi

    # Deploy all .deb files
    for deb in "$OUTPUT_DIR"/*.deb; do
        if [ -f "$deb" ]; then
            log_info "Deploying: $(basename "$deb")"
            "$REPO_DIR/add-package.sh" "$deb" testing
        fi
    done

    log_success "Deployment complete!"
else
    log_info "Skipping deployment (set AUTO_DEPLOY=1 to enable)"
    log_info "To manually deploy: cd $REPO_DIR && ./add-package.sh <package.deb> testing"
fi

log_success "All done! Packages available in: $OUTPUT_DIR"
