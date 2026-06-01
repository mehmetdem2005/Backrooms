# Backrooms Premium — V4 Oyun Geliştirme Planı

> **Vizyon:** Bu bir labirent değil — *seni inceleyen bir organizma*.
> Premium mobil psikolojik Backrooms korku oyunu: **harita seni öğrenir, canavar seni dinler, çıkış sana yalan söyler.**
> Slogan: **“The Backrooms learns how you panic.” / “Backrooms nasıl korktuğunu öğrenir.”**

Bu dosya, oyunu klasik bir "Backrooms klonundan" çıkarıp gerçek bir oynanış/korku oyununa dönüştürmek için yol haritasıdır.

---

## 0. Temel Felsefe

Oyuncu "koridorda yürüyorum" demesin; sürekli şunları düşünsün:
*"Ses çıkardım mı? Işığı açtım mı? Yanlış yola mı girdim? Arkamda bir şey var mı?"*

Her an küçük kararlar / risk-ödül ikilemleri:
- **Fener aç:** daha iyi gör ↔ canavar seni fark eder.
- **Koş:** hızlı kaç ↔ ses çıkarırsın.
- **Kapı aç:** yeni yol ↔ gıcırtı canavarı çağırır.
- **Dolaba saklan:** kurtul ↔ nefes sesin artarsa yakalanırsın.

Referans güçlü yönler (Inside/Escape the Backrooms, Escape Together): proximity ses, varlıkların sesi duyması, stamina, sınırlı envanter, her entity'nin kendine özgü mekaniği, procedural seviyeler, puzzle ve kaçış hedefleri.

---

## 1. Ana Oyun Döngüsü

**Yanlış (mevcut):** Haritada yürü → canavar gelirse kaç → çıkışı bul.

**Doğru hedef döngü:**
> Uyandın → çevreyi dinle → ipucu topla → sigorta/anahtar/kod bul → ses çıkarmadan ilerle → canavarın davranışını öğren → yanlış çıkışlara aldanma → gerçek çıkışı aç → kaç.

---

## 2. Canavar AI — "oyuncuyu okuyan" (akıllı değil, hisseden)

Canavar sadece `player.global_position` takip etmesin. Durum makinesi:

| Durum | Davranış |
|---|---|
| **Patrol** | Haritada rastgele gezer |
| **Listen** | Oyuncu ses çıkarınca durur, dinler |
| **Investigate** | Son ses konumuna gider |
| **Stalk** | Uzaktan takip eder, hemen saldırmaz |
| **Ambush** | Koridor köşesinde bekler |
| **Chase** | Gördüyse koşar |
| **Search** | Kaybederse son bölgede arar |
| **Fake Retreat** | Çekilmiş gibi yapıp başka yoldan yaklaşır |

**En korkutucu kural:** Canavar her zaman görünmesin. Bazen sadece sesi gelsin, bazen gölgesi, bazen uzak koridorda 1 saniye durup kaybolsun.

---

## 3. Ses Sistemi (oyunun yarısı)

### Ambient/olay ses katmanları
Floresan uğultusu · uzak metal vurma · boru içi yankı · halı üstü ayak sesi · nefes sesi · kalp atışı · canavar nefesi · yanlış çıkış sesi · elektrik kesilme sesi.

### Ses seviyesi (noise) sistemi — canavar bunu duyar
| Eylem | Ses |
|---|---|
| Yürüme | 0.25 |
| Koşma | 0.75 |
| Kapı açma | 0.60 |
| Metal kutuya çarpma | 1.00 |
| Fener aç/kapa | 0.15 |
| Nefes/panik | 0.30 |

Ses **uzaksa** canavar sadece araştırır; **yakınsa** kovalar.

---

## 4. Harita Bölgeleri ("aynı ama farklı")

| Bölge | Görev |
|---|---|
| Classic Yellow Rooms | Ana Backrooms hissi |
| Wet Carpet Zone | Ayak sesi yüksek, yavaşlatır |
| Dark Maintenance Area | Borular, elektrik, karanlık |
| Office-like Room | Puzzle ve evrak ipuçları |
| False Exit Hall | Sahte çıkışlar |
| Red Light Zone | Canavar daha agresif |
| Storage Room | Pil, anahtar, not |
| Long Silent Hall | Sesin kesildiği psikolojik bölüm |

