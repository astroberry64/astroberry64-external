#!/bin/bash
# PHD2 Guiding - Configuration for astroberry64-external build system

# === Source Configuration ===
SOURCE_TYPE="git"
GIT_REPO="https://github.com/OpenPHDGuiding/phd2.git"
GIT_TAG="v2.6.13dev7"  # Tracks all tags (stable + dev)

# === Build System ===
BUILD_SYSTEM="debian"  # Uses debian/ from git repo

# === Build Dependencies ===
# These will be auto-installed by mk-build-deps or apt-get build-dep
# Listed here for documentation purposes
BUILD_DEPS=(
    "debhelper (>= 9)"
    "cmake"
    "libwxgtk3.2-dev | libwxgtk3.0-dev | libwxgtk3.0-gtk3-dev"
    "libcfitsio-dev"
    "libopencv-dev"
    "libusb-1.0-0-dev"
    "libudev-dev"
    "libv4l-dev"
    "libnova-dev"
    "libcurl4-gnutls-dev"
    "libindi-dev (>= 2.0)"  # Can reference our own built packages
    "libeigen3-dev"
    "libgtest-dev"
)

# === Runtime Dependencies ===
# Automatically handled by debian/control
RUNTIME_DEPS=(
    "phd2"
)

# === Debian Packaging ===
DEB_SOURCE_PACKAGE="phd2"
DEB_BINARY_PACKAGES=(
    "phd2"
)
DEB_SECTION="education"
DEB_PRIORITY="optional"
DEB_MAINTAINER="Patrick Chevalley <pch@ap-i.net>"  # Keep upstream maintainer

# === Build Configuration ===
# Note: Using upstream default -DOPENSOURCE_ONLY=1 (INDI camera drivers only)
# Proprietary camera SDKs can be enabled later once baseline is stable
CMAKE_FLAGS=""

# === Package Metadata ===
DESCRIPTION="PHD2 Guiding - Push Here Dummy telescope auto-guiding"
HOMEPAGE="https://openphdguiding.org/"

# === Notes ===
# - Source: OpenPHDGuiding/phd2 GitHub repository
# - Tracks all tags (both stable releases and dev snapshots)
# - Latest as of 2025-01-15: v2.6.13dev7
# - Uses INDI camera drivers only (no proprietary SDKs in baseline)
# - Depends on libindi-dev >= 2.0 from our repository
# - Build uses system INDI (not bundled) via -DUSE_SYSTEM_LIBINDI=1
