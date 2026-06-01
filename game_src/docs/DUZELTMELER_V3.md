# Backrooms Premium Mobile V3 — Düzeltmeler ve Geliştirmeler

Godot **4.6.3 / Mobile renderer**, üst seviye telefon hedefi.

## Nasıl doğrulandı
Bu cihazda Godot motor ikilisi indirilemediği için (ağ kısıtı), doğrulama iki gerçek
araçla yapıldı: **gdtoolkit `gdparse`** (gerçek GDScript dilbilgisi ayrıştırıcısı) tüm
scriptlerde **0 sözdizimi hatası** verdi; kullanılan tüm motor API üyeleri **Godot
4.6.2 resmi sınıf XML'lerine** (miras dahil) karşı tek tek doğrulandı. gdlint çıktısındaki
uyarılar yalnızca stil (satır uzunluğu, tanım sırası) — derleme hatası değildir.

## Taranan/Düzeltilen hatalar
- **`Environment.fog_depth_enabled` yok (4.6).** Eskiden `_set_if_property` ile sarılıydı,
  bu yüzden derinlik sisi **sessizce hiç uygulanmıyordu**. Doğru API ile değiştirildi:
  `environment.fog_mode = Environment.FOG_MODE_DEPTH` + `fog_depth_begin/end/curve`.
- **`seed` gölgeleme uyarısı** (`@GlobalScope.seed()` fonksiyonunu gölgeliyordu).
  Hem GameRoot hem Builder'da `world_seed` olarak yeniden adlandırıldı
  (gerçek `_rng.seed` özelliği korundu).
- **Runtime'da `ProjectSettings.set_setting(...)` no-op'tu** (render ayarları yalnızca açılışta okunur).
  Gerçekten etki eden **Viewport** ayarlarıyla değiştirildi (MSAA 4X, debanding, gölge atlası).
- `_set_if_property` yardımcı fonksiyonu tamamen kaldırıldı; tüm Environment/Probe özellikleri
  artık doğrulanmış gerçek adlarla doğrudan atanıyor.

## Fener (bozuktu → düzeltildi)
- Parlak koni: `light_energy` 4.2, menzil 26, `light_specular`. Ek olarak kameraya **yakın
  dolgu ışığı (OmniLight3D)** eklendi; fener açıkken hemen önün net aydınlanır ("çalışıyor" hissi).
- Pil tüketimi/şarjı, düşük pilde kırpışma, doğru aç/kapa (klavye F + mobil FENER butonu),
  fener açma sesi (tık) ve düşük pilde kırmızı HUD uyarısı.

## Kaliteli karanlık mekaniği (fener kapalıyken)
- Taban ortam ışığı 0.22 → **0.10**; floresan yokken gerçek karanlık.
- Post-process shader yeniden yazıldı: fener kapalıyken ekran kenarları kapanır, merkezde
  küçük bir görüş alanı kalır; karanlıkta nefes alıp veren daralma. GameRoot her karede
  oyuncunun bulunduğu noktadaki floresan aydınlatmasını ölçüp (`get_illumination`) karanlığı
  ve görüş yarıçapını yumuşak geçişle sürer.

## Gelişmiş canavar AI'sı
- **Görünürlük tabanlı algı:** fener açık + hareket + ışık altında çok görünürsün; **çömelip
  (GİZLEN) durursan ve karanlıktaysan neredeyse görünmezsin** → canavarı şaşırtabilirsin.
- **Saldırganlık (aggression)** zamanla ve seni gördükçe artar: takip hücresi giderek sana
  yapışır, bekleme süreleri kısalır → **"sürekli kovalar"**; çok uzaklaşırsa yakınına yeniden konumlanır.
- **Kovalarken lead-pursuit:** hızına bakıp gittiğin yöne önden kestirme yapar.
- Kaybettiğinde (iyi saklanınca) farkındalığı **hızla** düşer → ARIYOR → TAKİPTE; sesle (ayak/koşu)
  tekrar tetiklenir. Durumlar: Takipte / Sesi duydu / Arıyor / Kovalıyor / Pusu kuruyor.

