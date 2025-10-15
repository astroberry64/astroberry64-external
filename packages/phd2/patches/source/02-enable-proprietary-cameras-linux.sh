#!/bin/bash
# Patch to enable proprietary camera SDKs on Linux
#
# Problem: When OPENSOURCE_ONLY=0, PHD2's thirdparty.cmake tries to FetchContent
# the OGMA SDK for all platforms, but in Debian's disconnected build environment
# (FETCHCONTENT_FULLY_DISCONNECTED=ON), this fails.
#
# Solution: Wrap the OGMA FetchContent in if(WIN32) since:
# - Linux already has OGMA libraries bundled in cameras/ogmalibs/
# - The FetchContent is only used on Windows anyway
# - Linux finds the library later using find_library()

set -e

FILE="thirdparty/thirdparty.cmake"

if [ ! -f "$FILE" ]; then
    echo "[patch-sh] ERROR: $FILE not found"
    exit 1
fi

# Check if already patched
if grep -q "if(WIN32)  # OGMA SDK fetch only needed on Windows" "$FILE"; then
    echo "[patch-sh] $FILE already patched, skipping"
    exit 0
fi

# Find the line number where "if (NOT OPENSOURCE_ONLY)" appears (around line 599)
# We know OGMA FetchContent starts shortly after
LINE_NUM=$(grep -n "^if (NOT OPENSOURCE_ONLY)" "$FILE" | head -1 | cut -d: -f1)

if [ -z "$LINE_NUM" ]; then
    echo "[patch-sh] ERROR: Could not find 'if (NOT OPENSOURCE_ONLY)' in $FILE"
    exit 1
fi

# Verify OGMA is in the next 20 lines
OGMA_CHECK=$(sed -n "${LINE_NUM},$((LINE_NUM + 20))p" "$FILE" | grep -c "OGMAcamSDK")
if [ "$OGMA_CHECK" -eq 0 ]; then
    echo "[patch-sh] ERROR: OGMAcamSDK not found near line $LINE_NUM in $FILE"
    exit 1
fi

# Use sed to wrap the OGMAcamSDK FetchContent block in if(WIN32)
# We need to:
# 1. Add "if(WIN32)  # OGMA SDK fetch only needed on Windows" after "if (NOT OPENSOURCE_ONLY)"
# 2. Add "endif()  # WIN32" after the existing "endif()" that closes the OGMA block

sed -i "${LINE_NUM}a\\  if(WIN32)  # OGMA SDK fetch only needed on Windows" "$FILE"

# Now find the endif() that closes the OGMA FetchContent block (should be around line 612-615)
# It's the first "endif()" after "if (NOT OPENSOURCE_ONLY)" and before "# Various camera libraries"
ENDIF_LINE=$(awk "/^if \(NOT OPENSOURCE_ONLY\)/,/^# Various camera libraries/ {if (/^endif\(\)/) {print NR; exit}}" "$FILE")

if [ -z "$ENDIF_LINE" ]; then
    echo "[patch-sh] ERROR: Could not find endif() for OGMA block in $FILE"
    exit 1
fi

# Add the closing endif for WIN32 before the OPENSOURCE_ONLY endif
sed -i "${ENDIF_LINE}i\\  endif()  # WIN32" "$FILE"

echo "[patch-sh] Patched $FILE to make OGMA FetchContent Windows-only"
echo "[patch-sh] This allows proprietary cameras to work on Linux without FetchContent issues"
