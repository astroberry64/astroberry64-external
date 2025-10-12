# astroberry64-external

Automated building of upstream astronomy packages (INDI, KStars, PHD2, etc.) for Debian arm64 for 64-bit RPI.

## Overview

This repository provides a script-first build system for packaging external astronomy software for Debian-based ARM64 systems (Raspberry Pi 4/5 and later).

**Philosophy**: Scripts do the work, CI just runs them. Track and build upstream packages and release to the testing APT repository.

**What this repo does**:
- Monitors upstream sources for new versions (daily automated checks)
- Builds packages when changes are pushed to main branch (including version updates from the previous line)
- Automatically deploys to the testing APT repository suite
- Provides tools for local testing and iteration

## Quick Start

### Building on a 64-bit RPI (or emulator)

```bash
# Clone the repo
git clone git@github.com:astroberry64/astroberry64-external.git
cd astroberry64-external

# Build INDI
./scripts/build-package.sh indi

# Packages will be in ~/astroberry64-external-build/output/
ls -lh ~/astroberry64-external-build/output/*.deb
```

## CI/CD Automation

### Automatic Version Checking

A daily cron job monitors upstream sources for new package versions:

- Checks GitHub releases, Ubuntu PPAs, and other sources
- Automatically commits version updates to package `config.sh` files
- Runs via GitHub Actions on a daily cron schedule

**Manual trigger**:
```bash
# Check all packages
gh workflow run check-external-updates.yml

# Check specific packages
gh workflow run check-external-updates.yml -f packages="indi,kstars-bleeding"
```

### Automatic Building & Deployment

When changes are pushed to `main`:

1. **GitHub Actions builds the package** using the same scripts you test locally
2. **Auto-deploys to trixie-testing suite** in the APT repository
3. **Packages become available** via `apt update` on test systems

**Manual trigger**:
```bash
# Build and deploy a specific package to testing suite
gh workflow run build-external.yml -f package=indi
gh workflow run build-external.yml -f package=kstars-bleeding
```

### Testing & Iteration Workflow

1. **Update your test RPI** from the testing suite:
   ```bash
   ssh pi@<RPI IP address>
   sudo apt update
   sudo apt install <package-name>
   ```

2. **Test the package** - verify functionality, check for issues

3. **Iterate if needed** - fix issues, push changes, repeat

4. **Promotion to stable** - TODO (currently manual, automation planned)

### Build Constraints

- **One package per commit** - Each commit should only modify one package directory
- This ensures isolated deployment tracking and clear build logs
- The CI will fail if multiple packages are changed in one commit

## Development Workflow

### Adding a New Package

1. **Create package directory**:
   ```bash
   mkdir -p packages/mypackage
   ```

2. **Write configuration** (`packages/mypackage/config.sh`):
   ```bash
   #!/bin/bash

   # Source type: git, ppa, github-release, archived
   SOURCE_TYPE="git"
   GIT_REPO="https://github.com/example/mypackage.git"
   GIT_TAG="v1.0.0"

   # Build system: debian, cmake, autotools, make
   BUILD_SYSTEM="debian"

   # Dependencies (documented - auto-installed from debian/control)
   BUILD_DEPS=("debhelper-compat (= 13)" "cmake" "libfoo-dev")
   ```

3. **Document the package** (`packages/mypackage/README.md`):
   - What the package does
   - Source information
   - Any special considerations
   - Patch documentation (if applicable)

4. **Test locally** on your 64-bit RPI:
   ```bash
   ./scripts/build-package.sh mypackage
   ```

5. **Add patches if needed** in `packages/mypackage/patches/`:
   - `debian/` - Patches to debian packaging (control, rules)
   - `source/` - Patches to source code
   - Document each patch in the package README

6. **Commit and push**:
   ```bash
   git add packages/mypackage
   git commit -m "Add mypackage from upstream"
   git push origin main
   ```

7. **GitHub Actions builds automatically** and deploys to testing suite

### Local Testing on a 64-bit RPI

#### Transfer and Build

```bash
# From your development machine
scp -r ~/src/astroberry64-external pi@<RPI IP address>:~/

# On the RPI
ssh pi@<RPI IP address>
cd ~/astroberry64-external
./scripts/build-package.sh indi
```

#### Install and Test

```bash
# Install built packages
cd ~/astroberry64-external-build/output
sudo apt install ./libindi1_*.deb ./libindi-data_*.deb ./indi-bin_*.deb

# Verify the package works
indiserver -v
```

### Example: Adding KStars Bleeding

Here's what was added to integrate KStars Bleeding into the build system:

**Step 1: Add package configuration** (see commit `1e6c567`)

Created `packages/kstars-bleeding/` with:
```
packages/kstars-bleeding/
├── config.sh                         # Source: PPA, Build: debian
├── patches/debian/
│   └── 01-fix-build-for-non-debian-maintainers.patch
└── README.md                         # Documentation
```

Plus a new source fetcher: `scripts/sources/get-from-ppa.sh` to download from Ubuntu PPAs.

**Step 2: Add CI/CD automation** (simplified workflow)

Only need to add **2 lines** to `.github/workflows/build-external.yml`:

```yaml
filters: |
  indi:
    - 'packages/indi/**'
  kstars-bleeding:              # ← Add package name
    - 'packages/kstars-bleeding/**'  # ← Add path filter
```

That's it! The workflow automatically:
- Detects changes via path filter
- Verifies single package per commit
- Builds the package using the unified build step
- Deploys to testing suite

**Manual trigger**:
```bash
gh workflow run build-external.yml -f package=kstars-bleeding
```

