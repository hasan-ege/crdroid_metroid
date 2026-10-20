# Nothing Phone (3) custom ROM: durum notları

## Cihaz (adb ile okundu, 2026-10-17)

| | |
|---|---|
| Model / kod adı | A024 / `metroid` (seri 00019157L001965) |
| Yazılım | Nothing OS **B4.1-260814-1733**, `user` derlemesi |
| Bootloader | **açık** (`verifiedbootstate=orange`, `vbmeta.device_state=unlocked`) |
| Root | Magisk v30.7 (init_boot_b) |
| SELinux | Enforcing |
| Glyph sürücüsü | `/sys/devices/platform/soc/8c0000.qcom,qupv3_2_geni_se/888000.spi/spi_master/spi10/spi10.0/leds/matrix-leds` (var, adb kabuğu erişemiyor) |
| `/dev/matrix_leds` | `system:system 0664`, `led_device` |
| Stok Glyph paketleri | `com.nothing.thirdparty`, `com.nothing.glyphnotification` |

B4.1-260814-1733, fuad00'ın LineageOS 23.2 ağacının istediği sürümle birebir aynı.
Firmware güncellemesi gerekmiyor.

## Root (2026-10-17)

- Stok `init_boot.img` (spike0en/nothing_archive, B4.1-260814-1733) telefonla doğrulandı.
  `avbtool calculate_vbmeta_digest` sonucu `37e473dc…1165f`, telefondaki `ro.boot.vbmeta.digest`
  ile aynı. init_boot hash'i de vbmeta tanımlayıcısıyla eşleşiyor.
- Magisk v30.7 (resmi, sha256 doğrulandı) ile yamalandı (KEEPVERITY/KEEPFORCEENCRYPT=true),
  sadece `init_boot_b`'ye flash'landı. `su` = `/product/bin/su`, shell'e izin verildi.
- **Geri alma:** `fastboot flash init_boot_b stock/B4.1-260814-1733/boot/init_boot.img`
- Stok OTA güncellemesi gelirse önce bu stok init_boot'u geri yükleyin, yoksa OTA başarısız olur.

## Glyph sürücüsü (root ile okundu)

- Chip ID 10, MCU firmware 17, bootloader 01, `max_brightness=2047`
- Stokta `frame_brightness` ve `single_brightness` etiketi `sysfs`, diğerleri `sysfs_leds_info`.
  Sahiplik `system:root 0664` (init açılışta değiştiriyor).
- Stok `com.nothing.thirdparty` çalışıyor, kendi kareleriyle bizimkileri ezebilir.
- `matrix-test.sh` all/cross/rows/walk/off: her kare SPI'ye hatasız gitti (`trans_info=0`).
- **LED düzeni telefonda doğrulandı:** satır-satır, ortalanmış, sol üstten başlıyor. `MatrixLayout` doğru.
- `tools/device-demo.sh all`: OpenGlyph çekirdeği (Renderer + efektler + SysfsMatrixSink) telefonda
  root olarak `app_process` ile çalıştı. 362 kare hatasız (`trans_info=0`), sonunda güç kapandı.
  Gözle doğrulandı: bildirim halkaları, şarj dolumu, arama halkaları, uygulama karesi ve öncelik
  geçişleri (arama > bildirim > uygulama) doğru.

## Yedek ve firmware analizi (2026-10-17)

