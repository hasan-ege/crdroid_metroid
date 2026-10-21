#!/usr/bin/env bash
# Builds a ROM, keeps the zip under builds/, copies it to the phone and checks it.
# Run it yourself in a terminal (not from Claude): long builds can make the kernel's OOM killer
# pick the Claude process.
#
#   bash tools/release.sh                 # Android 17 (crDroid 17), release build (secure adb)
#   bash tools/release.sh 16              # Android 16 tree
#   bash tools/release.sh 17 --upload     # also upload to Internet Archive (ia configure first)
#   DEBUG=1 bash tools/release.sh         # bring-up build: adb without authorization
#   JOBS=4 bash tools/release.sh          # fewer parallel jobs if memory runs out
#
# The build log is ~/android/logs/current_build.log (tail -f it to follow).
set -o pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
ADB="$HERE/platform-tools/adb"
IA="${IA:-$HOME/.local/bin/ia}"

ANDROID=17
UPLOAD=0
for a in "$@"; do
    case "$a" in
        16|17) ANDROID=$a ;;
        --upload) UPLOAD=1 ;;
        *) echo "unknown argument: $a"; exit 2 ;;
    esac
done

if [ "$ANDROID" = 17 ]; then
    TOP=/home/hasan/android/crdroid17; TAG=A17; ROMVER=13.0
else
    TOP=/home/hasan/android/crdroid; TAG=A16; ROMVER=12.13
fi
export TOP
export DEBUG=${DEBUG:-0}
export JOBS=${JOBS:-6}

say() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

say "Building crDroid ($TAG) in $TOP — DEBUG=$DEBUG JOBS=$JOBS"
START=$(date +%s)
# Lower priority so the desktop stays usable; the build itself is unchanged.
nice -n 10 ionice -c 3 bash "$HERE/tools/build.sh" bacon || {
    echo "Build failed. Errors:"
    grep -n -E 'FAILED:|error:' "$HOME/android/logs/current_build.log" | head -20
    exit 1
}
echo "Build took $(( ($(date +%s) - START) / 60 )) min"

ZIP=$(ls -t "$TOP"/out/target/product/metroid/crDroidAndroid-*.zip | head -1)
[ -f "$ZIP" ] || { echo "no zip found in $TOP/out/target/product/metroid"; exit 1; }

# builds/crDroid-<ver>-<date>-<A16|A17>-<n>[-debug]
DATE=$(date +%Y%m%d)
N=$(ls -d "$HERE"/builds/crDroid-*-"$TAG"-* 2>/dev/null | sed -E 's/.*-'"$TAG"'-([0-9]+).*/\1/' | sort -n | tail -1)
N=$(( ${N:-0} + 1 ))
SUFFIX=""; [ "$DEBUG" = 1 ] && SUFFIX="-debug"
DEST="$HERE/builds/crDroid-$ROMVER-$DATE-$TAG-$N$SUFFIX"
mkdir -p "$DEST"
cp "$ZIP" "$DEST/"
(cd "$DEST" && sha256sum ./*.zip | sed 's#\./##' > SHA256SUMS)
SUM=$(cut -d' ' -f1 "$DEST/SHA256SUMS")
say "Saved $(basename "$DEST") — sha256 ${SUM:0:16}…"

say "Copying to the phone (plug it in and allow USB debugging if asked)"
"$ADB" wait-for-device
NAME=$(basename "$ZIP")
"$ADB" push "$DEST/$NAME" /sdcard/Download/ || exit 1
ONPHONE=$("$ADB" shell sha256sum "/sdcard/Download/$NAME" | cut -d' ' -f1)
if [ "$ONPHONE" = "$SUM" ]; then
    echo "On the phone: Download/$NAME — checksum OK"
else
    echo "CHECKSUM MISMATCH on the phone ($ONPHONE). Copy it again."; exit 1
fi

if [ "$UPLOAD" = 1 ]; then
    if [ "$DEBUG" = 1 ]; then
        echo "Not uploading a debug build (adb without authorization)."
    else
        ID="crdroid-metroid-$ANDROID.0-$DATE-$TAG-$N"
        say "Uploading to Internet Archive as $ID"
        (cd "$DEST" && "$IA" upload "$ID" "$NAME" SHA256SUMS --retries 10 --checksum \
            --metadata="mediatype:software" \
            --metadata="title:crDroid $ANDROID.0 for Nothing Phone (3) metroid - $DATE ($TAG-$N)" \
            --metadata="creator:hasan-ege" \
            --metadata="date:$(date +%F)" \
            --metadata="subject:crDroid;Nothing Phone (3);metroid;custom ROM;Android $ANDROID;OpenGlyph" \
            --metadata="description:Unofficial crDroid for the Nothing Phone (3) (A024, metroid) with OpenGlyph. Release build (adb requires authorization). Source and notes: https://github.com/hasan-ege/crdroid_metroid . Flash at your own risk." ) \
            && echo "https://archive.org/details/$ID"
    fi
fi

say "Done"