**Result**: Push to `packages/kstars-bleeding/` automatically triggers build → deploys .deb packages to APT testing suite.

See the full history:
- Package addition: `git show 1e6c567`
- Initial workflow: `git show 384b97b`
- Simplified workflow: `git show HEAD` (current)

## Technical Details

### Architecture

#### Directory Structure

```
astroberry64-external/
├── scripts/
│   ├── build-package.sh              # Main orchestrator
│   ├── install-build-deps.sh         # Dependency installer
│   ├── apply-patches.sh              # Patch applicator
│   ├── check-all-updates.sh          # Version checker
│   ├── sources/                      # Source fetchers
│   │   ├── clone-from-git.sh
│   │   ├── get-from-ppa.sh
│   │   ├── get-from-github.sh
│   │   └── extract-archived.sh
│   └── builders/                     # Build system handlers
│       ├── build-debian.sh
│       ├── build-cmake.sh
│       ├── build-autotools.sh
│       └── build-make.sh
│
├── packages/                         # Package configurations
│   ├── indi/
│   │   ├── config.sh                 # Build configuration
│   │   ├── patches/                  # Patches for compatibility
│   │   │   ├── debian/               # Patches to debian/*
│   │   │   └── source/               # Patches to source code
│   │   └── README.md                 # Package-specific docs
│   └── kstars-bleeding/
│       ├── config.sh                 # Build configuration (PPA source)
│       ├── patches/
│       │   └── debian/               # Debian packaging patches
│       │       └── 01-fix-build-for-non-debian-maintainers.patch
│       └── README.md                 # Package documentation
│
├── archived-sources/                 # Manual downloads (Git LFS)
└── .github/workflows/                # CI/CD automation
    ├── build-external.yml            # Build and deploy packages
    └── check-external-updates.yml    # Daily version checker
```

#### Build Flow

1. **Load config** - Read `packages/NAME/config.sh`
2. **Fetch source** - Clone git, download from PPA, etc.
3. **Install deps** - Auto-install build dependencies
4. **Apply patches** - Apply any compatibility patches
5. **Build** - Run appropriate builder (debian, cmake, etc.)
6. **Collect** - Gather .deb files to output directory

### Package Configuration

Each package has a `config.sh` defining:

```bash
# Source type: git, ppa, github-release, archived
SOURCE_TYPE="git"
GIT_REPO="https://github.com/indilib/indi.git"
GIT_TAG="v2.1.6"

# Build system: debian, cmake, autotools, make
BUILD_SYSTEM="debian"

# Dependencies (auto-installed from debian/control)
BUILD_DEPS=(...)
RUNTIME_DEPS=(...)

# Build flags (if needed for non-debian builds)
CMAKE_FLAGS=""
MAKE_FLAGS="-j$(nproc)"
```

See `packages/indi/config.sh` or `packages/kstars-bleeding/config.sh` for complete examples.

### Source Types

#### Type 1: Git Repository
Clones from GitHub/GitLab at a specific tag. Most packages with `debian/` in git use this.

#### Type 2: PPA Source Packages
Downloads `.dsc` + tarballs from Ubuntu PPAs using `dget`. Used for packages like kstars-bleeding.

#### Type 3: GitHub Releases
Downloads release tarballs from GitHub releases API.

#### Type 4: Archived Sources
For packages behind captchas or at-risk of disappearing. Stored in `archived-sources/`.

### Patching

Patches live in `packages/NAME/patches/`:

- `debian/` - Patches to debian packaging (control, rules)
- `source/` - Patches to source code

Each patch should be documented in the package README:
- What it fixes
- Why it's needed
- When it can be removed
- Should it go upstream?

### Environment Variables

- `BUILD_DIR` - Build directory (default: `~/astroberry64-external-build`)
- `OUTPUT_DIR` - Output for .deb files (default: `BUILD_DIR/output`)

### Prerequisites

#### Build Tools (auto-installed)

The scripts will auto-install:
- build-essential
- devscripts
- debhelper
- fakeroot
- Package-specific build deps from `debian/control`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally on a 64-bit RPI
4. Submit PR with:
   - New/modified package configs
   - Updated package README
   - Patch documentation (if applicable)

### Example: Adding KStars Bleeding

Here's what was added to integrate KStars Bleeding into the build system:

**Step 1: Add package configuration** (see commit `1e6c567`)

Created `packages/kstars-bleeding/` with:
```
packages/kstars-bleeding/
├── config.sh                         # Source: PPA, Build: debian
├── patches/debian/
│   └── 01-fix-build-for-non-debian-maintainers.patch
└── README.md                         # Documentation
```

Plus a new source fetcher: `scripts/sources/get-from-ppa.sh` to download from Ubuntu PPAs.

**Step 2: Add CI/CD automation** (simplified workflow)

Only need to add **2 lines** to `.github/workflows/build-external.yml`:

```yaml
filters: |
  indi:
    - 'packages/indi/**'
  kstars-bleeding:              # ← Add package name
    - 'packages/kstars-bleeding/**'  # ← Add path filter
```

That's it! The workflow automatically:
- Detects changes via path filter
- Verifies single package per commit
- Builds the package using the unified build step
- Deploys to testing suite

**Manual trigger**:
```bash
gh workflow run build-external.yml -f package=kstars-bleeding
```

**Result**: Push to `packages/kstars-bleeding/` automatically triggers build → deploys .deb packages to APT testing suite.

See the full history:
- Package addition: `git show 1e6c567`
- Initial workflow: `git show 384b97b`
- Simplified workflow: `git show HEAD` (current)
