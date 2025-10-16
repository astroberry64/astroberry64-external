#!/bin/bash
# Patch to enable proprietary camera SDKs on Linux
#
# Problem: When OPENSOURCE_ONLY=0, PHD2's thirdparty.cmake has TWO separate OGMA blocks:
# 1. FetchContent the OGMA SDK (fails in disconnected build)
# 2. find_library for OGMA drivers (fails - no bundled libraries on Linux)
#
# Solution: Wrap EACH block separately in if(WIN32) to skip OGMA on Linux
# - OGMA cameras will only work on Windows
# - Other proprietary cameras (ZWO, QHY, Player One, SVBony, ToupTek) will work on Linux

set -e

FILE="thirdparty/thirdparty.cmake"

if [ ! -f "$FILE" ]; then
    echo "[patch-sh] ERROR: $FILE not found"
    exit 1
fi

# Check if already patched
if grep -q "if(WIN32)  # OGMA support is Windows-only" "$FILE"; then
    echo "[patch-sh] $FILE already patched, skipping"
    exit 0
fi

echo "[patch-sh] Patching $FILE to make OGMA support Windows-only"

#
# Strategy: Insert from bottom to top so line numbers don't shift
#

#
# Block 2: Wrap OGMA find_library in if(WIN32) - DO THIS FIRST
#

# Find "find_library(ogmacam" line
OGMA_FIND_LINE=$(grep -n "^      find_library(ogmacam" "$FILE" | head -1 | cut -d: -f1)

if [ -z "$OGMA_FIND_LINE" ]; then
    echo "[patch-sh] ERROR: Could not find 'find_library(ogmacam' in $FILE"
    exit 1
fi

# Find "list(APPEND PHD_INSTALL_LIBS ${ogmacam})" - last line of this block
OGMA_APPEND_LINE=$(grep -n "list(APPEND PHD_INSTALL_LIBS.*ogmacam" "$FILE" | head -1 | cut -d: -f1)

if [ -z "$OGMA_APPEND_LINE" ]; then
    echo "[patch-sh] ERROR: Could not find 'list(APPEND PHD_INSTALL_LIBS.*ogmacam)' in $FILE"
    exit 1
fi

# Sanity check: append line should be after find_library line
if [ "$OGMA_APPEND_LINE" -le "$OGMA_FIND_LINE" ]; then
    echo "[patch-sh] ERROR: OGMA block structure unexpected (append at line $OGMA_APPEND_LINE, find at $OGMA_FIND_LINE)"
    exit 1
fi

# Insert endif() AFTER the append line (bottom first)
sed -i "${OGMA_APPEND_LINE}a\\      endif()  # WIN32 - OGMA support" "$FILE"

# Insert if(WIN32) BEFORE find_library (top second)
sed -i "${OGMA_FIND_LINE}i\\      if(WIN32)  # OGMA support is Windows-only" "$FILE"

echo "[patch-sh] Wrapped OGMA find_library block (lines $OGMA_FIND_LINE-$OGMA_APPEND_LINE) in if(WIN32)"

#
# Block 1: Wrap OGMA FetchContent in if(WIN32) - DO THIS SECOND
#
# Note: Line numbers have shifted by +2 from the two insertions above
#

# Find "if (NOT OPENSOURCE_ONLY)" line
OPENSOURCE_LINE=$(grep -n "^if (NOT OPENSOURCE_ONLY)" "$FILE" | head -1 | cut -d: -f1)

if [ -z "$OPENSOURCE_LINE" ]; then
    echo "[patch-sh] ERROR: Could not find 'if (NOT OPENSOURCE_ONLY)' in $FILE"
    exit 1
fi

# Verify OGMA is nearby
if ! sed -n "${OPENSOURCE_LINE},$((OPENSOURCE_LINE + 20))p" "$FILE" | grep -q "OGMAcamSDK"; then
    echo "[patch-sh] ERROR: OGMAcamSDK not found near line $OPENSOURCE_LINE in $FILE"
    exit 1
fi

# Find FetchContent_MakeAvailable line
FETCHCONTENT_LINE=$(sed -n "${OPENSOURCE_LINE},\$p" "$FILE" | grep -n "FetchContent_MakeAvailable(OGMAcamSDK)" | head -1 | cut -d: -f1)
if [ -z "$FETCHCONTENT_LINE" ]; then
    echo "[patch-sh] ERROR: Could not find 'FetchContent_MakeAvailable(OGMAcamSDK)' in $FILE"
    exit 1
fi
FETCHCONTENT_LINE=$((OPENSOURCE_LINE + FETCHCONTENT_LINE - 1))

# Find the first "^endif()" after FetchContent - this closes the outer "if (NOT OPENSOURCE_ONLY)" block
OUTER_ENDIF=$(sed -n "$((FETCHCONTENT_LINE + 1)),\$p" "$FILE" | grep -n "^endif()" | head -1 | cut -d: -f1)
if [ -z "$OUTER_ENDIF" ]; then
    echo "[patch-sh] ERROR: Could not find endif() after FetchContent_MakeAvailable"
    exit 1
fi
OUTER_ENDIF=$((FETCHCONTENT_LINE + OUTER_ENDIF - 1))

# Insert our endif() BEFORE the outer endif() (bottom first)
sed -i "${OUTER_ENDIF}i\\  endif()  # WIN32 - OGMA FetchContent" "$FILE"

# Insert if(WIN32) AFTER "if (NOT OPENSOURCE_ONLY)" (top second)
sed -i "${OPENSOURCE_LINE}a\\  if(WIN32)  # OGMA support is Windows-only" "$FILE"

echo "[patch-sh] Wrapped OGMA FetchContent block (lines $OPENSOURCE_LINE-$OUTER_ENDIF) in if(WIN32)"
echo ""
echo "[patch-sh] ✅ Patched $FILE successfully"
echo "[patch-sh] PHD2 will build on Linux with ZWO, QHY, Player One, SVBony, and ToupTek camera support"
echo "[patch-sh] OGMA cameras are excluded on Linux (no bundled libraries available)"
