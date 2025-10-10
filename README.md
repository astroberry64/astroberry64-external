# astroberry64-external

Automated building of upstream astronomy packages (INDI, KStars, PHD2, etc.) for Debian arm64.

## Overview

This repository provides a script-first build system for packaging external astronomy software for Debian-based ARM64 systems (primarily Raspberry Pi 4/5).

**Philosophy**: Scripts do the work, CI just runs them. This enables rapid iteration on actual hardware before committing to GitHub Actions.

## Quick Start

### Building INDI on RPI5

```bash
# Clone the repo
git clone git@github.com:astroberry64/astroberry64-external.git
cd astroberry64-external

# Build INDI v2.1.6
./scripts/build-package.sh indi

# Packages will be in ~/astroberry64-external-build/output/
ls -lh ~/astroberry64-external-build/output/*.deb
```

### With Auto-Deploy to APT Repository

```bash
# Set repo location (if not in default ~/src/astroberry64-repo)
export ASTROBERRY64_REPO=~/src/astroberry64-repo

# Build and auto-deploy to trixie-testing
AUTO_DEPLOY=1 ./scripts/build-package.sh indi
```

## Architecture

### Directory Structure

```
astroberry64-external/
├── scripts/
│   ├── build-package.sh              # Main orchestrator
│   ├── install-build-deps.sh         # Dependency installer
│   ├── apply-patches.sh              # Patch applicator
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
│   └── indi/
│       ├── config.sh                 # Build configuration
│       ├── patches/                  # Patches for compatibility
│       │   ├── debian/               # Patches to debian/*
│       │   └── source/               # Patches to source code
│       └── README.md                 # Package-specific docs
│
├── archived-sources/                 # Manual downloads (Git LFS)
└── .github/workflows/                # CI/CD (coming soon)
```

### Build Flow

1. **Load config** - Read `packages/NAME/config.sh`
2. **Fetch source** - Clone git, download from PPA, etc.
3. **Install deps** - Auto-install build dependencies
4. **Apply patches** - Apply any compatibility patches
5. **Build** - Run appropriate builder (debian, cmake, etc.)
6. **Collect** - Gather .deb files
7. **Deploy** (optional) - Push to APT repo if `AUTO_DEPLOY=1`

## Package Configuration

Each package has a `config.sh` defining:

```bash
# Source type: git, ppa, github-release, archived
SOURCE_TYPE="git"
GIT_REPO="https://github.com/indilib/indi.git"
GIT_TAG="v2.1.6"

# Build system: debian, cmake, autotools, make
BUILD_SYSTEM="debian"

# Dependencies (auto-installed)
BUILD_DEPS=(...)
RUNTIME_DEPS=(...)

# Build flags (if needed)
CMAKE_FLAGS=""
MAKE_FLAGS="-j$(nproc)"
```

See `packages/indi/config.sh` for a complete example.

## Current Packages

| Package | Version | Source | Status |
|---------|---------|--------|--------|
| **indi** | 2.1.6 | github.com/indilib/indi | ✅ Ready to test |

### Coming Soon

- **indi-3rdparty** - INDI 3rd-party drivers
- **kstars** - KStars planetarium (requires Qt6)
- **phd2** - PHD2 autoguiding

## Development Workflow

### Local Development (RPI5)

1. **Edit scripts/configs** - Modify locally
2. **Test build** - Run `./scripts/build-package.sh NAME`
3. **Iterate** - Fix issues, add `set -x` for debugging
4. **Commit** - Once working, commit to git
5. **CI runs same scripts** - No surprises!

### Adding a New Package

1. Create `packages/NAME/` directory
2. Write `config.sh` with source and build settings
3. Create `README.md` documenting the package
4. Test locally: `./scripts/build-package.sh NAME`
5. Add patches in `patches/debian/` or `patches/source/` if needed
6. Commit and push

## Environment Variables

- `BUILD_DIR` - Build directory (default: `~/astroberry64-external-build`)
- `OUTPUT_DIR` - Output for .deb files (default: `BUILD_DIR/output`)
- `AUTO_DEPLOY` - Set to `1` to auto-deploy to APT repo
- `ASTROBERRY64_REPO` - Path to astroberry64-repo (default: `~/src/astroberry64-repo`)

## Prerequisites

### Build Tools (auto-installed)

The scripts will auto-install:
- build-essential
- devscripts
- debhelper
- fakeroot
- Package-specific build deps from `debian/control`

### Manual Prerequisites

- Git
- sudo access (for apt-get)
- arm64 architecture (RPI4/RPI5 or similar)

## Source Types

### Type 1: Git Repository (INDI)
Clones from GitHub/GitLab at a specific tag. Most packages with `debian/` in git use this.

### Type 2: PPA Source Packages
Downloads `.dsc` + tarballs from Ubuntu PPAs using `dget`.

### Type 3: GitHub Releases
Downloads release tarballs from GitHub releases API.

### Type 4: Archived Sources
For packages behind captchas or at-risk of disappearing. Stored in `archived-sources/`.

## Patching

Patches live in `packages/NAME/patches/`:

- `debian/` - Patches to debian packaging (control, rules)
- `source/` - Patches to source code

Each patch should be documented in the package README:
- What it fixes
- Why it's needed
- When it can be removed
- Should it go upstream?

## Deployment

### Manual Deployment

```bash
cd ~/src/astroberry64-repo
./add-package.sh ~/astroberry64-external-build/output/libindi1_*.deb testing
```

### Automatic Deployment

```bash
AUTO_DEPLOY=1 ./scripts/build-package.sh indi
```

Deploys all built .deb files to `trixie-testing` suite.

## Testing on RPI5

### Transfer and Build

```bash
# From local machine
scp -r ~/src/astroberry64-external pi@192.168.100.146:~/

# On RPI5
ssh pi@192.168.100.146
cd ~/astroberry64-external
./scripts/build-package.sh indi
```

### Install and Test

```bash
# Install built packages
cd ~/astroberry64-external-build/output
sudo apt install ./libindi1_*.deb ./libindi-data_*.deb ./indi-bin_*.deb

# Verify INDI works
indiserver -v
```

## Troubleshooting

### Build fails with missing dependencies

```bash
# The script auto-installs from debian/control, but if it fails:
cd ~/astroberry64-external-build/indi/indi
sudo apt build-dep ./
```

### Permission denied

```bash
# Make scripts executable
chmod +x scripts/*.sh scripts/sources/*.sh scripts/builders/*.sh
```

### Source directory not found

Check that the source fetcher script created a subdirectory in `WORK_DIR`.

## Design Documentation

See `../astroberry64-tools/DESIGN-external-builds.md` for detailed design decisions, rationale, and future plans.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test locally on RPI5
4. Submit PR with:
   - New/modified package configs
   - Updated README if adding packages
   - Patch documentation

## License

GPL-3.0 (same as Astroberry Server)

## Credits

- **INDI Library**: Jasem Mutlaq and INDI Team
- **Build System**: Astroberry64 Team
- **Original Astroberry**: Radek Kaczorek

## Resources

- **INDI Upstream**: https://github.com/indilib/indi
- **Astroberry64 Organization**: https://github.com/astroberry64
- **APT Repository**: https://astroberry64.github.io/astroberry64-repo/