## Ses sistemi (yeniden yazıldı) + yeni sesler
Yeni prosedürel sesler eklendi (sentez): `sub_drone`, `chase_layer`, `dark_ambience`,
`jumpscare_hit`, `scare_riser`, `monster_scream`, `monster_breath_close`, `monster_whisper`,
`monster_step`, `heartbeat_strong`.
- Dinamik katmanlar: gerilim arttıkça yükselen drone; **yalnızca kovalarken** giren kovalama
  müziği; fener kapalıyken yükselen karanlık ambiyansı.
- **Canavarı uzamsal takip eden 3D ses:** mesafe/duruma göre nefes/fısıltı/hırlama; canavar
  adım sesleri (hıza göre tempo); kovalama başında çığlık + riser.
- Yakınlıkla hızlanan güçlü kalp atışı.

## Jumpscare
- Yakalanma anında: yaratık tam önüne gelir, bakış kilitlenir, tam ekran prosedürel yaratık
  yüzü + beyaz patlama→siyah kapanış flaşı + kamera sarsıntısı + çığlık/jumpscare vuruşu.
- Kovalarken çok yaklaşırsa ara sıra **ölümcül olmayan irkilme** (kısa flaş + çığlık + sarsıntı).

## Harita (düzeltildi/geliştirildi)
- Çıkış artık Öklid mesafesiyle değil **başlangıçtan BFS (koridor) mesafesiyle en uzak
  ulaşılabilir hücre** seçiliyor → **çıkışa giden gerçek bir yol garanti**. Düşman, başlangıç
  ve çıkışa koridor mesafesi yüksek bir orta noktada başlatılıyor. Oda sayısı 30.

## project.godot — üst seviye mobil
Mobile renderer korundu; MSAA 3D 4X, ETC2/ASTC sıkıştırma, debanding, anizotropik 4x,
yumuşak gölge filtresi (yön + konumsal, 4096 atlas), yatay (sensor-landscape) yönelim, 3D ölçek 1.0.

## Notlar
- **İlk açılışta** editör yeni `.wav` dosyalarını otomatik içe aktarır (kısa sürer).
- Mobil kontroller: Sol = yürü, Sağ = bak, **FENER** aç/kapa, **GİZLEN** (sessiz+karanlıkta
  görünmez), **KOŞ**. Masaüstü: WASD, fare, F (fener), C/Ctrl (çömel), Shift (koş).

---

## Cihaz testi sonrası düzeltmeler (Mali-G76, gerçek Godot 4.6.3 koşusu)
Gerçek cihaz debugger çıktısına göre yapılan ek düzeltmeler:

