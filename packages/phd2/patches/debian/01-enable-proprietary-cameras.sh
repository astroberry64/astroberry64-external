#!/bin/bash
# Patch debian/rules to enable proprietary camera SDKs
#
# Changes OPENSOURCE_ONLY from 1 to 0 to enable:
# - ZWO/ASI cameras (libASICamera2)
# - QHY cameras (libqhyccd)
# - Player One cameras (libPlayerOneCamera)
# - SVBony cameras (libSVBCameraSDK)
# - ToupTek/Altair cameras
# - OGMA cameras
#
# All of these have ARM64 libraries bundled in the PHD2 source

set -e

FILE="debian/rules"

if [ ! -f "$FILE" ]; then
    echo "[patch-sh] ERROR: $FILE not found"
    exit 1
fi

# Check if already patched
if grep -q "DOPENSOURCE_ONLY=0" "$FILE"; then
    echo "[patch-sh] $FILE already patched, skipping"
    exit 0
fi

# Change OPENSOURCE_ONLY from 1 to 0
sed -i 's/-DOPENSOURCE_ONLY=1/-DOPENSOURCE_ONLY=0/g' "$FILE"

if ! grep -q "DOPENSOURCE_ONLY=0" "$FILE"; then
    echo "[patch-sh] ERROR: Failed to patch $FILE"
    exit 1
fi

echo "[patch-sh] Patched $FILE to enable proprietary camera SDKs"
echo "[patch-sh] This enables ZWO, QHY, Player One, SVBony, ToupTek, and OGMA cameras"
