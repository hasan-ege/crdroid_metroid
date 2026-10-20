#!/bin/sh
# Fills device/nothing/metroid/kernel/out/ (the layout fuad00's stage-kernel.sh produces from a
# Kleaf build) with the *stock* B4.1-260814-1733 kernel instead: same Image, DTB, DTBO and
# modules the phone runs today, so they match the stock vendor blobs and firmware.
#
#   tools/stage-stock-kernel.sh [source top]     (default /home/hasan/android/crdroid)
#
#   Image                  boot.img kernel (GKI 6.6.127-android15-8)
#   dtb.img                vendor_boot.img dtb
#   dtbo.img               dtbo.img
#   vendor_ramdisk/*.ko    vendor_boot ramdisk modules, plus anything the device tree's load
#                          lists need that stock keeps in vendor_dlkm (e.g. focaltech_tp.ko)
#   vendor_dlkm/           vendor_dlkm.img lib/modules (modules + stock load/dep files)
#   system_dlkm/           system_dlkm.img lib/modules
#   kernel-headers.tar.gz  techpack UAPI headers from NothingOSS b/mr at the B4.1 commit
#
# Needs fsck.erofs (erofs-utils), lz4 and cpio.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
top=${1:-/home/hasan/android/crdroid}
dev="$top/device/nothing/metroid"
out="$dev/kernel/out"
stock="$here/stock/B4.1-260814-1733"
unpack="$top/system/tools/mkbootimg/unpack_bootimg.py"

for t in fsck.erofs lz4 cpio; do
    command -v $t >/dev/null || { echo "missing $t (sudo sh tools/setup-host.sh)" >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
rm -rf "$out"
mkdir -p "$out/vendor_ramdisk" "$out/vendor_dlkm" "$out/system_dlkm"

python3 -I "$unpack" --boot_img "$stock/boot/boot.img" --out "$work/boot" >/dev/null
cp "$work/boot/kernel" "$out/Image"

python3 -I "$unpack" --boot_img "$stock/boot/vendor_boot.img" --out "$work/vb" >/dev/null
cp "$work/vb/dtb" "$out/dtb.img"
cp "$stock/boot/dtbo.img" "$out/dtbo.img"

mkdir -p "$work/rd"
for r in "$work"/vb/vendor_ramdisk*; do
    lz4 -dc "$r" | (cd "$work/rd" && cpio -idm --quiet)
done
cp "$work"/rd/lib/modules/*.ko "$out/vendor_ramdisk/"

for p in vendor_dlkm system_dlkm; do
    fsck.erofs --extract="$work/$p" "$stock/logical/$p.img" >/dev/null
    cp -a "$work/$p/lib/modules/." "$out/$p/"
done

# Modules the device tree loads from the vendor ramdisk but stock ships only in vendor_dlkm.
for list in "$dev/modules.load.vendor_boot" "$dev/modules.load.recovery"; do
    while read -r ko; do
        [ -n "$ko" ] && [ ! -f "$out/vendor_ramdisk/$ko" ] || continue
        if [ -f "$out/vendor_dlkm/$ko" ]; then
            cp "$out/vendor_dlkm/$ko" "$out/vendor_ramdisk/"
            echo "vendor_ramdisk: + $ko (from vendor_dlkm)"
        else
            echo "!! $ko is in $(basename "$list") but not in any stock image" >&2
            exit 1
        fi
    done < "$list"
done

bash "$dev/meta/kernel/generate-kernel-headers.sh" "$here/src/nothing-kernel" \
    "$out/kernel-headers.tar.gz" >/dev/null

{
    echo "stock kernel: Nothing OS B4.1-260814-1733"
    strings "$out/Image" | grep -m1 '^Linux version'
    echo "headers: NothingOSS sm8735/b/mr $(git -C "$here/src/nothing-kernel" log -1 --format=%h)"
    (cd "$out" && sha256sum Image dtb.img dtbo.img kernel-headers.tar.gz)
} > "$out/build-info.txt"

echo "kernel/out: $(ls "$out/vendor_ramdisk" | wc -l) ramdisk, $(ls "$out/vendor_dlkm" | grep -c '\.ko$') vendor_dlkm, $(ls "$out/system_dlkm" | grep -c '\.ko$') system_dlkm modules"
