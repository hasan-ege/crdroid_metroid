#!/bin/sh
# Builds the temporary hardware test app (not part of the ROM) and prints the APK path.
#   sh tools/device-test/build.sh && adb install -r tools/device-test/sensorprobe.apk
set -e
here=$(cd "$(dirname "$0")" && pwd)
top=$(cd "$here/../.." && pwd)
bt=$(ls -d "$top"/tools-ext/build-tools/*/ | head -1)
jar=${ANDROID_JAR:-/home/hasan/android/crdroid/prebuilts/sdk/36/public/android.jar}
out=$here/sensorprobe.apk
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/cls"
"$bt/aapt2" link -I "$jar" --manifest "$here/AndroidManifest.xml" -o "$w/unsigned.apk"
javac --release 17 -nowarn -cp "$jar" -d "$w/cls" "$here"/src/org/openglyph/sensorprobe/*.java
"$bt/d8" --min-api 33 --lib "$jar" --output "$w" $(find "$w/cls" -name '*.class')
(cd "$w" && zip -q unsigned.apk classes.dex)
"$bt/zipalign" -f 4 "$w/unsigned.apk" "$w/aligned.apk"
ks="$top/open-glyph/tools/test-toy/debug.keystore"
"$bt/apksigner" sign --ks "$ks" --ks-pass pass:android --out "$out" "$w/aligned.apk"
echo "$out"
