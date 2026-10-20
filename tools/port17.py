#!/usr/bin/env python3
"""Ports the metroid changes onto the crDroid 17.0 (Android 17) tree, leaving the 16 tree alone.

1. fuad00's metroid commits (on top of LineageOS lineage-23.2) are fetched from his forks and
   cherry-picked onto the matching LineageOS lineage-24.0 / crDroid 17.0 projects.
2. Our own patches (patches/crdroid/<repo>/*.patch) are applied with `git am -3`.

Anything that does not apply cleanly is aborted and listed at the end, to be ported by hand.
Run again after fixing: projects already carrying a commit (same subject) are skipped.

    tools/port17.py [--tree /home/hasan/android/crdroid17] [--only <path>]
"""
import argparse
import glob
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATCHES = os.path.join(HERE, "..", "patches", "crdroid")

# (path in the tree, fuad00 repo, fuad00 branch, metroid commits on top of LineageOS)
FUAD00 = [
    ("build/make", "android_build", "lineage-23.2", 1),
    ("build/soong", "android_build_soong", "lineage-23.2", 1),
    ("frameworks/av", "android_frameworks_av", "lineage-23.2", 1),
    ("frameworks/base", "android_frameworks_base", "lineage-23.2", 5),
    ("hardware/interfaces", "android_hardware_interfaces", "lineage-23.2", 3),
    ("packages/apps/Settings", "android_packages_apps_Settings", "lineage-23.2", 3),
    ("packages/modules/Bluetooth", "android_packages_modules_Bluetooth", "lineage-23.2", 1),
    ("packages/modules/Connectivity", "android_packages_modules_Connectivity", "lineage-23.2", 3),
    ("system/sepolicy", "android_system_sepolicy", "lineage-23.2", 1),
    ("vendor/lineage", "android_vendor_lineage", "lineage-23.2", 1),
    ("bootable/recovery", "android_bootable_recovery", "lineage-23.2-metroid", 2),
    ("hardware/qcom-caf/sm8750/audio/agm", "android_vendor_qcom_opensource_agm", "lineage-23.2-caf-sm8750", 1),
    ("hardware/qcom-caf/sm8750/audio/pal", "android_vendor_qcom_opensource_arpal-lx", "lineage-23.2-caf-sm8750", 1),
    ("hardware/qcom-caf/sm8750/audio/primary-hal", "android_hardware_qcom_audio-ar", "lineage-23.2-caf-sm8750", 1),
    ("hardware/qcom-caf/sm8750/data-ipa-cfg-mgr", "android_vendor_qcom_opensource_data-ipa-cfg-mgr", "lineage-23.2-caf-sm8750", 1),
    ("hardware/qcom-caf/sm8750/dataipa", "android_vendor_qcom_opensource_dataipa", "lineage-23.2-caf-sm8750", 1),
    ("hardware/qcom-caf/sm8750/display/hal", "android_hardware_qcom_display", "lineage-23.2-caf-sm8750", 1),
    ("packages/apps/Aperture", "android_packages_apps_Aperture", "lineage-23.2", 5),
    ("packages/apps/AudioFX", "android_packages_apps_AudioFX", "lineage-23.2", 1),
    ("packages/modules/common", "android_packages_modules_common", "lineage-23.2", 1),
    ("packages/modules/adb", "android_packages_modules_adb", "lineage-23.2", 2),
    ("packages/providers/TelephonyProvider", "android_packages_providers_TelephonyProvider", "lineage-23.2", 1),
    ("vendor/qcom/opensource/vibrator", "android_vendor_qcom_opensource_vibrator", "lineage-23.2", 1),
]

# patches/crdroid/<dir> -> path (the device tree is carried over as a whole, not as patches)
OURS = {
    "frameworks_base": "frameworks/base",
    "packages_apps_Settings": "packages/apps/Settings",
    "vendor_lineage": "vendor/lineage",
    "packages_services_Telecomm": "packages/services/Telecomm",
    "packages_apps_Aperture": "packages/apps/Aperture",
    "packages_apps_SetupWizard": "packages/apps/SetupWizard",
}

GIT = ["git", "-c", "user.name=hasan", "-c", "user.email=gungorbzk@gmail.com"]


def git(path, *args, check=True):
    r = subprocess.run(GIT + ["-C", path, *args], capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"{' '.join(args)}: {r.stderr.strip()[:300]}")
    return r


def subjects(path, n=300):
    return set(git(path, "log", f"-{n}", "--format=%s", check=False).stdout.splitlines())


def port_fuad00(tree, path, repo, branch, count, failed):
    p = os.path.join(tree, path)
    if not os.path.isdir(p):
        failed.append(f"{path}: not in the tree")
        return
    url = f"https://github.com/fuad00/{repo}"
    git(p, "fetch", "-q", f"--depth={count + 1}", url, branch)
    log = git(p, "log", "--format=%H %s", f"FETCH_HEAD~{count}..FETCH_HEAD").stdout.splitlines()
    have = subjects(p)
    for line in reversed(log):
        sha, title = line.split(" ", 1)
        if title in have:
            print(f"  = {path}: {title}")
            continue
        r = git(p, "cherry-pick", "-x", sha, check=False)
        if r.returncode:
            git(p, "cherry-pick", "--abort", check=False)
            failed.append(f"{path}: fuad00 '{title}' ({sha[:10]})")
            print(f"  ! {path}: {title}")
        else:
            print(f"  + {path}: {title}")


def port_ours(tree, folder, path, failed):
    p = os.path.join(tree, path)
    have = subjects(p)
    for patch in sorted(glob.glob(os.path.join(PATCHES, folder, "*.patch"))):
        title = next((l[len("Subject: "):] for l in open(patch, encoding="utf-8", errors="replace")
                      if l.startswith("Subject: ")), "")
        title = title.split("] ", 1)[-1].strip()
        if title in have:
            print(f"  = {path}: {title}")
            continue
        r = git(p, "am", "-3", patch, check=False)
        if r.returncode:
            git(p, "am", "--abort", check=False)
            failed.append(f"{path}: ours {os.path.basename(patch)}")
            print(f"  ! {path}: {os.path.basename(patch)}")
        else:
            print(f"  + {path}: {title}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tree", default="/home/hasan/android/crdroid17")
    ap.add_argument("--only")
    a = ap.parse_args()
    failed = []
    print("fuad00 metroid commits:")
    for path, repo, branch, count in FUAD00:
        if a.only and path != a.only:
            continue
        try:
            port_fuad00(a.tree, path, repo, branch, count, failed)
        except RuntimeError as e:
            failed.append(f"{path}: {e}")
    print("our patches:")
    for folder, path in OURS.items():
        if a.only and path != a.only:
            continue
        port_ours(a.tree, folder, path, failed)
    print(f"\n{len(failed)} to port by hand:" if failed else "\nall applied")
    for f in failed:
        print("  - " + f)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
