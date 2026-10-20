#!/bin/sh
# Read-only backup of every phone partition except the big/replaceable ones, over adb + su.
# Each image is checked: sha256 computed on the phone must equal sha256 of the local copy.
#
#   tools/backup-partitions.sh [output dir]      (default: backup/<date>-<build>)
#
# Nothing is written to the phone. The output holds device-unique data (IMEI/modem NV in
# modemst1/modemst2/fsg/fsc, calibration in persist, keys in keystore/secdata): keep it
# private and never flash another phone's copy.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
adb=${ADB:-$here/platform-tools/adb}

build=$("$adb" shell getprop ro.build.display.id | tr -d '\r')
out=${1:-$here/backup/$(date +%Y%m%d-%H%M)-$build}
mkdir -p "$out"

# Whole LUNs (sda..sdf), dynamic system (super), user data, crash dumps and logs are skipped.
skip='^(sd[a-z]|super|userdata|rawdump|nt_log|nt_kmsg|logfs|xbl_sc_logs)$'

parts=$("$adb" shell "su -c 'ls /dev/block/by-name'" | tr -d '\r' | grep -Ev "$skip")
: > "$out/SHA256SUMS"
: > "$out/FAILED"
for p in $parts; do
    "$adb" exec-out "su -c 'dd if=/dev/block/by-name/$p bs=1M 2>/dev/null'" > "$out/$p.img"
    remote=$("$adb" shell "su -c 'sha256sum /dev/block/by-name/$p'" | cut -d' ' -f1)
    local=$(sha256sum "$out/$p.img" | cut -d' ' -f1)
    if [ -n "$remote" ] && [ "$remote" = "$local" ]; then
        echo "$local  $p.img" >> "$out/SHA256SUMS"
        printf 'ok   %-24s %s\n' "$p" "$(du -h "$out/$p.img" | cut -f1)"
    else
        echo "$p" >> "$out/FAILED"
        printf 'FAIL %-24s phone=%s local=%s\n' "$p" "$remote" "$local"
    fi
done

"$adb" shell 'getprop ro.build.fingerprint; getprop ro.boot.slot_suffix; getprop ro.boot.vbmeta.digest' \
    > "$out/DEVICE.txt"
chmod -R go-rwx "$out"
echo
echo "$(wc -l < "$out/SHA256SUMS") ok, $(wc -l < "$out/FAILED") failed -> $out"
[ ! -s "$out/FAILED" ]