### Katmanlı ilerleme (Level 0 → aşağı)
- **Level 0** — Sarı Backrooms (klasik)
- **Level 0.5** — Islak Bölge (halı ıslak, koşmak riskli)
- **Level 1** — Maintenance (borular, servis tünelleri, elektrik)
- **Level 2** — Office Remnant (notlar, ekranlar, şifreler)
- **Level 3** — Red Zone (kırmızı ışık, agresif canavar, sahte çıkış)
- **Level 4** — The Quiet Floor (hiç ses yok — oyuncunun sesi bile kesilir)
- Finalde oyuncu çıktığını sanır ama daha derine düşmüş olabilir.

---

## 5. Puzzle / Hedef Sistemi (ObjectiveManager)

**Ana kaçış görevi:** 3 sigorta bul → elektrik odasına tak → yanlış çıkışlar arasından gerçeğini bul → asansör/paslı kapı aç → final kovalamaca.

**Mini puzzle fikirleri:** duvarlarda sayı ipuçları · eski notlarda yön tarifleri · yalan söyleyen tabelalar · gerçek yolu gösteren floresanlar · kırmızı=tuzak/sarı=güvenli (ama bazen ters) · ses kasetinden kapı kodu · geri dönünce değişen koridor.

---

## 6. Oyuncu Sistemleri

### Fener
Pil azalır · titrer · canavar ışığı fark eder · hızlı aç/kapa canavarı kızdırır · bazı ipuçları sadece fenerle görünür.

### Stamina
Koşunca azalır · canavar yakınsa hızlı tükenir · panikte nefes sesi artar · nefes canavarı çeker.

### Sanity / Akıl
Uzun karanlık/canavar görme → HUD bozulur · sahte canavar gölgeleri · değişen tabelalar · gecikmeli fener · kendi ayak sesini arkadan duyma · duvar desenleri yüze döner. **Sıfırda ölme yok** — sadece neyin gerçek olduğunu anlayamama.

---

## 7. Canavar Çeşitleri (her entity FARKLI kural)

1. **Stalker** — uzaktan izler, bakınca saklanır, gerilim yaratır.
2. **Listener** — görmez, çok iyi duyar; koşarsan/kapı açarsan/metale çarparsan gelir; saklanırken nefes kontrolü.
3. **Watcher** — ona bakarsan durur, bakmazsan yaklaşır; çok bakarsan sanity düşer.
4. **Mimic** — ses/tabela/çıkış taklidi yapar, sahte koridorlara çeker.
5. **Crawler** — tavan boşluklarında gezer; tavan paneli düşerse yakındır.
6. **Chaser** — az görünür ama görünürse çok tehlikeli; final kovalamaca.
7. **Manager (final)** — haritayı değiştirir, kapıları kilitler, ışığı kontrol eder.

---

## 8. Görsel Kalite — asset yoğunluğu (düşük poligon + iyi texture)

Duvar varyasyonları (temiz/küflü/yırtık/ıslak) · halı varyasyonları (kuru/ıslak/koyu leke/ezilmiş) · tavan panelleri (sağlam/çatlak/eksik/sarkık) · borular, kablolar, havalandırma · bozuk floresan · kağıt yığınları · eski tabela · kilitli kapı · sigorta kutusu · kaset çalar · güvenlik kamerası · duvar yazıları · düşmüş tavan parçası · paslı metal dolap.

> Kaynak: PolyHaven (CC0 PBR) + TripoSR (görselden-3D) + Blender (bpy) prosedürel/rig.

---

## 9. Mobil Kalite Ayarları (tek ayar olmasın)

| Ayar | Seçenek |
|---|---|
| Render Scale | 70 / 85 / 100 |
| Shadow Quality | Low / Medium / High |
| Fog Quality | Off / Normal / Premium |
| Dynamic Lights | 4 / 8 / 12 |
| Texture Quality | 1K / 2K |
| Monster Detail | Low / High |
| Post Process | Off / On |
| FPS Target | 30 / 45 / 60 |

