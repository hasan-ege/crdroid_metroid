#!/usr/bin/env bash
# fuad00's recovery-installer/flash-lineage-recovery.sh for our build: flashes the boot/AVB chain
# that matches the ROM zip to BOTH slots, activates slot a, clears misc and boots recovery.
# Sideloading the zip from that recovery then installs to slot b (recovery on the empty slot a
# lets update_engine reuse b's space in super; see DURUM.md).
#
#   tools/bootstrap.sh <build dir>          dry run
#   tools/bootstrap.sh <build dir> --yes    flash
#
# Never touches firmware/critical partitions, super, userdata or metadata.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
dir=${1:?build dir}
yes=${2:-}
fastboot="${FASTBOOT:-$here/platform-tools/fastboot}"
images=(boot init_boot vendor_boot dtbo pvmfw recovery vbmeta_system vbmeta_vendor vbmeta)

(cd "$dir" && sha256sum --quiet -c BOOTSTRAP.sha256) || { echo "!! bootstrap images changed" >&2; exit 1; }
[[ $("$fastboot" devices | wc -l) == 1 ]] || { echo "!! need exactly one fastboot device" >&2; exit 1; }
product=$("$fastboot" getvar product 2>&1 | sed -n 's/^product: //p')
unlocked=$("$fastboot" getvar unlocked 2>&1 | sed -n 's/^unlocked: //p')
serial=$("$fastboot" devices | awk '{print $1}')
echo "device: serial=$serial product=$product unlocked=$unlocked"
[[ ($product == sun || $product == Metroid) && $unlocked == yes ]] || { echo "!! not an unlocked metroid" >&2; exit 1; }
[[ -z ${SERIAL:-} || $serial == "$SERIAL" ]] || { echo "!! serial $serial is not $SERIAL" >&2; exit 1; }

run() { if [[ $yes == --yes ]]; then "$fastboot" "$@"; else echo "would run: fastboot $*"; fi; }

run set_active a
run erase misc
for slot in a b; do
    for image in "${images[@]}"; do
        run flash "${image}_${slot}" "$dir/$image.img"
    done
done
run set_active a
run erase misc
run reboot recovery
[[ $yes == --yes ]] || echo "(dry run; add --yes to flash)"
