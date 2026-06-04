---
name: gorsel-haritalama
description: Bir referans gorselinden (kapi, panel, obje, arayuz) 3D/2D modelleme icin GERCEK sekil ve oranlari ML ile cikarir; "goz karari" / "aklimda kaldigi gibi" tahmini ortadan kaldirir. rembg (U^2-Net) ile temiz siluet, perspektif (3/4) duzeltme, FastSAM (segment-everything) ile ic ogeleri (pencere, vent, dugme, yuva) piksel hassasiyetinde olcer; dogrulama gorselleri uretir. Bir gorselden birebir model istendiginde KULLAN.
---

# Gorselden Birebir Haritalama (ML destekli)

Amac: referans gorseli "bakip hatirlayarak" degil, **olcerek** modellemek.

## Pipeline (analiz.py otomatik yapar)
1. **rembg (U^2-Net)** -> arka plani ayirir, grunge/golgeden bagimsiz TEMIZ siluet
   maskesi. (Otsu esiklemesi grunge dokuda kayar; rembg kaymaz.)
2. **Sanal kose + GERCEK EN/BOY + rectify** -> siluetin 6-nokta poligonundan
   on-yuz koselerini bulur. EN/BOY oranini **perspektiften hesaplar**
   (Zhang-He metrik rektifikasyon; --en/--boy verilmezse) -> oran VARSAYILMAZ,
   olculur. Sonra perspektifi dogru oranli ON YUZE duzeltir.
   (Onemli: yanlis oran = "genel bicim tutmuyor"; bu adim onu cozer.)
3. **FastSAM (segment-everything)** -> her ic ogeyi (pencere, vent, yuva) maske
   olarak bulur; kaba sinir kutulari verir.
4. **ALT-PIKSEL kesinlestirme** -> her kutunun 4 kenarini gradyan profili +
   parabolik interpolasyon ile alt-piksel hassasiyetine getirir (SAM maskesi
   blok-blok olsa da kenar konumu tam).
5. **DETAY KATMANI (yeni)** -> her ic oge icin:
   - `alt_ogeler`: ic-ice KABARIK (parlak) / GIRINTILI (koyu) alt-yapilari bulur
     (slot icindeki dikey kulp cubugu, vent oct alt-cerceve, ic cep). CLAHE +
     parlaklik kontrasti + kontur; sekil = dikey_cubuk / yatay_cubuk / cep.
   - `izgara_sayisi`: vent oluk (slat) sayisini satir-parlaklik salinimindan olcer.
   - `civatalar`: CIVATA/RIVET tespiti. HoughCircles + **radyal kontrast
     dogrulamasi** (ic disk ile cevre halka arasi net kontrast + dusuk ic-varyans)
     -> grunge lekelerini eler, sadece gercek vidalar kalir.
6. `harita.json` (sub-piksel ic_ogeler + alt_ogeler + civatalar) + INCE etiketli
   grid + her oge icin otomatik ZOOM-GRID dogrulama gorselleri yazar.

## Kullanim
```
# YOLO/matplotlib yazma dizinleri (gerekli):
export YOLO_CONFIG_DIR=/tmp/ultra MPLCONFIGDIR=/tmp/mpl
python3 analiz.py <gorsel> <cikti> --en 1.1 --boy 2.1
python3 analiz.py <gorsel> <cikti> --grid 0.02   # grid minor araligi (vars. 0.01)
```
Uretilenler: `harita.json`, `mask.png`, `overlay.png` (orijinal+siluet+koseler),
`rectified_temiz.png`, `rectified_grid.png` (INCE etiketli: minor=grid_adim,
major=5x + eksen etiketleri), `ogeler.png` (oge+alt_oge+civata cizimli),
`zoom/oge_*.png` (her ic oge icin yakin GLOBAL-koordinatli ince grid).

## Detayli okuma (detay ATLAMA)
ML kutulari kabasını verir; INCE detay (vida konumu, slat sayisi, ic cubuk
sinirlari) **zoom/oge_*.png** uzerinden GLOBAL nx,ny grid'iyle gozle birebir
okunur. Grunge'da Hough vidalari kacirabilir -> zoom-grid otorite.