Godot Mobile renderer: ışık havuzu + yakın çevrede aktif ışık + (yarı) baked mantık + LOD şart.

---

## 10. V4 — "Gerçek Oynanış Paketi" (modüller)

1. **ObjectiveManager** — sigorta bulma, kapı açma, gerçek çıkış kontrolü
2. **AdvancedMonsterAI** — görme, ses duyma, son bilinen konum, pusu, kovalama, arama
3. **NoiseSystem** — koşma/kapı/eşya/fener sesi, canavar duyma mesafesi
4. **AudioDirector** — katmanlı ambience, uzak olaylar, tehlike müziği, nefes, kalp
5. **MapChunkSystem** — oda varyasyonları, sahte çıkışlar, özel bölgeler, daha büyük harita
6. **Inventory** — pil, sigorta, anahtar kartı, notlar (sınırlı slot)
7. **ScareDirector** — kontrollü korku olayları (ışık titreme, uzak gölge, kapı, sahte ayak sesi)

### Öncelik sırası (ilk 5)
1. **Ses + Noise System**
2. **Akıllı canavar AI**
3. **Görev/puzzle sistemi**
4. **Harita chunk varyasyonları**
5. **Kalite ayarları + optimizasyon**

---

## 11. Oyunu Klondan Çıkaran Büyük Fikirler

