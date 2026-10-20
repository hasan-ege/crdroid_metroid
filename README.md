# crDroid for the Nothing Phone (3) — `metroid`

Unofficial crDroid builds for the Nothing Phone (3) (A024, Snapdragon 8s Gen 4 / SM8735 "pakala"),
with **OpenGlyph**, an open-source replacement for Nothing's closed Glyph Matrix service.

- crDroid **17.0** (Android 17, v13.x): current
- crDroid **16.0** (Android 16, v12.x): previous

Built from [fuad00's metroid device tree](https://github.com/fuad00/android_device_nothing_metroid)
and the work documented by logix727 (in `device/nothing/metroid/meta/docs`).

## What's different from plain crDroid

- **OpenGlyph** ([repo](https://github.com/hasan-ege/OpenGlyph)): Glyph Matrix toys (clock, battery,
  solar path, moon, compass, leveller, stopwatch, spin the bottle, rock paper scissors, Magic 8 ball,
  Glyph Mirror…), Glyph Button, Glyph Toys timeout, always-on Glyph toy, Flip to Glyph, Essential
  Notifications, generative notification sounds and ringtones, music visualiser, caller ID, Live
  Update progress, camera countdown, recording light, bedtime, pocket mode, auto brightness from the
  rear light sensor, and compatibility with apps and toys made with Nothing's Glyph Matrix SDK.
- **Essential Key** settings (what the side key does), Glyph Matrix entry in Settings.
- **microG** (signed upstream builds) offered in the setup wizard instead of Google apps.
- Pure black Material 3 theme, generative per-caller ringtones in Telecom, Aperture camera fixes for
  this phone's camera layout, screen-off fingerprint.
- No hourly crDroid donation reminder.

## Source layout

| Repo | Branches | What |
|---|---|---|
| [android_device_nothing_metroid](https://github.com/hasan-ege/android_device_nothing_metroid) | `17.0`, `16.0` | Device tree (fork of fuad00) |
| [OpenGlyph](https://github.com/hasan-ege/OpenGlyph) | `main` | Glyph Matrix service, `packages/apps/OpenGlyph` |
| [android_frameworks_base](https://github.com/hasan-ege/android_frameworks_base) | `metroid-17.0`, `metroid-16.0` | SystemUI / framework fixes |
| [android_packages_apps_Settings](https://github.com/hasan-ege/android_packages_apps_Settings) | `metroid-17.0`, `metroid-16.0` | Glyph Matrix and Essential Key entries, fixes |
| [android_packages_apps_SetupWizard](https://github.com/hasan-ege/android_packages_apps_SetupWizard) | `metroid-17.0`, `metroid-16.0` | microG step |
| [android_packages_services_Telecomm](https://github.com/hasan-ege/android_packages_services_Telecomm) | `metroid-17.0`, `metroid-16.0` | Generative ringtones |
| [android_vendor_crdroid](https://github.com/hasan-ege/android_vendor_crdroid) | `metroid-17.0`, `metroid-16.0` | `vendor/lineage` tweaks |
| [android_packages_apps_Aperture](https://github.com/hasan-ege/android_packages_apps_Aperture) | `metroid-17.0`, `metroid-16.0` | Camera routing, recording light |

This repo holds the glue: `local_manifests/`, the same changes as plain patches (`patches/`),
helper scripts (`tools/`) and the development log (`docs/DURUM.md`, Turkish).

## Building

```bash
mkdir crdroid17 && cd crdroid17
repo init -u https://github.com/crdroidandroid/android -b 17.0 --git-lfs
mkdir -p .repo/local_manifests
curl -o .repo/local_manifests/metroid.xml https://raw.githubusercontent.com/hasan-ege/crdroid_metroid/main/local_manifests/17.0.xml
repo sync -c -j8
```

Then provide what cannot be published:

- **Vendor blobs** (`vendor/nothing/metroid`): Nothing's proprietary files. Extract them from a stock
  Nothing OS image with `device/nothing/metroid/extract-files.py`.
- **Kernel**: the stock prebuilt kernel, staged with `tools/stage-stock-kernel.sh`.
- **Signing keys** (`vendor/lineage-priv/keys`): generate your own. Never use or share someone else's.

```bash
TOP=$PWD bash /path/to/crdroid_metroid/tools/build.sh bacon
```

`tools/build.sh` defaults to `DEBUG=1` (adb without authorization, bring-up only). Use `DEBUG=0`
for anything you give to other people.

## Builds

Release zips are about 4.3 GB, more than GitHub allows per file; they are hosted elsewhere (links in
[Releases](https://github.com/hasan-ege/crdroid_metroid/releases)). See [BUILDS.md](BUILDS.md).

## Known issues

See [docs/TEST-2026-10-20.md](docs/TEST-2026-10-20.md). In short: incoming SMS may not arrive on
Turkcell (the modem never delivers them; under investigation), 1080p60 video bands under fluorescent
light, ultra-wide is not available in 60 fps video, and the camera HAL can crash on the logical
camera.

**Flash at your own risk.** Unlocked bootloader required; back up your partitions first
(`tools/backup-partitions.sh`).
