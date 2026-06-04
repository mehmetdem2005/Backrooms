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
okunur. Grunge'da Hough vidalari kacirabilir -> zoom-grid otorite. Modelleme
scriptine bu okunan degerleri gir; hicbir alt-yapiyi atlamadan parca parca kur.

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

## Derinlik / cerceve profili (3B akil yurutme)
- `harita.json -> kamera`: focal, yaw, pitch, px_per_m. 3/4 acida yan/ust yuz
  gorunur; derinlik = yan-serit_px / px_per_m / sin(yaw).
- Cerceve KESITI (rim/oluk/bevel) icin: rectified on yuzde sol cerceve boyunca
  yatay parlaklik+gradyan profili al; duz pervaz / basamak / kanal / panel
  kenarlarini gradyan zirvelerinden oku, profili ona gore modelle.

## Notlar
- `--en/--boy` sadece warp hedef **orani** icin; mutlak olcek modelde belirlenir.
- FastSAM etiketleri (vent/yuva/pencere) konum sezgiseldir; asil olan koordinatlar.
- Yedek: rembg yoksa Otsu, FastSAM yoksa OpenCV (kenar-koruyan filtre) devreye girer.

## Gereksinimler
```
pip install --break-system-packages opencv-python-headless numpy \
    onnxruntime rembg ultralytics torch torchvision
```
Modeller ilk kullanimda iner: rembg `u2net` (~170MB), `FastSAM-s.pt` (~23MB).
