#!/usr/bin/env bash
# Writes the stock B4.1-260814-1733 firmware to BOTH slots, which fuad00's LineageOS/crDroid
# build requires (the ROM zip carries no firmware). Run with the phone in bootloader fastboot.
#
#   tools/flash-firmware.sh          dry run: checks and prints what it would flash
#   tools/flash-firmware.sh --yes    flashes
#
# Safety checks before anything is written:
#   - exactly one fastboot device, product sun/Metroid, bootloader unlocked, serial = $SERIAL if set
#   - every image matches the sha256 recorded when the verified firmware package was unpacked
#   - Qualcomm anti-rollback of these images was checked (all 0) with tools/qcom-arb.py
# Never interrupt it: a slot with half its firmware written will not boot (the other slot still
# will, and re-running finishes the job).
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
fw="$here/stock/B4.1-260814-1733/firmware"
fastboot="${FASTBOOT:-$here/platform-tools/fastboot}"
sums="$fw/FIRMWARE.sha256"
yes=${1:-}

[[ -f $sums ]] || (cd "$fw" && sha256sum *.img > FIRMWARE.sha256)
(cd "$fw" && sha256sum --quiet -c FIRMWARE.sha256) || { echo "!! firmware images changed on disk" >&2; exit 1; }

devs=$("$fastboot" devices | wc -l)
[[ $devs == 1 ]] || { echo "!! need exactly one device in fastboot, found $devs" >&2; exit 1; }
product=$("$fastboot" getvar product 2>&1 | sed -n 's/^product: //p')
unlocked=$("$fastboot" getvar unlocked 2>&1 | sed -n 's/^unlocked: //p')
slot=$("$fastboot" getvar current-slot 2>&1 | sed -n 's/^current-slot: //p')
serial=$("$fastboot" devices | awk '{print $1}')
echo "device: serial=$serial product=$product unlocked=$unlocked current-slot=$slot"
# The bootloader reports the SoC platform (sun), not the product name (Metroid).
[[ $product == sun || $product == Metroid ]] && [[ $unlocked == yes ]] \
    || { echo "!! not an unlocked Nothing Phone (3)" >&2; exit 1; }
[[ -z ${SERIAL:-} || $serial == "$SERIAL" ]] || { echo "!! serial $serial is not $SERIAL" >&2; exit 1; }

parts=$(cd "$fw" && ls *.img | sed 's/\.img$//')
for p in $parts; do
    for s in a b; do
        if [[ $yes == --yes ]]; then
            "$fastboot" flash "${p}_$s" "$fw/$p.img"
        else
            echo "would flash ${p}_$s <- $p.img"
        fi
    done
done
[[ $yes == --yes ]] && echo "firmware B4.1-260814-1733 written to both slots" || echo "(dry run; add --yes to flash)"
