#!/usr/bin/env bash
# Brings the INACTIVE slot's firmware to stock B4.1-260814-1733 from a running, rooted system,
# the same way update_engine writes firmware during an OTA (block devices, inactive slot only).
# Needed because the bootloader refuses `fastboot flash` on critical partitions
# ("Device critical unlocked: false").
#
#   tools/sync-inactive-firmware.sh          dry run: compares and lists what differs
#   tools/sync-inactive-firmware.sh --yes    writes the differing partitions, then verifies
#
# Refuses to touch the active slot: the running slot keeps booting whatever happens here.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
adb="${ADB:-$here/platform-tools/adb}"
fw="$here/stock/B4.1-260814-1733/firmware"
yes=${1:-}
tmp=/data/local/tmp/fw-sync

(cd "$fw" && sha256sum --quiet -c FIRMWARE.sha256) || { echo "!! firmware images changed on disk" >&2; exit 1; }
[[ $("$adb" shell 'su -c id -u' | tr -d '\r') == 0 ]] || { echo "!! no root over adb" >&2; exit 1; }

active=$("$adb" shell getprop ro.boot.slot_suffix | tr -d '\r')
case $active in _a) target=_b ;; _b) target=_a ;; *) echo "!! unknown slot '$active'" >&2; exit 1 ;; esac
echo "active slot $active, writing only $target"

"$adb" shell "rm -rf $tmp; mkdir -p $tmp"
todo=()
for img in "$fw"/*.img; do
    p=$(basename "$img" .img)
    size=$(stat -c %s "$img")
    want=$(sha256sum < "$img" | cut -d' ' -f1)
    have=$("$adb" shell "su -c 'head -c $size /dev/block/by-name/$p$target | sha256sum'" | cut -d' ' -f1)
    if [[ $have == "$want" ]]; then
        printf '  ok    %-14s\n' "$p$target"
    else
        printf '  DIFF  %-14s\n' "$p$target"
        todo+=("$p")
    fi
done

if (( ${#todo[@]} == 0 )); then echo "inactive slot already has B4.1 firmware"; exit 0; fi
if [[ $yes != --yes ]]; then echo "(dry run; ${#todo[@]} partition(s) differ, add --yes to write)"; exit 0; fi

for p in "${todo[@]}"; do
    img="$fw/$p.img"; size=$(stat -c %s "$img"); want=$(sha256sum < "$img" | cut -d' ' -f1)
    "$adb" push "$img" "$tmp/$p.img" >/dev/null
    "$adb" shell "su -c 'dd if=$tmp/$p.img of=/dev/block/by-name/$p$target bs=1M conv=fsync 2>/dev/null'"
    have=$("$adb" shell "su -c 'head -c $size /dev/block/by-name/$p$target | sha256sum'" | cut -d' ' -f1)
    [[ $have == "$want" ]] || { echo "!! $p$target verify failed (have $have)" >&2; exit 1; }
    printf '  wrote %-14s verified\n' "$p$target"
done
"$adb" shell "rm -rf $tmp"
echo "inactive slot $target now has B4.1-260814-1733 firmware"