## GENEL OTOMATIK INSA — insa.py (objeye-ozel sabit YOK)
`harita.json` + `outline.json`'u OKUYUP modeli kendisi kurar; her referans
icin calisir, elle olcu girmeye/objeye-ozel script yazmaya gerek YOK:
```
blender -b -P insa.py -- <analiz_cikti_dizini> [--boy 2.05] [--out models]
```
Tur-surumlu (type-driven) insa, tamamen haritadan:
- siluet `outline` -> cok-kademeli cerceve (pervaz -> oluk kanali -> panel)
- panel (leaf) -> acikligi doldurur
- her `ic_oge` etiket/oran/`alt_ogeler`'e gore otomatik secilir:
  - `dikey_pencere`/uzun-dar -> oct CIFT cerceve girinti + cam + cevre PERCIN
  - `vent`/`izgara_sayisi>=2` -> oct sig girinti + N yatay izgara
  - `kabarik dikey_cubuk` alt-ogesi olan -> DERIN cep + KAPSUL pull-bar (kapi kolu)
  - buyuk + icinde baska oge olan -> KABARIK plaka (cocuklar uzerine girinti)
  - diger -> girintili cep
- `civatalar`/global -> kubbeli silindir (konum/yaricap haritadan)
- derinlikler EN/BOY olcegine ORANLI (her boyuta uyar); kenarlar temizle()+
  genel_pah() ile temiz. Cikti: `<out>/model_cerceve.glb`, `model_govde.glb`,
  `/tmp/insa_preview.png`, `/tmp/insa_front.png` (dogrula.py icin ortho on).

### Uctan-uca akis (yeni obje icin tek komut zinciri)
```
export YOLO_CONFIG_DIR=/tmp/ultra MPLCONFIGDIR=/tmp/mpl HF_HOME=/tmp/hf
python3 analiz.py <gorsel> <cikti>                 # detayli harita + DERINLIK (Depth Anything V2)
blender -b -P insa.py -- <cikti> --boy 2.05 --poly 6000   # low-poly mobil model
python3 dogrula.py <cikti>/rectified_temiz.png /tmp/insa_front.png fark.png
# /tmp/insa_side.png = yan-profil (derinlik) dogrulamasi
```
Detay eksikse: once analiz.py'nin detay tespitini iyilestir (genel), gerekiyorsa
zoom-grid'den okunan degeri harita.json'a el ile ekle -> insa.py onu kullanir.
Tek bir objeye-ozel modelleme scripti yazma; iyilestirmeyi PIPELINE'a yap.

## Ornek (referans): tools/kapi_uretici/kapi_olustur.py
Bu sci-fi kapi icin elle-ayarlı somut ornek (insa.py'nin urettigi yapilarin
nasil gorunmesi gerektigini gosterir). Yeni objelerde insa.py'yi kullan.

Otomatik koseler kayarsa elle ver:
```
python3 analiz.py <gorsel> <cikti> --koseler "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"
```

## Adimlar
1. Calistir. `overlay.png` ve `ogeler.png`'i **Read** ile gor.
2. Kutular oturmadiysa: koseleri manuel ver, veya `rectified_grid.png` uzerinden
   ogeleri gozle oku; okudugun kutulari cv2.rectangle ile cizip dogrula.
3. `harita.json`'daki `ic_ogeler` (x,y,x1,y1 = on-yuz [0..1]) degerlerini
   modelleme scriptine ver. Donusum (kapi ornegi, en=1.10 boy=2.10):
   ```
   model_x = -0.55 + nx*1.10        # sol->sag
   model_z =  2.10 - ny*2.10        # ust(ny=0)->z=2.10
   ```
   `siluet_rectified_normalize` ust pah (chamfer) olcumu icin kullanilir.

