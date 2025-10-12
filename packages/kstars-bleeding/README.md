# KStars Bleeding Edge - Build Configuration

**Source**: ppa:mutlaqja/ppa
**Maintainer**: Jasem Mutlaq <mutlaqja@ikarustech.com>
**Homepage**: https://edu.kde.org/kstars/

## Patches

### debian/01-fix-build-for-non-debian-maintainers.patch

**What it fixes**: Replaces restricted Debian Qt/KDE team build infrastructure with standard debhelper

**Why needed**:
The Ubuntu PPA package uses:
```makefile
include /usr/share/pkg-kde-tools/qt-kde-team/2/debian-qt-kde.mk
```

This include is **restricted by policy** to packages maintained by `debian-qt-kde@lists.debian.org`.
Since Jasem Mutlaq maintains this package, not the Debian Qt/KDE team, the build fails with:
```
debian_qt_kde.mk usage denied by policy.
```

**What the patch does**:
1. **Removes restricted includes**: Deletes the debian-qt-kde.mk and l10n-packages.mk includes
2. **Replaces with standard debhelper**: Uses modern `dh $@ --with kf5` pattern
3. **Adds parallel build support**: `export DEB_BUILD_OPTIONS := parallel=$(shell nproc)`
4. **Preserves optimization**: Keeps `export DEB_BUILD_MAINT_OPTIONS = optimize=-lto`
5. **Keeps all overrides**: The `override_dh_strip` and `override_dh_auto_configure` sections are untouched

**Technical explanation**:
- `%:` = pattern rule matching all targets (build, binary, clean, etc.)
- `dh $@` = run debhelper for the matched target
- `--with kf5` = load KDE Frameworks 5 helpers (same functionality as the restricted makefile)
- This is the standard modern approach for KDE packages outside Debian

**Trade-offs**:
- ✅ **Gains**: Works for anyone, parallel builds, standard approach
- ⚠️ **Loses**: Automatic l10n package version handling (minor, doesn't affect functionality)

**When can it be removed?**:
- If Jasem changes his PPA packaging to not use restricted includes
- If the package is ever adopted by official Debian Qt/KDE team
- Check each new version from PPA to see if upstream changed their approach

**Should it go upstream?**:
- Possibly - Jasem could switch to standard debhelper in his PPA
- The restricted makefiles are meant for Debian team use only
- Standard debhelper would make his PPA more portable

## Build Dependencies

KStars bleeding edge from ppa:mutlaqja/ppa requires:
- Qt5 (Qt 5.15 available in Debian Trixie)
- KDE Frameworks 5 (KF5)
- INDI library (>= 2.0) - built from our astroberry64-external
- CMake build system

**Note**: KStars source supports both Qt5/KF5 and Qt6/KF6, but Jasem's PPA builds with Qt5/KF5 for broader compatibility.

## Notes

- This is the "bleeding edge" version of KStars with latest features
- Built with Qt5/KF5 for maximum compatibility
- Ubuntu Noble source packages rebuild for Debian Trixie with patching
- Package version format: `6:3.7.9+202510070847~ubuntu24.04.1`
  - Epoch 6 due to KDE versioning history
  - Date stamp: 202510070847 = 2025-10-07 08:47 UTC
  - Targeted for Ubuntu 24.04 (Noble), adapted for Trixie

## Testing

After building, verify:
```bash
# Check package installed
dpkg -l | grep kstars-bleeding

# Check INDI integration
kstars --version

# Launch KStars
kstars
```
