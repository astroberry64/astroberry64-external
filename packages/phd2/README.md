# PHD2 Guiding - Build Configuration

**Source**: https://github.com/OpenPHDGuiding/phd2
**Maintainer**: Patrick Chevalley <pch@ap-i.net>
**Homepage**: https://openphdguiding.org/

## Overview

PHD2 is the enhanced second generation of the popular PHD (Push Here Dummy) telescope auto-guiding software. This package tracks both stable releases and development snapshots to provide the latest features and camera SDK updates.

**Version Tracking**: All git tags (stable + dev snapshots)
- Stable releases: v2.6.13, v2.6.12, etc.
- Development snapshots: v2.6.13dev7, v2.6.13dev6, etc.
- Latest as of 2025-01-15: v2.6.13dev7 (159 commits ahead of v2.6.13 stable)

## Patches

### 01-fix-missing-iomanip-include.patch
Fixes compilation error in test code caused by missing `#include <iomanip>`.
- **Issue**: `gp_guider_test.cpp` uses `std::setw()` without including `<iomanip>`
- **Impact**: Compilation fails with GCC 14.2.0
- **Fix**: Adds `#include <iomanip>` after `#include <iostream>`
- **Status**: Should be reported upstream

### Camera Driver Support

This baseline build uses **INDI-only camera drivers** (no proprietary SDKs):
- Camera access via INDI server
- Compatible with libindi from astroberry64-external
- Open source only, no binary blobs
- Same approach as Patrick Chevalley's ppa:pch/phd2

### Future: Native Camera SDK Support

Native SDK support can be added later by removing `-DOPENSOURCE_ONLY=1`:
- Would enable: ZWO, QHY, ToupTek, SVBony, Player One, Altair cameras
- Trade-off: Includes non-free binary blobs vs better camera performance
- Requires additional patches to handle SDK fetching during build
- Deferred until baseline package is stable in CI/CD

## Build Dependencies

PHD2 requires:
- wxWidgets 3.2 or 3.0 (wxGTK)
- INDI library (>= 2.0) - built from our astroberry64-external
- libcfitsio (FITS file handling)
- OpenCV (image processing)
- libnova (astronomical calculations)
- libcurl (network communication)
- Eigen3 (matrix calculations)
- CMake build system

## Build Configuration

PHD2's debian/rules configures cmake with:
- `-DUSE_SYSTEM_LIBINDI=1` - Use our built INDI library (not bundled)
- `-DUSE_SYSTEM_GTEST=1` - Use system Google Test library
- `-DUSE_SYSTEM_LIBUSB=1` - Use system libusb library
- ~~`-DOPENSOURCE_ONLY=1`~~ - Removed by our patch to enable proprietary SDKs

## Version Tracking Strategy

**Why track both stable and dev?**

Looking at the v2.6.13 cycle:
- v2.6.13 stable released: Dec 22, 2023
- v2.6.13dev1-7 released: Dec 2023 → Jan 2025
- Development ahead by **159 commits** with active camera SDK updates

Development releases contain:
- Latest camera SDK updates
- Bug fixes
- Performance improvements
- New features
- Well-tested by upstream before tagging

Users benefit from recent updates while maintaining reasonable stability.

## Integration with KStars

PHD2 integrates with KStars via the Ekos guide module:
- KStars can launch and control PHD2 via network interface
- Binary must be named `phd2` for KStars to find it
- INDI integration for camera access (when not using native drivers)

## Notes

- PHD2 includes both INDI-based and native camera drivers
- Native drivers provide better performance and feature access
- Built with system INDI library from astroberry64-external
- wxWidgets 3.2 preferred but falls back to 3.0 if unavailable
- Package size: ~10-15 MB (includes camera SDKs)

## Testing

After building, verify:
```bash
# Check package installed
dpkg -l | grep phd2

# Check version
phd2 --version

# Launch PHD2 (requires X11)
phd2

# Test INDI integration (if using INDI drivers)
indiserver -v
```

## References

- [PHD2 Development Snapshots](https://openphdguiding.org/development-snapshots/)
- [PHD2 GitHub Repository](https://github.com/OpenPHDGuiding/phd2)
- [Building PHD2 on Linux Wiki](https://github.com/OpenPHDGuiding/phd2/wiki/BuildingPHD2OnLinux)
- [PHD2 User Guide](https://openphdguiding.org/phd2-user-guide/)
