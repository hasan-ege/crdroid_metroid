#!/bin/sh
# One-time host setup for building crDroid on this CachyOS machine. Needs sudo.
#
#   sudo sh tools/setup-host.sh
#
# 1. Build packages that are missing (git-lfs, ccache, zip, bc; erofs-utils and cpio for
#    unpacking stock images).
# 2. A 32 GB swap file for the 14 GB RAM machine, in its own btrfs subvolume (/swap) so
#    snapper snapshots of / never include it. Priority 10 keeps the existing zram
#    (priority 100) in use first.
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo" >&2; exit 1; }

pacman -S --needed --noconfirm git-lfs ccache zip bc erofs-utils cpio

if ! swapon --show=NAME --noheadings | grep -qx /swap/swapfile; then
    [ -d /swap ] || btrfs subvolume create /swap
    [ -f /swap/swapfile ] || btrfs filesystem mkswapfile --size 32g --uuid clear /swap/swapfile
    swapon --priority 10 /swap/swapfile
    grep -q '^/swap/swapfile' /etc/fstab || echo '/swap/swapfile none swap defaults,pri=10 0 0' >> /etc/fstab
fi

swapon --show
echo "ok"
