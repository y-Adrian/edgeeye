#!/bin/bash
# Update Milk-V Duo S SD boot partition with a new kernel+DTB (boot.sd).
#
# U-Boot loads "boot.sd" from the FAT boot partition ROOT (not rawimages/).
# Use the FIT image from SDK rawimages/, NOT the CIMG-wrapped boot.sd in install root.
#
# Usage (macOS/Linux, SD boot partition mounted at $MOUNT):
#   MOUNT=/Volumes/boot ./update_boot_sd.sh
#
# Usage (manual copy):
#   cp $SRC_BOOT $MOUNT/boot.sd
#   # Do NOT replace fip.bin unless you rebuilt u-boot.

set -euo pipefail

EDGEEYE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUO_SDK_ROOT="${DUO_SDK_ROOT:-$(cd "$EDGEEYE_ROOT/../duo-sdk" 2>/dev/null && pwd)}"
SDK_OUT="${DUO_SDK_ROOT}/install/soc_sg2000_milkv_duos_musl_riscv64_sd"
SRC_BOOT="${SDK_OUT}/rawimages/boot.sd"
SRC_FIP="${SDK_OUT}/fip.bin"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$DUO_SDK_ROOT" ] || die "missing duo-sdk — set DUO_SDK_ROOT or clone next to edgeeye-duos"
[ -f "$SRC_BOOT" ] || die "missing $SRC_BOOT — in SDK: source scripts/envsetup from edgeeye-duos, then pack_boot"

# FIT magic (boot.itb), not CIMG
MAGIC=$(dd if="$SRC_BOOT" bs=4 count=1 2>/dev/null | xxd -p)
if [ "$MAGIC" = "43494d47" ]; then
	die "$SRC_BOOT looks CIMG-wrapped; use rawimages/boot.sd (FIT), not install/boot.sd"
fi

echo "Source boot.sd: $SRC_BOOT ($(wc -c < "$SRC_BOOT") bytes, FIT)"
echo "Expected on SD:  <boot-partition>/boot.sd  (FAT root, same level as fip.bin)"

if [ -n "${MOUNT:-}" ]; then
	[ -d "$MOUNT" ] || die "mount point not found: $MOUNT"
	[ -f "$MOUNT/fip.bin" ] || echo "WARN: $MOUNT/fip.bin not found — is this the boot partition?"
	cp -v "$SRC_BOOT" "$MOUNT/boot.sd"
	# Optional: only when u-boot was rebuilt
	if [ "${UPDATE_FIP:-0}" = "1" ] && [ -f "$SRC_FIP" ]; then
		cp -v "$SRC_FIP" "$MOUNT/fip.bin"
	fi
	sync
	echo "Done. Eject SD card safely, then reboot the board."
else
	echo ""
	echo "Set MOUNT to your SD boot partition path, e.g.:"
	echo "  MOUNT=/Volumes/boot $0"
fi
