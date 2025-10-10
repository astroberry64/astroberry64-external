# INDI Core Library Build

**Version**: 2.1.6 (2025-10-08)
**Source**: https://github.com/indilib/indi
**Build System**: Debian (uses debian/ from upstream git)

## Build Strategy

INDI maintains its own `debian/` directory in the git repository, so we:
1. Clone the git repo at the specified tag
2. Install build dependencies from `debian/control`
3. Build directly using `dpkg-buildpackage` or `debuild`
4. No custom .deb creation needed

## Packages Built

From this single source, multiple binary packages are created:
- `libindi1` - Core library (runtime)
- `libindi-data` - Data files
- `libindi-dev` - Development headers
- `indi-bin` - INDI server and tools

## Patches

Currently no patches applied. This directory structure is ready if we need to patch for Debian Trixie compatibility.

### When to add patches:
- Dependency version mismatches in `debian/control`
- Build system issues specific to Trixie
- Missing dependencies in Trixie vs Ubuntu

### Patch structure:
- `patches/debian/` - Patches to debian/* files (control, rules, etc.)
- `patches/source/` - Patches to source code

## Testing

After building, verify:
```bash
# Check package versions
dpkg -I libindi1_*.deb

# Install and test
sudo apt install ./libindi1_*.deb ./libindi-data_*.deb ./indi-bin_*.deb

# Verify INDI server runs
indiserver -v
```

## Upstream Tracking

- **Upstream release frequency**: ~Monthly
- **Watch for**: Major version bumps that might change dependencies
- **debian/ maintenance**: Jasem Mutlaq maintains debian/ in git
- **No need to sync from PPA**: debian/ is authoritative in git

## Notes

- INDI uses CMake but debian/rules handles the build
- Builds cleanly on Debian Trixie arm64 (confirmed via testing)
- This is a core dependency for indi-3rdparty drivers and KStars