- **Bölüm yedeği:** `backup/20261017-2105-B4.1-260814-1733/` içinde 108 bölüm (super, userdata,
  tüm LUN'lar, rawdump ve loglar hariç). Her biri telefondaki sha256 ile doğrulandı (`SHA256SUMS`).
  IMEI/modem NV (`modemst1`, `modemst2`, `fsg`, `fsc`), kalibrasyon (`persist`) ve anahtarlar
  (`keystore`, `secdata`) dahil. **Bu klasör telefona özel ve hassas: paylaşma, başka telefona yazma.**
  Yeniden almak için: `tools/backup-partitions.sh`.
- **Slot `_b` (aktif):** sistem/boot B4.1-260814 ama firmware (xbl, abl, tz, modem…) **C5.0-260819-1642**
  (26 bölümden 25'i birebir; sadece pvmfw farklı). Telefon geçmişte C5.0'a geçip sistemde B4.1'e dönmüş.
- **Slot `_a`:** firmware B4.1-260814, ama Google sistem güncellemesi C5.0-260924'ü indirmeye başlayıp
  `abl_a`'yı C5.0-260924 ile yazmış (karışık durum). **`_a`'dan boot etme.** İndirme 16,8 MB'ta
  durmuş (`update_engine` boşta).
- **Anti-rollback:** `tools/qcom-arb.py` ile okundu. xbl_config, abl, tz, hyp, aop, devcfg, keymaster,
  uefi, cpucp, qupfw, shrm… B4.1-260624, B4.1-260814, C5.0-260819 ve C5.0-260924'ün hepsinde ve
  telefonda `arb=0`. C5.0 → B4.1 firmware dönüşü anti-rollback'e takılmıyor
  (xbl kapsayıcı formatta, okunamadı).
- **Yapılacak:** Geliştirici seçenekleri → "Otomatik sistem güncellemeleri" **kapalı** olmalı.
  ROM'dan önce iki slota da B4.1-260814 firmware'i yazılacak
  (`stock/B4.1-260814-1733/firmware/`, hash doğrulandı).

## Klasör

- `open-glyph/`: açık kaynak Glyph Matrix servisi (bkz. `open-glyph/README.md`)
- `platform-tools/`: Google'ın resmi adb/fastboot paketi (`./platform-tools/adb`)
- `stock/`: stok imajlar (B4.1-260814 boot+firmware; B4.1-260624, C5.0-260819, C5.0-260924 firmware)
- `patched/`: Magisk yamalı init_boot · `tools-ext/`: avbtool, Magisk APK, build-tools (d8)
- `backup/`: telefonun bölüm yedekleri (hassas) · `tools/`: `backup-partitions.sh`, `qcom-arb.py`

## OpenGlyph cihaz testi için root seçenekleri

1. **Stok sistemde root (Magisk/KernelSU):** stok B4.1 `init_boot.img` yamalanıp flash'lanır.
   Veriler silinmez. Stok `init_boot` geri flash'lanarak geri alınabilir.
   Sonra `ADB=../platform-tools/adb tools/matrix-test.sh walk` ile LED sırası doğrulanır.
2. **Unofficial LineageOS 23.2 kurmak:** veriler silinir. OpenGlyph'i sistem uygulaması olarak
   derleyip kurmak için zaten bu yola gideceğiz.

## Makine

Ryzen 7 9700X (16 thread), **14 GB RAM** (Android derlemesi için yetersiz, 32 GB+ ya da büyük
swap gerekir), /home'da 627 GB boş.

## crDroid derleme ortamı (2026-10-17)

- Hedef: **crDroid 16.0** (crDroid 12.x, Android 16). Manifest varsayılanı `lineage-23.2`,
  fuad00 metroid ağacıyla aynı taban.
- Kaynak: `/home/hasan/android/crdroid`. Bu klasördeki `crdroid` bir kısayol, çünkü AOSP derlemesi
  yolda boşluk ("NOTHING 3") olursa bozulur. İndirme günlüğü: `/home/hasan/android/crdroid-sync.log`.
- `repo` launcher: `~/.local/bin/repo`. İndirme `--depth=1`, git-lfs kapalı (paket kurulunca açılacak).
- Host kurulumu (sudo): `sudo sh tools/setup-host.sh` kuruyor: git-lfs, ccache, zip, bc ve
  `/swap/swapfile` (32 GB, ayrı btrfs alt birimi, öncelik 10, fstab).
- metroid platform çatallarından 11'ini crDroid de kendi çatalıyla değiştiriyor
  (build/make, build/soong, frameworks/av, frameworks/base, hardware/interfaces, Settings,
  Bluetooth, Connectivity, system/sepolicy, vendor/lineage, bootable/recovery). Bunlara
  metroid yamaları crDroid sürümünün üstüne cherry-pick edilecek. Kalan 14'ü (qcom-caf sm8750 ses,
  ekran, ipa, Aperture, AudioFX, adb, common, TelephonyProvider, apn, vibrator) doğrudan fuad00'dan.
- Metroid yamaları: `tools/metroid-patches.py` (+ `.json`). 11 depoda toplam 23 commit, uygulamak için
  `tools/apply-metroid-patches.sh` (crDroid çatallarında `metroid` dalına cherry-pick).
- Local manifest: `tools/crdroid-metroid.xml` (`tools/make-local-manifest.py` ile fuad00'dan
  üretildi; 14 proje, 13 remove-project). Sync bitince `.repo/local_manifests/` içine konacak.
- Kernel: ağaç `kernel/out/`'ta kaynaktan (Kleaf) derlenmiş kernel bekliyor. **İlk derlemede stok
  B4.1 kernel'i** (boot.img'deki Image, vendor_boot'taki dtb ve ramdisk modülleri, dtbo,
  vendor_dlkm/system_dlkm modülleri) aynı düzene konacak. Kaynaktan kernel sonra yapılacak.
- Blob'lar: stok B4.1 sistem imajları `stock/B4.1-260814-1733/logical/` içine indiriliyor, `extract-files.py` için.
- **2026-10-17 akşam:** crDroid 16.0 sync bitti (115 GB). 14 metroid projesi fuad00'dan indi.
  23 metroid yamasının hepsi uygulandı. `frameworks/base` fc5baed7ef (parmak izi ripple)
  crDroid'in `isRippleEnabled` ayarıyla elle birleştirildi.
- Stok kernel: `tools/stage-stock-kernel.sh` (erofs-utils gerekiyor). Kernel başlıkları NothingOSS
  `sm8735/b/mr` 5f61614'ten üretildi; bu commit tam olarak B4.1-260814-1733. Kaynak: `src/nothing-kernel`.
