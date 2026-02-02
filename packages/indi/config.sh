#!/bin/bash
# INDI Core Library Configuration

# === Source Configuration ===
SOURCE_TYPE="git"
GIT_REPO="https://github.com/indilib/indi.git"
GIT_TAG="v2.1.8"  # Latest as of 2025-10-08

# === Version Tracking ===
# Controls automated version checking (check-all-updates.sh)
VERSION_SOURCE="github-releases"       # INDI uses GitHub Releases for stable versions
VERSION_INCLUDE_PRERELEASE="false"     # Only track stable releases

# === Build System ===
BUILD_SYSTEM="debian"  # Uses debian/ from git repo

# === Build Dependencies ===
# These will be auto-installed by mk-build-deps or apt-get build-dep
# Listed here for documentation purposes
BUILD_DEPS=(
    "debhelper-compat (= 13)"
    "cmake"
    "cdbs"
    "zlib1g-dev"
    "libnova-dev"
    "libcfitsio-dev"
    "libusb-1.0-0-dev"
    "libgsl-dev"
    "libcurl4-gnutls-dev"
    "libjpeg-dev"
    "libfftw3-dev"
    "libev-dev"
    "libgps-dev"
    "libgnutls28-dev"
    "libtheora-dev"
)

# === Runtime Dependencies ===
# Automatically handled by debian/control
RUNTIME_DEPS=(
    "libindi1"
    "libindi-data"
    "indi-bin"
)

# === Debian Packaging ===
# INDI already has debian/ directory, these values are informational
DEB_SOURCE_PACKAGE="indi"
DEB_BINARY_PACKAGES=(
    "libindi1"
    "libindi-data"
    "libindi-dev"
    "indi-bin"
)
DEB_SECTION="science"
DEB_PRIORITY="optional"
DEB_MAINTAINER="INDI Team <indi-devel@lists.sourceforge.net>"  # Keep upstream maintainer

# === Build Configuration ===
# Additional flags if needed (INDI's debian/rules should handle most of this)
CMAKE_FLAGS=""
MAKE_FLAGS="-j$(nproc)"

# === Package Metadata ===
DESCRIPTION="INDI (Instrument Neutral Distributed Interface) astronomical device control library"
HOMEPAGE="https://indilib.org"
