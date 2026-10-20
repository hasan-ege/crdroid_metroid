#!/usr/bin/env python3
"""List the commits fuad00's metroid forks carry on top of LineageOS lineage-23.2, for the
repos crDroid also replaces with its own forks. Those commits are what must be cherry-picked
onto crDroid's 16.0 branches.

    metroid-patches.py            human-readable list
    metroid-patches.py --json     machine-readable, for apply-metroid-patches.sh
"""
import json
import sys
import urllib.request

# (repo name, fuad00 branch, path in the source tree)
REPOS = [
    ("android_build", "lineage-23.2", "build/make"),
    ("android_build_soong", "lineage-23.2", "build/soong"),
    ("android_frameworks_av", "lineage-23.2", "frameworks/av"),
    ("android_frameworks_base", "lineage-23.2", "frameworks/base"),
    ("android_hardware_interfaces", "lineage-23.2", "hardware/interfaces"),
    ("android_packages_apps_Settings", "lineage-23.2", "packages/apps/Settings"),
    ("android_packages_modules_Bluetooth", "lineage-23.2", "packages/modules/Bluetooth"),
    ("android_packages_modules_Connectivity", "lineage-23.2", "packages/modules/Connectivity"),
    ("android_system_sepolicy", "lineage-23.2", "system/sepolicy"),
    ("android_vendor_lineage", "lineage-23.2", "vendor/lineage"),
    ("android_bootable_recovery", "lineage-23.2-metroid", "bootable/recovery"),
]


def compare(name, branch):
    url = (f"https://api.github.com/repos/LineageOS/{name}/compare/"
           f"lineage-23.2...fuad00:{name}:{branch}?per_page=250")
    with urllib.request.urlopen(url) as r:
        return json.load(r)


def main():
    out = []
    for name, branch, path in REPOS:
        d = compare(name, branch)
        commits = [{"sha": c["sha"], "title": c["commit"]["message"].splitlines()[0]}
                   for c in d["commits"]]
        out.append({"repo": name, "branch": branch, "path": path,
                    "ahead": d["ahead_by"], "behind": d["behind_by"], "commits": commits})
    if "--json" in sys.argv:
        json.dump(out, sys.stdout, indent=1)
        return
    for r in out:
        print(f"== {r['path']}  (+{r['ahead']} / -{r['behind']} vs LineageOS)")
        for c in r["commits"]:
            print(f"   {c['sha'][:10]} {c['title'][:90]}")


if __name__ == "__main__":
    main()