4. **KAPATMA DONGUSU (en hassas adim) — dogrula.py:** modeli olusturduktan
   sonra ORTOGRAFIK ON render'ini al (objenin on yuzune dik bakan ortho kamera,
   arka plan saydam, kadraj on yuzu tam dolduracak). Sonra:
   ```
   python3 dogrula.py <cikti>/rectified_temiz.png <model_front.png> fark.png --grid 0.05
   ```
   KIRMIZI = modelin kenarlari, YESIL = referans kenarlari (ust uste; hizalama
   net gorunur). INCE etiketli grid ile sapan olcuyu okursun. Cikti sayisal:
   `model->ref ortusme`, `ref->model kapsama`, ve ust/orta/alt bant icin
   `eksik` (referansta olup modelde olmayan = ATLANAN detay). fark.png'i Read et,
   sapan/eksik olcuyu duzelt, yeniden uret/dogrula. Not: referansin grunge
   dokusu yuzunden ham `kapsama` dusuk cikar; ONEMLI olan model kenarinin
   YAPISAL referans ozelliklerine oturmasi + `eksik` bandinin dusuk olmasi.

## DERINLIK ALGISI (profesyonel + ucretsiz; objeden bagimsiz)
Derinlik TAHMIN edilmez; iki bagimsiz kaynaktan OLCULUR (ML model + geometri):

1. **Monoküler derinlik modeli — Depth Anything V2** (Apache-2.0, ucretsiz, SOTA):
   `derinlik_haritasi()` orijinal goruntude YOGUN relative derinlik uretir;
   M ile rectified on yuze warp edilir, **planar egim (3/4) cikarilir** (detrend)
   -> sadece YEREL kabarti kalir -> `depth_rect.png`. Her oge `derinlik_isaret_depth`
   ile ic-vs-cevre medyanindan **girinti/kabarik + goreli derinlik** alir.
   KRITIK avantaj: parlaklik degil SAHNE DERINLIGI okunur -> **grunge/pas lekesi
   derinlige karismaz** (sezgisel yontemin tam zayifligi cozulur).
   `GORSEL_DEPTH=0` ile kapatilir; model yoksa golge sezgiseline (yedek) duser.
2. **Geometrik metrik capa** — `olc_kalinlik()`: 3/4 gorunumde gorunen YAN YUZ
   seridinden GERCEK kalinlik = `yan_serit_px / (px_per_m * sin|yaw|)` (sag/sol +
   alt/ust medyani). Model goreli derinligi bu metrik kalinlikla olceklenir.
   Kamera DUZ bakiyorsa null -> insa.py yedek varsayima duser.

harita.json: `derinlik{kalinlik_m, kalinlik_orani, kabartma_kaynak}`; her
`ic_oge`/`alt_oge` -> `kabartma` (girinti/kabarik/duz) + `derinlik_m`.
- insa.py KARARLI model okumasini kullanir (derinlik_orani>=0.18); model "duz"/
  zayif derse (kucuk/sig detay: vent, plaka kabarikligi) YAPISAL tip-yedegine duser
  (plaka cocuklu->kabarik, vent->izgaradan recess). Boylece buyuk recess'ler (pencere,
  kol) modelden metrik, ince detay yapidan gelir.

## LOW-POLY / MOBIL CIKTI (insa.py)
- Cikti mobil-hazir: dusuk segment (cylinder vert=10, rounded_rect seg=5,
  pah segment=1) + FLAT shade (ucuz, temiz siluet).
- `--poly <butce>` (vars. 6000): join sonrasi tri butceyi asarsa Decimate
  (collapse) ile indirir; tri sayisini RAPORLAR. Cerceve butcesi = yari.
- Tipik sonuc: tum kapi ~2-3k ucgen (mobil icin ideal). `/tmp/insa_side.png`
  yan-profil render'i derinligi gozle dogrular.

## Notlar
- `--en/--boy` sadece warp hedef **orani** icin; mutlak olcek modelde belirlenir.
- FastSAM etiketleri (vent/yuva/pencere) konum sezgiseldir; asil olan koordinatlar.
- Yedek: rembg yoksa Otsu, FastSAM yoksa OpenCV (kenar-koruyan filtre) devreye girer.

## Gereksinimler
```
pip install --break-system-packages opencv-python-headless numpy \
    onnxruntime rembg ultralytics torch torchvision \
    transformers timm            # DERINLIK: Depth Anything V2 (ucretsiz)
```
Modeller ilk kullanimda iner: rembg `u2net` (~170MB), `FastSAM-s.pt` (~23MB),
`Depth-Anything-V2-Small-hf` (~50-100MB, CPU'da ~1-3sn cikarim). Hepsi ucretsiz.