- **Volumetrik sis yalnızca Forward+ renderer'da çalışır** — oyun Mobile renderer kullandığı
  için debugger'a hata basıyor ve hiçbir etki yapmıyordu. **Kapatıldı**; atmosfer normal
  derinlik sisiyle (Mobile'da desteklenen) sağlanıyor.
- **Performans (18 FPS → hedef yüksek):** asıl darboğaz, floresan ışık yöneticisinin **her
  karede tüm fikstür listesini script-callable karşılaştırıcıyla sıralamasıydı**. Artık en
  yakın ışıklar saniyede ~4 kez, callable'sız O(n·K) tek geçişle seçiliyor; her kare yalnızca
  seçili 8 ışığın kırpışması güncelleniyor (kare başına binlerce script çağrısı elendi).
- **`is_inside_tree()` uyarısı:** oyuncu ve canavar, `global_position` atanmadan önce sahne
  ağacına eklenecek şekilde sıra düzeltildi.
- **Tüm GDScript uyarıları temizlendi:** `seed` (→ `world_seed`), tamsayı bölme (→ `sign()`),
  `scale`/`basis`/`offset` taban-sınıf gölgelemeleri (yeniden adlandırıldı), kullanılmayan
  `delta`/parametreler (→ `_delta` / `_` ön eki), kullanılmayan `_body_mesh`.

Doğrulama: `gdparse` tüm scriptlerde 0 sözdizimi hatası; `gdlint` unused-argument = 0
(kalan gdlint çıktısı yalnızca satır uzunluğu ve tanım sırası — motor bunları uyarı olarak
basmaz, derlemeyi etkilemez).

---

## İkinci geri bildirim turu (oynanış)
- **Harita sütunları/çizgileri:** Kolonlar artık koridor ortasında rastgele durmuyor —
  yalnızca **oda içi hücrelerde** (dört yanı açık), tabandan tavana, daha kalın ve hücre
  köşesine hizalı (gerçek destek kolonu dizisi gibi). Tavan **tel ve boruları** artık yalnızca
  koridor ekseni boyunca, komşu hücreler açıkken yerleşiyor → havada rastgele kısa çizgiler
  yerine sürekli, anlamlı hatlar.
- **Tehlike (yakınlık) barı:** Artık sabit 0 takılmıyor. Mesafe **harita boyutuna oranlanıyor**
  (`maze_width * cell_size`) ve canavarın **farkındalığıyla** harmanlanıyor — canavar seni
  avlarken (uzakta bile) bar yükselir, kovalarken dolar.
- **Yapay zeka (çok daha akıllı, seni bulur):** Artık uzakta rastgele dolaşmıyor. TAKİP
  durumunda **doğrudan sana yaklaşır** (1–3 hücre), daha sık yol bulur; görüş menzili ve işitme
  arttı, KOVALAMA eşikleri düştü, farkındalığı daha yavaş kaybeder, saldırganlık daha hızlı
  birikir. Işınlanarak yeniden konumlanma yalnızca **42 m+** uzaktayken (rastgele hissi kalktı).
  Yine de çömelip (GİZLEN) karanlıkta sessiz durursan kaybeder.
- **Fener (artık düz yuvarlak değil):** Spot ışığa **prosedürel projektör dokusu (cookie)**
  eklendi → yumuşak kenarlı, hafif dokulu gerçek fener huzmesi; spot açısı/yumuşaması ayarlandı.
  Zeminde belirgin yuvarlak parlama yapan dolgu ışığı kısıldı.
- **Ayak sesi (silah gibiydi):** Sert örnekler atıldı; **yumuşak, alçak gövdeli halı adımı +
  kısa kumaş hışırtısı** sesleri sentezlendi; çalma seviyesi/pitch'i de düşürüldü.

---

## AAA görsel/asset geliştirmesi
- **Prosedürel PBR doku setleri (512², döşenebilir):** Duvar kâğıdı, halı, asma tavan, beton ve
  metal için **albedo + normal + roughness** haritaları (numpy ile, fraktal yükseklik alanından
  Sobel normal). Eski 384² hash-gürültü dokuların yerine geçti → gerçek yüzey kabartması ve
  malzeme hissi. `textures/` klasöründe; ETC2/ASTC ile mobilde sıkışır.
- **Dünya-uzayı triplanar haritalama:** Büyük multimesh kutularında doku gerilmesi/dikiş izi
  ortadan kalktı; doku ölçeği tüm yüzeylerde tutarlı (duvar/zemin/tavan/beton/metal).
- **Gerçek malzemeler:** Borular ve havalandırmalar artık **metalik** (çizik normal haritalı);
  destek kolonları **beton**; floresan panelleri daha güçlü emissive.
- **Asma tavan T-bar ızgarası:** Her hücrede ince çapraz metal ızgara → ofis/backrooms asma
  tavan görünümü.
- **Gömme floresan kasası (troffer):** Her panelin etrafında koyu metal çerçeve → ışıklar
  gerçek tavan armatürü gibi durur.

Doğrulama: tüm scriptler `gdparse` 0 hata; kullanılan tüm BaseMaterial3D/StandardMaterial3D
üyeleri (albedo/normal/roughness_texture, metallic, uv1_scale, uv1_triplanar, texture_filter)
Godot 4.6.2 XML'lerine karşı doğrulandı. PNG'ler ilk açılışta otomatik import edilir.

---

## Üçüncü oynanış turu
- **Yaklaşırken lag:** İki gerçek spike kaynağı bulundu ve giderildi. (1) `get_grid_path` BFS'i
  `remove_at(0)` ile O(n²)'ydi → açık/büyük haritada kovalarken donduruyordu; indeks-işaretçili
  O(n) kuyruğa çevrildi. (2) `get_ambush_cell_around` TÜM açık hücreleri gezip her biri için yol
  buluyordu (canavar yaklaşıp pusuya geçtiğinde sürekli spike) → tek O(n) seçime indirildi.
  Ayrıca yol hedefi geçersizse (duvar) **en yakın açık hücreye sabitleniyor** → canavar artık
  kovalarken donmuyor.
- **Canavarı bulma:** TAKİP'te artık çoğunlukla **doğrudan oyuncuya yöneliyor** (seni aktif arar
  ve bulur), hızları artırıldı. Hedef sabitleme sayesinde beeline güvenilir.