1. **Harita oyuncuyu öğrensin** — sürekli sağa dönüyorsa sağ taraf tehlikeli olur; çok koşuyorsa halı ıslanır; hep fener açıksa ışığa duyarlı canavar gelir; aynı tabelaya güveniyorsa tabelalar yalan söyler; odaya geri dönünce oda değişir. **"Harita seni izliyor."**
2. **Bina da düşman** — koridor arkanda kapanır; ışıklar baktığın yerde değil arkanda yanar; duvar kâğıdı kıpırdar gibi; tabelalar sana özel mesaj; güvenli oda içinde kapı kaybolur; aynı koridora 3 kez girince pusu.
3. **"Don't Look Back" mekaniği** — "ARKANA BAKMA" + arkadan ayak sesi; bakarsan canavar yaklaşır/fener bozulur/harita değişir; ama bazen gerçek çıkış arkanda oluşur.
4. **Sahte çıkış sistemi** — çok "EXIT" tabelası, çoğu sahte (aynı odaya atar / canavar sesi / daha derine indirir / kırmızı tuzak / uğultu artar). Gerçek çıkış sadece **fener kapalıyken** görünür.
5. **Canavar oyuncuyu kandırsın (Mimic)** — uzakta "çıkış sesi", çocuk ağlaması, oyuncunun ayak sesini taklit, kapı sesi, sahte "güvenli oda".
6. **Telefonu oyuna kat** — yaklaşınca titreşim; fener bozulunca ekran titrer; stereo nefes (sağ/sol); panikte HUD bozulur; bazı kapılar için telefonu eğmek; bazı notlar doğru açıyla fenerle okunur.
7. **Sanity ile delirme** — sahte gölgeler, yanlış HUD, çoğalan EXIT, gecikmeli fener, yüze dönen duvarlar.
8. **Güvenli oda ama tam değil** — pil/not/harita parçası/ses kaydı; uzun kalırsan floresan artar, kapı tıklar, altından bir şey geçer, canavar yerini öğrenir.
9. **Katmanlı iniş** (bkz. Bölüm 4).
10. **Her canavarın farklı kuralı** (bkz. Bölüm 7).
11. **Kalıcı sonuçlu seçimler** — çok fener → ışık canavarı; çok koşu → ses canavarı; çok not → Mimic artar; uzun safe room → güvensizleşir; yanlış çıkış → harita bozulur. (tekrar oynanabilirlik)
12. **Ses kaydı hikâye sistemi** — kayıp çalışan, önceki oyuncu günlüğü, bakım raporu, canavar ipuçları. Örn: *"Eğer ışıklar aynı anda sönerse koşma. O zaten seni duymak için bekliyor."*
13. **Yanlış güven kur** — sarı ışık/EXIT/dolap/sessizlik önce güvenli sanılır, sonra kurallar bozulur.
14. **Harita nefes alsın** — duvarlar hafif kabarıp iner, floresan kalp ritmine döner, halıdan nem, borudan nefes, tavan titreşir, koridor uzuyor gibi (abartmadan).
15. **Özel final kovalamaca** — gerçek çıkış açılır → ışıklar söner → harita yeniden dizilir → ipuçlarına göre doğru yol değişir → canavar panik seviyesine göre gelir → fener %5 → sahte çıkışlar çoğalır → gerçek çıkış sadece fener kapalıyken.
16. **Kamera kayıtları** — güvenlik odası ekranları; bazen canavarı, bazen oyuncunun arkasını, bazen "başka odadaki kendini" gösterir; canavar kameraya bakınca kapanır.
17. **Mini-map yok, haritayı parça parça buldur** — duvar krokileri, ofis planları (bazıları yalan), "You are here" yanlış yeri gösterir.
18. **ScareDirector** — jumpscare spam yok; oyuncunun durumuna göre korku seçer (uzun süre sakinse uzak gölge/ışık titreme; çok panikse sessizlik; çok rahatsa arkadan ayak sesi/yakın spawn ama saldırmaz).
19. **Gerçekçi loot/sınırlı envanter** — pil, sigorta, anahtar kartı, not, kaset, **sprey boya/tebeşir** (işaret koy — ama bazı bölgede işaretler değişir/silinir), kapı kolu, harita parçası.
20. **"Ben buradan geçtim mi?" hissi** — aynı oda varyasyonları, küçük değişen objeler, bozulan işaretler, farklı ışıkla tekrar gösterim.
21. **Hikâye sırrı** — burası rastgele oluşmadı; korkuları kullanarak büyüyen bir mekân. Tabelalar bilinçli, canavarlar binanın savunması, floresan sesleri bir dil, EXIT'ler yem; gerçek çıkış dışarı değil **kontrol odası**. Finalde kaçmak yerine binayı kapatma seçeneği.
22. **Pazarlama: "Her oyuncunun Backrooms'u farklı"** — oyun ilk 10 dk oyuncuyu analiz eder (koşu/saklanma/fener/arkaya bakma/ses) ve korkuyu ona göre üretir.
23. **Mobil viral: ölüm raporu** — "Ölüm nedeni / en büyük hata / canavar seni ne zaman fark etti / hayatta kalma süresi" → TikTok/Shorts paylaşımı.
24. **Oyun modları** — Story · Endless · Nightmare (az pil, akıllı canavar) · No Flashlight · One Life.
25. **En büyük fikir: Backrooms = zekâ** — harita oyuncuya göre değişir, canavar alışkanlıkları öğrenir, sesler yönlendirir, tabelalar yalan söyler, güvenli odalar bozulur, çıkışlar kandırır.

---

## Uygulama Notları (teknik durum)

**Tamamlanan altyapı (v3.x):**
- Çok katlı oda+koridor labirenti (rampalı), kat-farkındalıklı Vector3i pathfinding.
- TripoSR + Blender (bpy) ile riglenmiş canavar (idle/walk/attack), amansız takip + yol düzleştirme.
- PolyHaven CC0 PBR texture'lar (duvar/zemin/tavan/beton/metal).
- AAA fener (yumuşak huzme + elde model), kaliteli karanlık (görüş ışığı), mobil dokunma kontrolleri.
- **Godot içi yazılım-GL render** (Mesa llvmpipe + xvfb) → APK yapmadan önizleme alınabiliyor.

**Sıradaki (V4 — öncelik sırasıyla):**
1. NoiseSystem + katmanlı AudioDirector
2. AdvancedMonsterAI (Patrol/Listen/Investigate/Stalk/Ambush/Chase/Search)
3. ObjectiveManager (sigorta → elektrik → gerçek çıkış)
4. MapChunkSystem (oda varyasyonları, bölge tipleri, sahte çıkışlar)
5. Kalite ayarları menüsü + optimizasyon (ışık havuzu, LOD)
6. Inventory + ScareDirector + Sanity
7. Ek entity'ler (Listener, Watcher, Mimic)
</content>
