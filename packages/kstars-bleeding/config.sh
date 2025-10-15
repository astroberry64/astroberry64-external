#!/bin/bash
# KStars Bleeding Edge - Configuration for astroberry64-external build system

# === Source Configuration ===
SOURCE_TYPE="ppa"
PPA_NAME="ppa:mutlaqja/ppa"
PACKAGE_NAME="kstars-bleeding"

# === Version Tracking ===
# Controls automated version checking (check-all-updates.sh)
VERSION_SOURCE="custom"                 # PPA version checking not yet implemented
# TODO: Implement PPA version checking via Launchpad API

# === Build System ===
BUILD_SYSTEM="debian"

# === Build Dependencies ===
# These will be auto-installed by mk-build-deps or apt-get build-dep
# Listed here for documentation purposes
BUILD_DEPS=(
    # Note: Actual dependencies are in debian/control from PPA source
    # These are listed here for documentation only
    "debhelper-compat (= 13)"
    "cmake"
    "libindi-dev (>= 2.0)"  # Can reference our own built packages
    "libqt5*-dev"  # Qt5 libraries
    "libkf5*-dev"  # KDE Frameworks 5
)

# === Runtime Dependencies ===
# Automatically handled by debian/control
RUNTIME_DEPS=(
    "libindi1"
    "kstars-bleeding-data"
)

# === Debian Packaging ===
DEB_SOURCE_PACKAGE="kstars-bleeding"
DEB_BINARY_PACKAGES=(
    "kstars-bleeding"
    "kstars-bleeding-data"
    "kstars-bleeding-dbg"
)
DEB_SECTION="science"
DEB_PRIORITY="optional"
DEB_MAINTAINER="Jasem Mutlaq <mutlaqja@ikarustech.com>"  # Keep upstream maintainer

# === Build Configuration ===
# Note: This package uses Qt5/KF5 (not Qt6/KF6) as specified in debian/control
# CMAKE_FLAGS are not used when BUILD_SYSTEM="debian" (debian/rules controls cmake)
CMAKE_FLAGS=""

# === Package Metadata ===
DESCRIPTION="KStars Desktop Planetarium (Bleeding Edge)"
HOMEPAGE="https://edu.kde.org/kstars/"

# === Notes ===
# - Source: Jasem Mutlaq's PPA (same maintainer as INDI)
# - Latest version as of 2025-10-07: 6:3.7.9+202510070847~ubuntu24.04.1
# - Builds for arm64 confirmed available on Launchpad
# - Ubuntu Noble source will be rebuilt for Debian Trixie
# - KStars uses Qt6 and KDE Frameworks 6 (KF6)
# - Depends on libindi-dev from our repository