- **Ayak/canavar sesi menzili:** Adım ve nefes/fısıltı seslerinin işitilebilir mesafesi ve hacmi
  belirgin artırıldı → canavarı **çok daha uzaktan duyarsın** (yalnızca yakalayacakken değil).
- **Harita sıfırdan (vasat → kaliteli):** Tek genişlikli mükemmel labirent kaldırıldı. Yeni
  **açık backrooms düzeni**: geniş açık alan, **kapı boşluklu bölme duvarlarıyla** düzensiz odalar
  ve koridorlar, dağınık dolu bloklar/kolon kümeleri; başlangıç çevresi garanti açık;
  **bağlantı garantisi** (başlangıçtan erişilemeyen açık hücreler doldurulur) ve çıkış BFS ile en
  uzak ulaşılabilir hücre. Açık odalar + hizalı kolon dizileri + tavan ızgarası → gerçek backrooms.

---

## Dördüncü oynanış turu (ekran görüntüsü geri bildirimi)
- **Gerçekçi oyuncu nefesi:** İki sentez döngü eklendi — sakin burun nefesi ve eforlu panting.
  Koşma + düşen dayanıklılık + stres "efor" değerini yükseltir; sakin↔panting yumuşak geçişle
  karışır, panting'in perdesi (hızı) eforla artar. Yeni "Player" ses yolu.
- **Tuşlar yenilendi (yuvarlak + düzgün):** Joystick artık gerçek **yuvarlak** taban+topuz
  (StyleBoxFlat), sol yarıda dokunulan yere gelir, bırakınca merkeze döner. FENER / KOŞ / GİZLEN
  **yuvarlak** tuşlar; basılıyken renk değişir (geri bildirim). KOŞ basılı-tut, GİZLEN aç/kapa.
- **Karanlık mekaniği (kapkaranlık → atmosferik):** Shader'da siyah karışımı ve alfa tavanı
  düşürüldü; fener kapalıyken kenarlar kararır ama **merkezde gözün alıştığı dim bir görüş**
  kalır (artık tam siyah değil). Taban ortam ışığı 0.10→0.16, görüş yarıçapı genişletildi.
- **FPS sayacı:** Sol alta küçük bir "FPS" göstergesi eklendi.
- **Harita:** Açık düzene **büyük açık holler** eklendi (içlerinde hizalı kolon ızgaraları ile) →
  görkemli geniş backrooms alanları + çeşitlilik; bölme yoğunluğu biraz azaltıldı (daha büyük odalar).

---

## Performans turu ("oyun çok kasıyor")
Mali-G76 (orta seviye mobil GPU) için en ağır kalemler tespit edilip düşürüldü:
- **Floresan ışıkların gölgeleri kapatıldı** — 2 floresan *omni* ışığı küp gölge (6'şar yüz =
  12 gölge render) yapıyordu; mobildeki **en büyük yük buydu**. Sadece fener (tek spot) gölge yapar.
