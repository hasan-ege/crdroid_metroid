# Glyph: her şey oyuncak + otomasyon (tasarım taslağı)

## Katmanlar (yukarıdan aşağı)

1. **Bildirimler** (oyuncak değil, her şeyin üstünde): gelen arama, arayan kimliği, bildirim
   animasyonu, önemli bildirimler, şarj takılınca kısa gösterim, kamera geri sayımı, Essential Key
   simgesi.
2. **Elle seçilen oyuncak:** Glyph tuşuna basınca açılır, tuş her zaman oyuncaklar arasında
   geçiş yapar. Süre dolunca (zaman aşımı) kapanır.
3. **Otomasyon oyuncağı:** elle seçilmiş oyuncak yokken, sıralı kurallardan **koşulu sağlanan ilk**
   kural kendi oyuncağını gösterir. Koşul sürdükçe ekranda kalır, koşul bitince bir sonraki kurala
   ya da boşa düşer.
4. Hiçbiri yoksa matris kapalı.

## Oyuncak olacak her şey

Mevcut oyuncaklar (saat, pil, güneş, ay, pusula, terazi, kronometre, şişe, taş-kağıt-makas,
Magic 8, ayna, sineği besle, SDK oyuncakları) + şimdi ayrı katman olanlar:

| Yeni oyuncak | Şu an |
|---|---|
| Görselleştirici (Sabit / Hareketli) | müzik katmanı |
| Arama sesi | arama katmanı |
| Kum saati (zamanlayıcı) | Live Update katmanı |
| İlerleme (Live Update: teslimat, indirme…) | Live Update katmanı |
| Her zaman açık saat | AOD katmanı → kural olur |

## Otomasyon kuralları ("küçük n8n")

Ayarlar → Glyph Oyuncakları → **Otomasyonlar**. Sıra sürükleyerek değişir, üstteki kazanır.
Her kural: **EĞER** koşulların hepsi doğruysa **İSE** şu oyuncağı göster.

Koşullar:
- Ses çalıyor — istersen yalnızca seçtiğin uygulamalardan (beyaz liste)
- Zamanlayıcı çalışıyor (Saat uygulaması)
- Live Update / ilerleme var
- Arama sürüyor
- Şarj oluyor
- Telefon yüzüstü (matris yukarıda) / ekran yukarıda
- Ekran kapalı / açık
- Kulaklık takılı
- Saat aralığı (ör. 08:00–23:00)

Varsayılan kurallar:

| Sıra | Eğer | İse |
|---|---|---|
| 1 | Arama sürüyor | Arama sesi |
| 2 | Zamanlayıcı çalışıyor | Kum saati |
| 3 | Ses çalıyor | Görselleştirici |
| 4 | İlerleme var | İlerleme |
| 5 | Ekran kapalı ve telefon yüzüstü | Saat (kısık) |

Uyku saatinde (bedtime) hepsi kapalı, eskisi gibi.

## Diğer

- Oyuncak zaman aşımı varsayılanı uzatılacak.
- USB bilgisayara bağlanınca görünür bir "USB ne için kullanılsın?" bildirimi
  (Dosya aktarımı / Yalnızca şarj düğmeleriyle).
