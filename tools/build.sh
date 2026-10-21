#!/usr/bin/env bash
# Builds crDroid 16.0 for metroid on this 14 GB RAM machine.
#
#   tools/build.sh [target] [extra mka args]    target: bacon (default) | bootimage | ...
#
# Env: VARIANT=userdebug (default) | user, JOBS=8 (default; lower if the build gets OOM-killed),
#      WITH_GMS=true to include Google apps (needs vendor/partner_gms in the manifest),
#      DEBUG=1 (default) -> WITH_ADB_INSECURE=true: adb (also in recovery) needs no
#      authorization. Bring-up only: anyone with a USB cable gets a shell. DEBUG=0 for daily use.
# Log: /home/hasan/android/logs/build_<date>_<target>.log (current_build.log links to it)
set -o pipefail  # no -u: build/envsetup.sh uses unset variables
TOP=${TOP:-/home/hasan/android/crdroid}
TARGET=${1:-bacon}
shift || true
VARIANT=${VARIANT:-userdebug}
JOBS=${JOBS:-8}
LOGS=/home/hasan/android/logs
mkdir -p "$LOGS"
LOG=$LOGS/build_$(date +%Y%m%d_%H%M)_${TARGET}.log
ln -sfn "$LOG" "$LOGS/current_build.log"

cd "$TOP" || exit 1
DEV=device/nothing/metroid
[ -f $DEV/kernel/out/Image ] || { echo "no $DEV/kernel/out: run tools/stage-stock-kernel.sh"; exit 2; }
[ -f vendor/nothing/metroid/metroid-vendor.mk ] || { echo "no vendor blobs: run $DEV/extract-files.py"; exit 2; }
[ -f vendor/lineage-priv/keys/releasekey.pk8 ] || { echo "no release keys in vendor/lineage-priv/keys"; exit 2; }

export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache CCACHE_DIR=/home/hasan/android/ccache
mkdir -p "$CCACHE_DIR"
ccache -M 50G >/dev/null
export BUILD_USERNAME=hasan BUILD_HOSTNAME=crdroid-metroid
export LC_ALL=C.UTF-8
[ "${DEBUG:-1}" = 1 ] && export WITH_ADB_INSECURE=true
# Keep Soong/Kati and the Java tools inside what 14 GB RAM + swap can hold.
# -k 0: keep going after a failure so one run reports every broken module.
# Android 17 builds with siso by default, which takes -local_jobs instead of -j.
if grep -q "NINJA_DEFAULT ninjaCommandType = NINJA_SISO" build/soong/ui/build/config.go 2>/dev/null; then
    export NINJA_ARGS="-local_jobs $JOBS -k ${KEEP_GOING:-0}"
else
    export NINJA_ARGS="-j$JOBS -k ${KEEP_GOING:-0}"
fi
export _JAVA_OPTIONS="-Xmx6g"

{
    echo "BUILD START $(date) target=$TARGET variant=$VARIANT jobs=$JOBS gms=${WITH_GMS:-false} adb_insecure=${WITH_ADB_INSECURE:-false}"
    # shellcheck disable=SC1091
    source build/envsetup.sh
    breakfast metroid "$VARIANT"
    m -j"$JOBS" "$TARGET" "$@"
    rc=$?
    echo "BUILD END $(date) target=$TARGET rc=$rc"
    exit $rc
} > "$LOG" 2>&1
rc=$?
echo "$LOG rc=$rc"
exit $rc