- **MSAA 4X → 2X** (çalışma anında 4X'e zorlanıyordu) — 1080p'de büyük fill kazancı.
- **Gölge atlası 4096 → 2048**, yumuşatma filtre kalitesi 2 → 1.
- **Aktif floresan ışık sayısı 8 → 6** (Forward Mobile ışık kümesi limitine yakındı).
- **Yansıma probları kapatıldı** (ek render geçişi, etkisi inceydi).
- **PBR triplanar örnek maliyeti düşürüldü:** roughness dokuları skaler değere çevrildi, normal
  harita yalnızca duvar/metal/betona bırakıldı (zemin/tavan normalsiz). Kullanılmayan dokular silindi.
- **Toz parçacıkları 420 → 240.**
Görünüm büyük ölçüde korundu; en hissedilir değişiklik floresan gölgelerinin yumuşaması.

---

## Chunk sistemi + lamba geliştirme
- **Chunk sistemi:** Harita artık `chunk_size` (varsayılan 8 hücre = 32 m) parçalara bölünüyor.
  Her chunk kendi `Node3D`'si altında kendi multimesh setini ve kendi `StaticBody3D` çarpışma
  gövdesini (chunk zemini + o chunk'taki duvar kutuları) taşıyor. `PremiumBackroomsBuilder.chunks`
  listesi dışarı açık.
- **ChunkStreamer (yeni):** Oyuncu oluşturulduktan sonra kurulur; ~0.2 sn'de bir her chunk'ın
  merkezine olan mesafeye bakar. Yakın chunk'lar **görünür + çarpışır**, uzaktakiler
  `visible=false` ve `collision_layer=0` ile **kapatılır**. Görüş mesafesi ~2 chunk yarıçapı.
  Tüm geometri tek seferde kurulur (oynarken kurma takılması yok), sonra mesafeye göre kültür edilir.
  → Çizim çağrısı / instance / overdraw / fill ve fizik çiftleri büyük ölçüde azalır.
- **Optimizasyon temeli:** Bundan sonraki içerik/optimizasyon değişiklikleri bu chunk yapısına göre
  yapılacak (yeni geometri tipleri `_chunk_type_info` tablosuna eklenip otomatik chunk'lanır).
- **Tavan lambaları geliştirildi:**
  - Tek panel yerine **çift floresan tüp** (twin-tube troffer) + daha geniş metal kasa.
  - Emissive tüp materyali daha parlak ve soğuk-beyaz (enerji 3.4 → 4.6).
  - Işık havuzu: hastalıklı floresan beyazı renk, parlaklık ↑ (1.68 → ~2.05), menzil ↑.
  - **Konuma bağlı arızalı tüpler:** belirli tavan lambaları sürekli vızıldar ve ara ara söner
    (gerçek bozuk floresan hissi); parlaklığa göre renk sıcak↔soğuk kayar.

---

## Beşinci oynanış turu (UI + AI + ses + harita düzeltmeleri)
- **Yazı karışması düzeltildi:** Mobil kontrollerdeki ipucu yazısı HUD üst-sol yığınıyla
  (çıkış mesafesi + barlar) tam üst üste biniyordu → kaldırıldı. İpuçları zaten altta dönüyor.
- **FPS göstergesi:** En altta (y=1040) "expand" en-boy oranında kırpılıyordu → üst-sola taşındı
  (belirgin, yeşil, 24 punto).
- **Havada uçuşan tabelalar:** Uyarı tabelaları boşlukta rastgele konumlanıyordu → artık yalnızca
  komşu **duvara yapıştırılıyor** (duvar yüzeyine hizalı, göz hizası üstü). Duvarı olmayan hücrede
  tabela yok.
- **Canavar daha az rastgele:** STALK'ta doğrudan oyuncuya yönelme %78 → %90; pusu (AMBUSH) daha
  seyrek (bekleme 6–10 → 11–16 sn) ve yalnızca oyuncu 16 m'den uzaktayken → amaçsız gezinme azaldı,
  daha kararlı/tehditkâr takip.
- **Yakınlık sesi yumuşatıldı:** Canavar sesi/adımı artık 3D **inverse-distance** sönümleme kullanıyor
  (doğal, sürekli artış); manuel ses eğrisi smoothstep ile yumuşatıldı ve tepkisi hızlandırıldı →
  yaklaşırken ani sıçrama yok. Yakınlık ayrıca gerilim drone'unu yumuşakça yükseltiyor.
- **Canavar adım sesi yeniden üretildi:** Eski cızırtılı (geniş-bant gürültü) ses yerine katmanlı,
  kaliteli ve rahatsız edici bir ayak sesi: ağır ıslak gümbürtü + etli "şpılt" + ince kemiksi tık +
  insan-dışı alt sürüklenme kuyruğu (hafif oda yankısı). Korkutucu ama gürültülü değil.

---

## Sinematik yakalama (doğrudan öldürme yok)
Yakalanınca anında "YAKALANDIN" yerine sahnelenmiş bir yakalama:
1. **0 sn:** Kontroller kilitlenir, canavar oyuncunun tam önüne (1.25 m) gelip yüzünü ona döner,
   kollarını kaldırmaya başlar; oyuncunun kamerası tabandan yukarı kalkar (ayağın yerden kesilir gibi)
   ve canavarın **yüzüne kilitlenir** (`_camera.look_at`). Yakın nefes sesi çalar.
2. **0 → 1.5 sn:** Kamera yüz hizasına yükselir, kollar yukarı kalkar, titreme artar.
3. **1.75 sn:** Canavar **BAĞIRIR** (çığlık + jumpscare yüz overlay + flaş + maksimum sarsıntı).
4. **2.65 sn:** "YAKALANDIN — Seni havaya kaldırdı. Yüzü çok yakındı." mesajı.

Uygulama: `PremiumFpsPlayer.start_grab/update_grab_target/_update_grab` (lift + yüze bakış),
`ShadowStalker.begin_grab/_animate_grab` (kol kaldırma, oyuncuya dönme),
`PremiumGameRoot._update_grab_cinematic` (zamanlama), `AudioDirector.play_grab_breath`.

---

## Hata düzeltme: canavar zeminden düşüyordu (görünmüyor, sesi geliyor)
Chunk sistemi çarpışmayı **oyuncuya** uzaklığa göre kapatıyordu; ama canavar genelde oyuncudan
uzakta dolaştığı için altındaki chunk'ın zemin çarpışması kapanıyor → canavar boşluğa düşüp gözden
kayboluyor (3D sesi konumundan gelmeye devam ettiği için "ses var, canavar yok"). Düzeltme:
ChunkStreamer artık **yalnızca görünürlüğü** kültür eder; çarpışma tüm chunk'larda her zaman açık
(gizli chunk'ın CollisionShape3D'leri yine çarpışır, GPU kazancı korunur, dinamik gövde sadece
oyuncu+canavar olduğu için fizik maliyeti ihmal edilebilir).

---

## Canavar chunk çarpışmasına entegre edildi (çarpışma artık her zaman açık değil)
Önceki düzeltme tüm chunk çarpışmalarını sürekli açık tutuyordu. Şimdi daha performanslı çözüm:
ChunkStreamer'a canavar referansı (`set_entity`) eklendi. Çarpışma artık **oyuncuya VEYA canavara
yakın** chunk'larda açık; geri kalan chunk'lar fizik dışı kalır. Görünürlük yine sadece oyuncuya
göre kültür edilir. Canavarın çarpışma yarıçapı ~1.6 chunk (≈51 m) → 0.2 sn'lik güncelleme
aralığında bile canavar her zaman sağlam zemine basar (düşmez), uzak chunk'lar fizikten çıkar.

---

## Kaliteli duvar texture seti: wall_yellow_dirty
Kullanıcının verdiği 4 haritalı kaliteli set entegre edildi (1024'e indirildi, mobil VRAM için):
- `wall_yellow_dirty_albedo.png` → Albedo (sarı kirli Backrooms duvar kâğıdı)
- `wall_yellow_dirty_normal.png` → Normal (kabartı)
- `wall_yellow_dirty_roughness.png` → Roughness (parlaklık/matlık)
- `wall_yellow_dirty_height.png` → Height (parallax/displacement için hazır; mobil performansı
  için varsayılan olarak BAĞLANMADI — parallax olarak BAĞLANDI (heightmap_enabled, scale 4.0)
Duvar materyali artık albedo + normal + roughness dokularını dünya-uzayı triplanar ile kullanıyor
(`_make_pbr_material(..., use_normal=true, use_roughness=true)`). Eski prosedürel `wallpaper_*`
dokuları kaldırıldı. `_make_pbr_material`'a opsiyonel `use_roughness` parametresi eklendi (diğer
yüzeyler skaler roughness'ta kaldı → hafif).

## Height bağlandı
Kullanıcı talebiyle 4. harita da bağlandı: `wall_yellow_dirty_height.png` artık duvar materyalinde
parallax/derinlik haritası olarak aktif (`heightmap_enabled=true`, `heightmap_texture`,
`heightmap_scale=4.0`, deep_parallax kapalı → mobilde hafif). `_make_pbr_material`'a opsiyonel
`use_height` parametresi eklendi. Böylece duvar 4 haritayı da kullanıyor: albedo + normal + roughness + height.

## Performans + duvar ayarı (FPS 27 geri bildirimi)
- **Roughness ve height KAPATILDI:** Duvar artık sadece albedo + normal (mat, skaler roughness 0.96).
  Fenerde gereksiz parlama gitti; triplanar doku örneklemesi duvarda ~12 → ~6'ya indi (büyük GPU kazancı).
  Roughness/height PNG'leri projede duruyor ama yüklenmiyor (VRAM'e binmez).
- **Duvar tekrarı azaltıldı:** uv ölçeği 0.5 → 0.22 (doku ~2 m yerine ~4.5 m'de bir tekrarlıyor → desen
  büyüdü, tekrar hissi azaldı).
- **Chunk görüş mesafesi** 2.3 → 2.0 chunk yarıçapı (daha az chunk çizilir → ek performans).

## Kaliteli halı (zemin) texture seti: carpet_old_dirty
Kullanıcının verdiği halı seti (1024'e indirildi):
- `carpet_old_dirty_albedo.png` → Albedo (sarı/kahve eski kirli halı)
- `carpet_old_dirty_normal.png` → Normal
- `carpet_old_dirty_roughness.png` → projede mevcut, ıslak alanlar için ayrılmış (şimdilik BAĞLANMADI)
- `carpet_old_dirty_height.png` → projede mevcut, KULLANILMIYOR
Talimat gereği (kuru halı): zemin yalnızca **albedo + normal** (mat, skaler roughness 0.95);
roughness yalnızca ıslak alanlarda kullanılacak, height hiç kullanılmıyor. uv ölçeği 0.55 → 0.4
(daha az tekrar). Eski prosedürel `carpet_albedo.png` kaldırıldı.

## Köklü performans + görünüm düzeltmesi (10 FPS)
Asıl darboğaz: tüm yüzeylerde **triplanar** (her dokuyu 3× örnekliyordu) + glow + fener gölgesi.
Düşük uv ölçeği de dokuları bulanıklaştırıyordu ("çözünürlük düştü").
- **Triplanar TÜM materyallerde KAPATILDI** → her yüzeyde doku örneği 3× azaldı (en büyük GPU kazancı).
  Normal haritalar korundu (artık ucuz). uv tiling netleştirildi → dokular keskin görünür
  (duvar 1.6×1.22, halı 2.0, tavan 1.5).
- **Glow/bloom KAPATILDI** (mobilde çok-geçişli, pahalı + gereksiz parlama).
- **Fener gölgesi KAPATILDI** (her kare spot gölge render'ı mobilde ağır).
- **MSAA KAPATILDI** (runtime + project.godot) → bant genişliği kazancı.
NOT: Telefonda editör İÇİNDE oynamak (embedded) gerçek performansı yansıtmaz; editör + oyun
birlikte çalışır. Gerçek FPS için APK export alıp test etmek gerekir (genelde 2-3 kat daha hızlı).
