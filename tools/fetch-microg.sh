#!/usr/bin/env bash
# Fetches the official microG release into vendor/microg and verifies it: the GPG signature of
# each APK against the microG Project Team key, and the APK signing certificate (NOGAPPS
# Project, the one microG signs with and the framework lets spoof Google's signature).
#   tools/fetch-microg.sh [version]   (default v0.3.17.252432)
set -euo pipefail
VER=${1:-v0.3.17.252432}
TOP=${TOP:-/home/hasan/android/crdroid}
DEST=$TOP/vendor/microg
KEY=22F796D6E62E6625A0BCEFEA7F979A66F3E08422
CERT_SHA1=10321bd893f69af97f7573aafe9de1dc0901f3a1
APKSIGNER=$(ls -d "$(dirname "$0")"/../tools-ext/build-tools/*/apksigner | head -1)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
export GNUPGHOME=$work/gpg; mkdir -m700 "$GNUPGHOME"
curl -sSf "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x$KEY" | gpg -q --import
base=https://github.com/microg/GmsCore/releases/download/$VER
code=${VER##*.}
gms=com.google.android.gms-${code}034.apk
assets=$(curl -sSf "https://api.github.com/repos/microg/GmsCore/releases/tags/$VER")
store=$(echo "$assets" | grep -oE 'com\.android\.vending-[0-9]+\.apk"' | head -1 | tr -d '"')
for f in "$gms" "$store"; do
    curl -sSLf -o "$work/$f" "$base/$f"
    curl -sSLf -o "$work/$f.asc" "$base/$f.asc"
    gpg --status-fd 1 --verify "$work/$f.asc" "$work/$f" 2>/dev/null | grep -q "VALIDSIG $KEY" \
        || { echo "bad GPG signature: $f"; exit 1; }
    "$APKSIGNER" verify --print-certs "$work/$f" | grep -qi "SHA-1 digest: $CERT_SHA1" \
        || { echo "unexpected signing certificate: $f"; exit 1; }
done
mkdir -p "$DEST/etc"
cp "$(dirname "$0")/microg/Android.bp" "$(dirname "$0")/microg/microg.mk" "$DEST/"
cp "$(dirname "$0")"/microg/etc/*.xml "$DEST/etc/"
cp "$work/$gms" "$DEST/GmsCore.apk"
cp "$work/$store" "$DEST/MicrogCompanion.apk"
# Services Framework Proxy: its own repo, one old release, no GPG signature; the signing
# certificate check is what vouches for it.
curl -sSLf -o "$work/GsfProxy.apk" https://github.com/microg/GsfProxy/releases/download/v0.1.0/GsfProxy.apk
"$APKSIGNER" verify --print-certs "$work/GsfProxy.apk" | grep -qi "SHA-1 digest: $CERT_SHA1" \
    || { echo "unexpected signing certificate: GsfProxy.apk"; exit 1; }
cp "$work/GsfProxy.apk" "$DEST/GsfProxy.apk"
echo "microG $VER verified and copied to $DEST"