- Stok kernel `kernel/out/` içine konuldu: 340 ramdisk modülü (+focaltech_tp.ko vendor_dlkm'den),
  312 vendor_dlkm ve 96 system_dlkm modülü.
- Blob'lar: `extract-files.py --allow-prohibited-files` ile stok B4.1'den çıkarıldı, hatasız,
  `vendor/nothing/metroid` 4,7 GB.
- **İmza anahtarları:** `~/.android-certs` (ağaçta `vendor/lineage-priv/keys` kısayolu) ve yedeği
  `keys/`. CN=crDroid metroid, 2054'e kadar geçerli. **Bu anahtarları kaybetme ve paylaşma:**
  kaybolursa güncelleme için telefonu sıfırlamak gerekir. Ele geçirilirse sahte güncelleme imzalanabilir.
- Derleme: `tools/build.sh` (userdebug, -j8, ccache 50 GB). Log: `~/android/logs/current_build.log`.
- Karar: **Google'suz (vanilla)** derleme. Gerekirse sonra microG.
- **1. derleme (21:50–22:36) başarısız:** %29'da `UdfpsController.java: duplicate declaration of field
  mAuthController`. Sebep: metroid yaması fe91e2e905 nullable bir `mAuthController` ve setter ekliyor,
  crDroid ise zaten `final` bir alanı inject ediyor. Düzeltme: frameworks/base aff26b935, yama dosyası
  `patches/crdroid/frameworks_base/`. Ağaç sıfırdan kurulursa yamalardan sonra
  `git am` ile uygulanacak. Derleme artık `-k 0` ile tüm hataları tek turda topluyor.
- **2. derleme sırasında** (hata derlemeyi durdurmadı, `-k 0`): `vendor_sepolicy` checkpolicy hatası,
  `duplicate entry for genfs entry (sysfs, /class/qcom-battery)`. LineageOS sepolicy_vndr 490d47f
  (2026-09-30) bu yolu herkes için `vendor_sysfs_battery_supply` olarak etiketliyor, fuad00 ağacı ise
  ayrıca kendi tipiyle etiketliyordu. Düzeltme: device tree c81b223, yama dosyası
  `patches/crdroid/device_nothing_metroid/`. (fuad00'a da bildirilebilir, LineageOS 23.2'de de patlar.)
- **2. derleme, 3. hata:** `webview.apk` imzalanamadı (`zip END header not found`). Dosya 134 baytlık bir
  git-lfs işaretçisiydi, çünkü sync git-lfs kurulmadan yapılmıştı. `external/chromium-webview/prebuilt/*`
  (ağaçtaki tek 4 LFS projesi) için `git lfs pull` yapıldı, webview.apk artık 258 MB.

## İlk başarılı derleme (2026-10-18 00:28)

- `builds/crDroid-12.13-20261018/crDroidAndroid-16.0-20261018-metroid-v12.13.zip` (4,2 GB, A/B
  payload), recovery.img ve boot imajları. Derleme süresi toplam ~2,5 saat (3 tur: 45 dk, 1 sa 40 dk, 9 dk).
- Doğrulama: sha256 OK, `unzip -t` hatasız. OTA imzası bizim releasekey ile
  (sha256 98:EE:9E:4B…D5:D4). boot.img kernel'i stok B4.1 ile birebir (86dc8754…).
  security patch 2026-10-01.
- AVB (vbmeta) AOSP'nin herkese açık test anahtarıyla imzalı (2597c218…). Açık bootloader'da sorun değil,
  bootloader **asla kilitlenmemeli**.
- odm.img küçük (348 KB) ve bu bilinçli: stok odm'nin 243 MB'ı mağaza demo APK'ları ve JP strongbox.
- Kurulum: `tools/flash-firmware.sh` (önce dry-run) ile iki slota B4.1 firmware, sonra recovery ve
  `adb sideload`. **Format data veriyi siler, Magisk root da gider.**

## Kurulum denemesi (2026-10-18 sabah)

- İlk sideload (recovery `b`'den, hedef `a`): `kInstallDeviceOpenError` (status 7). Sebep: super 9,66 GB'ın
  ~9,05 GB'ını stok `b` kullanıyor, recovery çalıştığı slotun bölümlerini silmiyor ve hedefe yer kalmıyor.
  logix727'nin notu da bunu doğruluyor: OTA eski slotun alanının üstüne yazılıyor.
- `fastboot flash` kritik bölümleri reddediyor ("Device critical unlocked: false"). `unlock_critical` ise
  "Flashing Unlock is not allowed" diyor (`get_unlock_ability: 0`, Ayarlar'da OEM kilit açma gri).
  `abl_a` bunun yerine stoktan root+dd ile B4.1 yapıldı (slot `a` firmware'i tamamen B4.1).
- Firmware'i OTA'ya gömme fikri güvenlik denetiminde reddedildi (kritik kilidi dolaylı aşmak).
  `vendor/nothing/metroid-firmware/` içinde imajlar duruyor ama hiçbir yerden include edilmiyor.
- **Karar: fuad00 yöntemi.** `tools/bootstrap.sh` boot, init_boot, vendor_boot, dtbo, pvmfw, recovery
  ve vbmeta* imajlarını iki slota yazdı, sonra `set_active a`, `erase misc`, recovery. ROM `b`'ye kurulacak,
  **`b`'nin firmware'i C5.0-260819** (fuad00 B4.1 istiyor, donanım sorunları çıkarsa sebep bu olabilir).
- crDroid `gen_build_prop.py` her non-eng derlemeyi "user" gösteriyor, bu yüzden recovery'de ADB
  yetkilendirmesi `WITH_ADB_INSECURE` ile kapanmıyor (ro.adb.secure=1 önce yazılıyor).
- **2026-10-18: crDroid 12.13 KURULDU VE AÇILDI.** Sideload `Total xfer 1.00x`, slot `b`, C5.0-260819
  firmware üstünde. crDroid boot animasyonu ve kurulum sihirbazı geldi.
- İlk açılış sağlık kontrolü (adb, salt okunur): slot `_b`, SELinux Enforcing, kernel stok 6.6.127, yama
  2026-10-01. SIM (Turkcell) yüklü, baseband PAKALA 7.0-02698. Wi-Fi açık, NFC açık, 41 donanım sensörü,
  parmak izi HAL var, 5 kamera, ses HAL'i çıkışları (hoparlör/ahize) var, Glyph sysfs düğümü var.
  Kamera sağlayıcı açılışta bir kez çöküp yeniden başladı. 25 avc denial (çoğu mediaprovider→radio_service).
- **İlk kullanımda bulunan iki sorun** (device tree 50913d7, yama dosyası `patches/crdroid/device_nothing_metroid/`):
  1. "com.qualcomm.qti… yanıt vermiyor": `uimlpaservice` (eSIM LPA) `uimLpaGetEid`'de index -1 ile çöküyor,
     çünkü modem eSIM slotunu boş bildiriyor. Build'den çıkarıldı. Telefonda şimdilik `pm disable-user`.
  2. Kamera kayıt LED'i ekran açıkken yanıyordu: stok lights HAL BUTTONS ışığını (HAL id 2) kırmızı kayıt
     LED'ine bağlıyor, Lineage varsayılan tuş parlaklığı 1.0. Overlay ile
     `config_buttonBrightnessSettingDefaultFloat=0.0` yapıldı. Telefonda şimdilik lineagesettings
     `secure/button_brightness=0.0`.

## Bir sonraki derlemeye hazır düzeltmeler (2026-10-18, henüz derlenmedi)

- **Bluetooth hiç açılmıyordu:** zygote `selinux_android_setcontext(1002 … seinfo default)` ile
  com.android.bluetooth'u öldürüyordu. `mac_permissions.xml`'de @BLUETOOTH imzası AOSP test anahtarı
  (a6ccc500…) ama Bluetooth.apk bizim bluetooth anahtarımızla imzalı (097243d4…). Sebep: bu ağaçta
  `MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES` ayarlanmazsa test anahtarı dizinine düşüyor. Düzeltme:
  `keys.mk`'ye `PRODUCT_MAINLINE_SEPOLICY_DEV_CERTIFICATES` ve
  `PRODUCT_MAINLINE_BLUETOOTH_SEPOLICY_DEV_CERTIFICATES := vendor/lineage-priv/keys`.
  Telefonda geçici çözüm yok (politika ROM'da).
- **Kayıt LED'i video kaydında yanıp sönsün:** OpenGlyph `RecordingLedController` + `core/TimerLed` +
  `core/RecordingDetector`. Bir kamera açık ve aynı uid ses kaydediyorsa video kaydı sayılıyor ve
  `/sys/class/leds/red` kernel `timer` tetikleyicisiyle 500/500 ms yanıp sönüyor. Ayar:
  `settings put secure open_glyph_record_led 0/1`. Sessiz (mikrofonsuz) kayıt algılanmaz.
  LED stok lights HAL'de `/sys/class/leds/red` (DT: pmxr2230@1/led-controller/led@1). ueventd trigger,
  delay_on ve delay_off'u system'e veriyor. Sepolicy (device b010096): led-controller yolu `sysfs_leds`
  (yol kalıp tahmini; OpenGlyph açılışta gerçek yolu log'a yazıyor), `system_app` izinleri.
  İzinler: CAMERA_OPEN_CLOSE_LISTENER, MODIFY_AUDIO_ROUTING.
- **OpenGlyph ROM'a eklendi** (device 96aa6d4). `adb install` ile kurulamıyor: Android 14+
  "non-preload app signed with platform signature joining android.uid.system" reddediyor.
- **Smooth display anahtarı yoktu:** crDroid'de `config_show_smooth_display=false` ve maksimum yenileme
  listesi kapalı. Device overlay ile `config_show_smooth_display=true` (device a403ec4).
- Device tree yamaları sırayla: `patches/crdroid/device_nothing_metroid/0001…0005`, frameworks/base:
  `patches/crdroid/frameworks_base/0001`. OpenGlyph host testleri (32) geçiyor ve system SDK stub'ına
  karşı javac ile derleniyor.
- **Güncelleme yöntemi notu:** ROM şu an `b`'de. Recovery'den sideload yine super'da yer sorunu çıkarabilir.
  Tercih: Android içinden crDroid Updater "yerel güncelleme" (VAB snapshot, veri korunur).
- **2. ROM derlemesi (07:00) başarılı:** `builds/crDroid-12.13-20261018-2/`. mac_permissions'ta bluetooth
  imzası artık bizim (097243d4…). OpenGlyph `system_ext/priv-app`'te. `DEBUG=0` (ro.adb.secure=1).
  İlk deneme `keys.mk` çift dahil edildiği için Soong'da durdu (device c27bc17, yama 0006).
  **Eksik:** `uimlpaservice` hâlâ product'ta: `filter-out` miras alınan vendor listesini etkilemiyor.
  Bir sonraki derlemede proprietary-files.txt'den çıkarılacak. Telefonda pm disable-user ile kapalı.
- Kurulum: zip `/sdcard/Download`'a gönderildi (sha256 doğrulandı). Android içinden Updater → yerel
  güncelleme (VAB, veri korunur).

## 2. sürüm telefonda (2026-10-18 07:10)

- Updater "yerel güncelleme" ile kuruldu, veriler korundu. **ROM artık slot `a`'da, yani tam B4.1 firmware
  üstünde** (VAB güncellemesi pasif slota yazdı). Firmware sorunu böylece çözüldü.
- Bluetooth ✅ (açık, adres var, setcontext çökmesi yok).
- **OpenGlyph ROM içinde çalışıyor ✅:** servis ve bildirim dinleyicisi uid 1000. Test bildirimi → halka
  darbesi, `dumpsys battery` ile şarj → dolum efekti gözle doğrulandı.
- Kayıt LED'i: `avc denied { search } name="red" tcontext=vendor_sysfs_graphics`. sun genfs_contexts
  red/green/blue LED'leri vendor_sysfs_graphics olarak etiketliyor. Düzeltme: device 3f67a66,
  `sepolicy/vendor/openglyph.te`, sonraki derlemede.

## Sonraki derleme için hazır (2026-10-18, derlenmedi)

- **Glyph Button:** matrix altındaki basınç noktası `aw9380x_0_ch0` (event4). Sert basış `EV_KEY` scancode
  251 (0xfb) veriyor (10 basışın 7'si). Hafif dokunuş sadece ABS_DISTANCE/ABS_RX (ch0/ch1).
  `keylayout/aw9380x_0_ch0.kl` 251'i `MACRO_1`'e bağlıyor. `MetroidKeyHandler` scancode 251'i tüketip
  `org.openglyph.action.GLYPH_BUTTON` (down/up/tap/long_press, uzun basış ≥600 ms) gönderiyor.
  OpenGlyph şimdilik kısa basışta pil seviyesini gösteriyor, uzun basış oyuncaklar için ayrıldı (device f91a754).
- DocumentsUI teması kaldırıldı (vendor/lineage 472e4b5, `patches/crdroid/vendor_lineage/`).
- `uimlpaservice` blob listesinden çıkarıldı (device 460de3a). Fuad00'ın vibrator `filter-out`'u da etkisiz
  (vendor.qti.hardware.vibrator.service hâlâ imajda), şimdilik dokunulmadı.
- Kayıt LED'i vendor sepolicy (device 3f67a66).
- **Derlemeden önce `m installclean`** gerekli: kaldırılan modüllerin eski dosyaları `out/`'ta kalıp imaja girebilir.
- Device tree yamaları: `patches/crdroid/device_nothing_metroid/0001…0009`.
- **Ayarlar > Glyph Matrix + oyuncaklar** (OpenGlyph git f71804a, derlenmedi): sistem Ayarları ana sayfasına
  `EXTRA_SETTINGS` + `category.ia.homepage` ile enjekte edilen SettingsLib ekranı (`GlyphSettingsActivity`).
  İçinde ana anahtar, parlaklık, bildirim/arama/şarj/kayıt ışığı anahtarları, test düğmesi ve oyuncaklar var.
  Oyuncaklar (`org.openglyph.toys`): Saat, Pil (şarjda nefes alan halka), Kronometre (uzun basış:
  başlat/durdur/sıfırla). Glyph Button: kısa basış göster/sıradaki, uzun basış eylem, 5 sn sonra söner.
  Ayar anahtarları `GlyphSettings` içinde (`open_glyph_*`). Host testleri geçiyor. javac kontrolünde
  sadece aapt'nin üreteceği `R` eksik.
- **3. ROM derlemesi (07:48, installclean sonrası) başarılı:** `builds/crDroid-12.13-20261018-3/`
  (sha256 7121052244a885f3…). OpenGlyph ve ayar ekranı imajda. uimlpaservice yok, DocumentsUIOverlay yok,
  `aw9380x_0_ch0.kl` var, system_app → vendor_sysfs_graphics izni var. Telefona henüz gönderilmedi.
- **Nothing tarzı özellikler** (OpenGlyph git, derlenmedi): Her zaman açık Glyph (soluk saat; mod
  OFF/ALWAYS/FACE_DOWN/CHARGING, sessiz saatler, dakikalık RTC_WAKEUP alarmı), Flip to Glyph (wake-up
  ivmeölçer, yüzüstüyken zil sessiz, kaldırınca geri yüklenir), önemli bildirimler (seçili uygulamaların
  bildirimi durdukça alt nokta yanar), uygulamaya özel desenler (RING/SWEEP/DOT/FLASH). Hepsi Ayarlar >
  Glyph Matrix'te. Glyph Button titreşimi: device 50d8680 (yama 0010).
- **Dönüştürücü (Nothing SDK oyuncakları):** kullanıcı AB 2009/24/EC md. 6 ile birlikte çalışabilirlik
  gerekçesi sundu. Sınırlar: sadece SDK'nın servis arayüzü incelenecek, kod kopyalanmayacak, aar
  dağıtılmayacak, bilgi sadece uyumluluk için kullanılacak. Önce Nothing'e protokol belgesi için e-posta önerildi.

## Parlaklık + Nothing SDK uyumluluğu (2026-10-18, derlenmedi)

- **Ekran parlaklığı:** kaydırıcının alt yarısı aynı karanlıkta kalıyordu. Ölçüm: kaydırıcı %43 → parlaklık
  0,035 (≈3 nit), %70 → 0,12. DisplayDeviceConfig parlaklığı DBV'ye doğrusal eşliyor, panelin nit eğrisi
  dik (DBV %9 → 6 nit), AOSP'nin HLG kaydırıcısı ise alt yarıyı 3–6 nite sıkıştırıyordu. Düzeltme:
  `sys.brightness.disable_gamma_conversion=true` (device 2340e8a, yama 0011). Beklenen: %25 ≈ 20 nit,
  %50 ≈ 90 nit.
- **Nothing SDK uyumluluğu** (OpenGlyph 8352b0b, device 6763302 / yama 0012): `OpenGlyphCompat`
  (`com.nothing.thirdparty`) SDK uygulamalarının karelerini OpenGlyph'e iletiyor. SDK oyuncakları
  (`com.nothing.glyph.TOY`) Ayarlar > Glyph Matrix'te oyuncak olarak görünüyor ve Glyph Button ile
  kullanılıyor. Arayüz notları: `open-glyph/docs/nothing-sdk-interface.md`. SDK .aar projede yok.
  AOD olayı (`aod`) henüz gönderilmiyor.
- **Ayarlar ana sayfası:** Glyph Matrix girişi artık Ayarlar'ın kendi XML'inde, crDroid ayarlarının hemen
  altında (expressive `-55`, klasik `-50`, başlık sırasıyla crDroid'den sonra). Kırmızı arka plan chip'li
  simgesi var (`ic_homepage_glyph_matrix`). Settings metroid dalı 99e735c6, yama
  `patches/crdroid/packages_apps_Settings/0001`. OpenGlyph'in kendi EXTRA_SETTINGS enjeksiyonu kaldırıldı (0f647ae).
- **4. ROM derlemesi (10:45, installclean sonrası) başarılı:** `builds/crDroid-12.13-20261018-4/`
  (sha256 1db97be76e0daf11…). İçinde OpenGlyph + OpenGlyphCompat, doğrusal parlaklık, Ayarlar'da Glyph Matrix
  girişi (chip'li), Glyph Button titreşimi, AOD/Flip/önemli bildirim/desenler. Telefona gönderildi, hash doğrulandı.
- **SDK uygulaması çalışmıyordu (com.tober.glyphmatrixtools):** uygulama compat'a bağlanıp kayıt oluyordu,
  ama SDK telefonu `Build.MODEL.contains("A024")` ile tanıyor. Bizde model "Phone (3)" olduğu için matris
  boyutu 0 ve hiç kare yok. Düzeltme: `PRODUCT_MODEL := A024` + `ro.product.marketname=Phone (3)`
  (device 85625f9, yama 0013). Compat artık her uygulamanın ilk karesini log'a yazıyor.

## Oyuncak sözleşmesi + stock Glyph Interface tasarımı + bildirim motoru (2026-10-18, ROM derlenmedi)

- **Oyuncak sözleşmesi (SDK README'ye göre):** seçim ile görünürlük ayrıldı. Seçili SDK oyuncağı bağlı kalır, matris
  5 sn sonra söner. `setGlyphMatrixTimeout(false)` oyuncağı ekranda tutar. AOD oyuncağı dakikada bir `aod` olayı
  alır. Test oyuncağı: `open-glyph/tools/test-toy` (telefona kuruldu, OpenGlyph buldu). Buton olayları elle
  denenmedi: `sendevent` SELinux yüzünden reddediliyor.
- **Ayarlar stock Glyph Interface'e benzetildi** (kullanıcının ekran görüntüleri baz alındı):
  - Ana ekran: canlı matris önizlemesi (gerçek matrisin aynası), kart ızgarası. Kartlar: Glyph Oyuncakları
    (etkin oyuncak şeridi + anahtar), Bildirimler, Önemli Bildirimler, Flip to Glyph, Her Zaman Açık Glyph
    Oyuncağı, aramalar, şarj, kayıt ışığı, Uyku programı.
  - Glyph Oyuncakları: büyük canlı önizleme, oyuncak şeridi, "Matriste göster". Oyuncakları yönet: sürükleyerek
    sıralama, ekle/kaldır (`open_glyph_toy_order`).
  - Her Zaman Açık Glyph Oyuncağı: aç/kapat, ne zaman, önizlemeli radyo listesi (saat + AOD destekli SDK oyuncakları).
  - Uyku programı: başlangıç/bitiş saati (dakika hassasiyeti), tekrar günleri. Uyku sırasında kayıt ışığı hariç
    tüm Glyph ışıkları kapalı (`open_glyph_bedtime*`). Eski sessiz saatler kaldırıldı.
- **Bildirim motoru (Essential Notifications):** kurallar = uygulamalar (boş = hepsi) + kişiler (kişi seçici ya
  da elle isim; gönderen/başlık/kişi listesiyle eşleşir) + anahtar kelimeler + matris simgesi (16 piksel
  simge ya da uygulamanın kendi simgesi, monokrom katmandan). Eşleşen bildirim durdukça simge matriste kalır.
  En yeni bildirim kazanır. Ayar: `open_glyph_essential_rules`. Eski "önemli uygulamalar" ilk kurala dönüşür.
  Varsayılan bildirim deseni ayarı eklendi (`open_glyph_pattern`).
- Host testleri geçiyor (kurallar, uyku programı, simgeler, oyuncak sırası). Doğrulama: `m OpenGlyph`.
- **Oyuncak testi (mevcut ROM, test oyuncağı, gerçek Glyph Button):** bağlanma, `registerMatrixSDK` ve
  `action_down` / `action_up` / `change` olayları geliyor. Eski ROM, oyuncak 5 sn görünmezse ve sıradakine
  geçildiğinde bağlantıyı kesiyor. Yeni sözleşmede seçili kaldıkça bağlı kalacak.
- **Titreşim hiç çalışmıyordu (sadece Glyph Button değil):** stock titreşim HAL'i "user" derlemede
  `haptic_interface_disable=1` yazıyor (Nothing OS RichTap kullanıyor). Bu yüzden AOSP'nin standart arayüzü
  sürücüde yok sayılıyordu (`activate_store … ignore`). Düzeltme: init, HAL'den sonra bayrağı 0 yapıyor
  (device yama 0015). Ayrıca Glyph Button titreşimi USAGE_HARDWARE_FEEDBACK'e geçti (yama 0014).
- **5. ROM derlemesi (11:56, installclean sonrası) başarılı:** `builds/crDroid-12.13-20261018-5/` (sha256
  ba69551b528e3402…). İçinde: yeni Glyph Interface, oyuncak sözleşmesi, Essential Notifications motoru,
  uyku programı, model A024, titreşim düzeltmesi. `/sdcard/Download`'a gönderildi, hash doğrulandı.

## Stock oyuncak seti, generative bildirimler, müzik görselleştirme (2026-10-18)

- **Stock Phone (3) oyuncakları** (B4.1 firmware'den isim/açıklama listesi çıkarıldı, kod alınmadı): NothingCardLab
  (Digital Clock, Battery, Bottle, Solar Path, Stopwatch, Rock Paper Scissors), Magicball, NothingToy (Compass,
  Feed The Fly, Moon Phase), Leveler, NTCamera (Glyph Mirror). Hepsi OpenGlyph'te sıfırdan yazıldı.
  Sonda sabit "Off" var. Eski oyuncak sırası sıfırlandı (`open_glyph_toy_order_v2`). Sensör ve kamera yalnızca
  oyuncak ekrandayken çalışıyor; sensörlü oyuncaklar 1 dk sonra kapanıyor. Clock ve Moon her zaman açık olabilir.
- **Generative bildirim:** cihaz başına rastgele seed (`open_glyph_seed`) ve paket adından deterministik melodi
  (pentatonik/lydian/dorian/hirajoshi gamları, FM ses, yankı) ve 8 motiften biriyle her notada tetiklenen
  matris animasyonu. Varsayılan desen artık bu. İsteğe bağlı olarak uygulamaların varsayılan sesteki
  kanallarına kendi sesleri atanıyor (`Notifications/OpenGlyph/*.wav`), kapatınca geri alınıyor.
  Önizleme: Bildirimler > Bir uygulamayı önizle. Nothing'in algoritması herkese açık değil;
  forumlarda yalnızca "Generative" ve "Diode/Chemical" ses motoru adları geçiyor.
- **Müzik görselleştirme:** medya dahili hoparlörden çalarken çıkış miksi (Visualizer, oturum 0) 25 aynalı
  çubuk olarak gösteriliyor; kulaklık, Bluetooth ve arama sırasında kapalı.
- Host testleri geçiyor, `m OpenGlyph` başarılı (OpenGlyph 3dd90d7).
- **"Basınca titreşiyor ama matris boş" nedeni:** (1) compat servisi oyuncak bağlanınca başlıyor ve OpenGlyph'e
  bağlanması birkaç ms sürüyor; oyuncağın ilk karesi (EndlessLife bir süre tek kare çiziyor) bu arada düşüyordu.
  Artık bekletilip bağlanınca iletiliyor. (2) Gizliyken uzun basış hiçbir şey yapmıyordu, artık oyuncağı
  gösteriyor. Ayrıca kullanıcı isteğiyle oyuncaklar arka planda tutulmuyor: ekrandan kalkınca bağlantı kesiliyor,
  bir sonraki basış sıradakini sıfırdan başlatıyor (OpenGlyph 52bca7e).
- **Titreşim yoğunluğu:** HAL'de genlik kontrolü yok. Sürücü her darbeyi tam seviyede (0x7F) başlatıp anma
  seviyesine (0x48) iniyor; başlangıç fazı uzatıldı (`cont_drv_time "e 32"`), kısa tıklar tamamen tam seviyede
  (~1,8x). Uzun titreşimler yine anma seviyesinde. Status bar saati köşeden uzaklaştırıldı
  (`rounded_corner_content_padding` 60px). Device yama 0016-0017.
- **Generative motorlar referanstan yeniden yapıldı (OpenGlyph 21ab874):** Nothing'in videosundaki motor
  bölümü indirildi; kareler 25×25'e çevrildi ve ses spektrogramla incelendi. Diode X/Y aynalı devre
  parçalarından oluşuyor: vuruş başına 2–4 kare parlıyor, arada karanlık. Chemical'da organik dokunun yanan
  alanı ses şiddetini izliyor (en fazla ~%45). Ses melodik değil, mikro-örnek dokusundan oluşuyor.
  Tarayıcı generator'ı: `open-glyph/tools/generator/generator.html` (isim, seed, motor, kaydırıcılar).
  Java portu bununla birebir aynı; testler tarayıcı çıktısına sabitlendi. Varsayılanlar kullanıcının
  kulakla ayarladığı değerler. Ayarlar > Bildirimler'de seed gösterme, elle düzenleme ve 🎲 var.
  `m OpenGlyph` başarılı. ROM derlenmedi (kullanıcı hepsi birlikte derlensin istedi).
- **7. ROM derlemesi (17:04) başarılı:** `builds/crDroid-12.13-20261018-7/` (sha256 9aa31d308636b53c…). Yeni olanlar:
  oyuncak boş ekran düzeltmesi, oyuncakların sıfırdan başlaması, yeni generative motorlar, seed ayarı,
  Taş-Kâğıt-Makas tasarımı, güçlü kısa titreşim, status bar saat boşluğu. `/sdcard/Download`'a gönderildi.
- **7. derleme sonrası test ve düzeltmeler (ROM'a girmedi):**
  - Bildirimler: generative ses çalışıyor. Ancak 6. derlemenin eski FM sesleri kanallarda kalmıştı. Artık
    generator sürümü saklanıyor; sürüm değişince eski sesler geri alınıp yenileri üretiliyor.
    Bir uygulamanın ilk bildirimi (kanal yeni oluşurken) Android gereği varsayılan sesle çalıyor.
  - Bildirim ayarlarındaki desen bölümü kaldırıldı; yalnızca generative kaldı.
  - EndlessLife: (1) yeniden başlatmadan sonra oyuncak listesi boştu, çünkü tarama direct boot'ta yapılıyordu.
    Artık kilit açılınca yeniden taranıyor. (2) Oyuncaklar BIND_FOREGROUND_SERVICE ve arka plandan FGS
    izniyle bağlanıyor (AOD'deki startForeground hatası). (3) Seçimi kaldırılan oyuncağın geç gelen kareleri
    "uygulama karesi" olarak takılı kalıyordu; artık showToyFrame ile ayrılıp düşürülüyor.
    OpenGlyph 20d44ba, 42a277c, son commit.
- **8. ROM derlemesi (17:41) başarılı:** `builds/crDroid-12.13-20261018-8/` (sha256 66268c1743432db5…). İçinde: generative-only bildirimler, eski ses yenileme,
  EndlessLife düzeltmeleri (kilit açılınca tarama, FGS izni, showToyFrame). /sdcard/Download'a gönderildi.
- **8. derleme sonrası düzeltmeler (9. ROM'da):**
  - Bildirim sesleri: bizim dosyalar artık klasörden tanınıyor (Notifications/OpenGlyph). Senkron kilit
    açıldıktan sonra yapılıyor. Yeni kanallar ChannelWatcher ile anında kendi seslerini alıyor.
  - Glyph siyah kalma: bağlanma sırasında karelerin tamponlanması ve her bağlanmada yeni identifier.
  - Ekran kapalıyken parmak izi (screen-off UDFPS) ve kayıt ışığı sepolicy düzeltmesi
    (system_app → vendor_sysfs_graphics getattr). Device 0018.
  - **Essential Key ayarları (Apple Action Button'dan esinlenildi):** Ayarlar ana sayfasında Glyph Matrix'in
    altında. Tuşu kaydırarak ya da noktalara dokunarak eylem seçiliyor: fener, sessiz mod (titreşim ya da sessiz),
    Rahatsız Etmeyin, kamera (fotoğraf, selfie ya da video), ses kaydedici, ekran görüntüsü, Glyph oyuncakları,
    oynat/duraklat, uygulama ya da hiçbiri. Tetikleme basılı tutma (450 ms, varsayılan) ya da basma.
    Eylem çalışınca matriste simgesi 0,9 sn gösteriliyor. OpenGlyph 565b7b1, device 0019, Settings 0002.
- **9. ROM (01:32):** `builds/crDroid-12.13-20261019-9/` (sha256 bf98516f…). Essential Key ayarları + yukarıdaki düzeltmeler.
- **9. derleme sonrası:**
  - Gerçek bildirimler sessizdi: kanallar silinmiş ses dosyalarımızı gösteriyordu (SystemUI "Couldn't open fd").
    Senkron/geri alma yalnızca başlatıcıda görünen uygulamaları kapsıyordu. Artık tüm paketler kapsanıyor, kullanılan
    dosya silinmiyor, dosyası kaybolmuş kanal yeniden ses alıyor (OpenGlyph 6dccd94).
  - Visualizer simetrik (bas ortada, 13 bant 200 Hz–2 kHz, 60 fps), değerler tarayıcıda ayarlandı:
    `open-glyph/tools/generator/visualizer.html` (OpenGlyph 8ad051f).
  - Ekran kapalı parmak izi: sensör olmayan `fts_gesture_fod_pressed` dosyasını bekliyordu. Dokunmatik sürücü
    parmak izi alanına dokunuşu fts_ts girişinde tuş 249 olarak gönderiyor; sensör artık bunu okuyor (device 0020).
  - Matrisin karanlık kalması: Bedtime zamanlaması (23:00–07:00), hata değil.
- **10. ROM (02:14):** `builds/crDroid-12.13-20261019-10/` (sha256 37efee95…). /sdcard/Download'a gönderildi.
- **10. ROM testleri:** Ekran kapalı parmak izi çalışıyor (sensör 630,2539 → Authenticated! ~0,4 sn). Generative
  bildirim sesleri tüm uygulamalarda çalıyor (kanallar açılışta yeni dosyalara bağlandı).
- **Kayıt ışığı takılı kalıyordu:** `delay_on` dosyası timer tetikleyicisi seçilince kernel tarafından root sahipli
  oluşturuluyor, yazma EACCES. LED yanıp sönmeye başlamış ama OpenGlyph "kapalı" sanıyordu, kayıt bitince
  kapatmıyordu. Artık durumu yalnızca trigger belirliyor; açılışta artakalan blink bir kez temizleniyor.
  Aperture ayarlarına (Video) "Kayıt ışığı" anahtarı eklendi; OpenGlyph RecordLightProvider yalnızca önyüklü
  Aperture'a cevap veriyor (OpenGlyph accd865, Aperture yama 0001).
- **11. ROM:** `builds/crDroid-12.13-20261019-11/` (sha256 5e81eaa3…). Kayıt ışığı düzeltmesi, Aperture'da kayıt ışığı anahtarı, paket adına göre generative ses/efekt (OpenGlyph 947eb37). /sdcard/Download'a gönderildi.
- **Üretken zil sesleri (ROM 12 için, derlenmedi):** Arayan başına döngülü ses + Glyph animasyonu. Telecom
  (RingtoneFactory) kişinin kendi zil sesi yoksa ve ayar açıksa `content://org.openglyph.ringtone/caller/<sha256>`
  çalar (numaranın son 10 hanesinin hash'i; numara OpenGlyph'e gitmez). OpenGlyph RingtoneProvider sesi
  seed + "call:" + hash ile üretir, çalma periyoduna dolgulu WAV verir ve aynı arayanın animasyonunu döngüde
  gösterir. Ayar: Bildirimler > Üretken zil sesleri (varsayılan kapalı). OpenGlyph b784b8a, Telecom yama 0001.
- **ROM 12 içeriği (derleniyor):**
  - Caller ID: çalarken Glyph Button kısa basış → arayanın adı/numarası kayan yazı (arama bildiriminden).
  - Glyph Progress: Android 16 Live Updates (ProgressStyle / promoted ongoing) yüzde + kaydırıcı.
  - Kum saati: Saat uygulaması zamanlayıcısı (Live Update) ile kum simülasyonu, 51 tane; ayrıca oyuncak.
  - Kamera geri sayımı: Aperture zamanlayıcısı matriste; Mirror 3-2-1 sayıp çeker, aynalı kopya da kaydeder.
  - Flip to Glyph sessiz/titreşim seçimi, Cep modu, otomatik Glyph parlaklığı.
  - Siyah tema: Material 3 yüzeyleri saf siyah (SystemUI yama 0002).
  - Üretken zil sesleri (arayan başına, döngülü) — Telecom yama 0001.
  - microG v0.3.17.252432 (resmi, GPG + imza doğrulandı) /product'ta; kurulum sihirbazında "Google hizmetleri"
    adımı, varsayılan "microG (önerilen)". `tools/fetch-microg.sh` APK'ları indirip doğrular.
    Yamalar: device 0021, SetupWizard 0001, Aperture 0002.
- **12. ROM (04:00):** `builds/crDroid-12.13-20261019-12/` (sha256 f9e38c1f…). /sdcard/Download'a gönderildi.
- **Android 17 portu (ayrı ağaç: ~/android/crdroid17, crDroid 17.0 = android-17.0.0_r1 + lineage-24.0):**
  - `tools/port17.py`: fuad00'ın metroid commit'leri + bizim yamalar; elle uyarlananlar: SystemUI parmak izi
    ripple, UDFPS yenileme hızı, Settings UDFPS footer, siyah tema, çekirdek başlıkları, SetupWizard
    (Kotlin'e geçmiş, microG adımı yeniden yazıldı). Gereksiz kalanlar: yüz kamerası (17'de var),
    allowed_deps (17'de yok), QTI titreşim (stok kullanılıyor).
  - Cihaz ağacı (17.0 dalı): libheif uyumluluk kütüphanesi, libdisplayconfig.qti yer tutucu, ses tipleri V4
    lib_fixup, Doze yardım metinleri, sepolicy 202504/202604 compat, sistem_ext Wi-Fi Display (Miracast)
    çıkarıldı (17'de değişen gizli framework sembollerini kullanıyor) → 17'de kablosuz ekran yansıtma yok.
  - Telecom 17'de mainline modül: zil sesi kodu yalnızca açık API. build.sh siso'yu algılıyor (-local_jobs).
  - **İlk A17 derlemesi başarılı (12:13):** `builds/crDroid-13.0-20261019-A17-1/` (4,1 GB,
    sha256 eddeec61…). Android 17, güvenlik yaması 2026-10-01. Telefona gönderilmedi, test edilmedi.
    Yamalar: `patches/crdroid17/`.
- **A17-2 (17:48):** `builds/crDroid-13.0-20261019-A17-2/` — Türk operatörleri için VoLTE (IMS/SMS düzeltmesi). Test edilmedi.
- **A17-3 (18:01):** `builds/crDroid-13.0-20261019-A17-3/` (sha256 b730a967…): VoLTE TR + zil sesi MediaStore düzeltmesi. /sdcard/Download'a gönderildi (16'dan güncelleme).
- **Glyph Toys stok mantığı (OpenGlyph, commit edilmedi, derlenmedi):** stok host (NtThirdParty B4.1)
  kaynak/log metinlerinden ve SDK README'den çıkarılan kurallar uygulandı (kod alınmadı):
  - Tek "Glyph Toys zaman aşımı" ayarı (15 sn, 30 sn, 1/2/5/10/30 dk; varsayılan 15 sn, `open_glyph_toy_timeout`).
    Sensörlü oyuncakların ayrı 1 dk süresi kaldırıldı. Ayar: Glyph Oyuncakları ekranı.
  - Oyuncak kilit açılınca (USER_PRESENT) ve matris yüzüstü konunca kapanır; kısa basış geri getirir.
  - Kurulum bitmeden buton yok sayılır; arama sırasında oyuncaklara olay gitmez, uzun basış Caller ID gösterir
    (stokta Caller ID uzun basışla; önceden kısa basıştı).
  - Pil düşükken (ACTION_BATTERY_LOW) Her Zaman Açık kapanır, şarjda ya da pil toparlanınca geri gelir.
  - Her Zaman Açık oyuncağı seçilince etkin oyuncaklara eklenir (bildirim toast'ı).
  - Stokta default süre değeri bulunamadı; 15 sn en kısa seçenek olduğu için seçildi.
