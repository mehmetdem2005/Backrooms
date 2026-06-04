---
name: gorsel-haritalama
description: Bir referans gorselinden (kapi, panel, obje, arayuz) 3D/2D modelleme icin GERCEK sekil ve oranlari ML ile cikarir; "goz karari" / "aklimda kaldigi gibi" tahmini ortadan kaldirir. rembg (U^2-Net) ile temiz siluet, perspektif (3/4) duzeltme, FastSAM (segment-everything) ile ic ogeleri (pencere, vent, dugme, yuva) piksel hassasiyetinde olcer; dogrulama gorselleri uretir. Bir gorselden birebir model istendiginde KULLAN.
---

# Gorselden Birebir Haritalama (ML destekli)

Amac: referans gorseli "bakip hatirlayarak" degil, **olcerek** modellemek.

## Pipeline (analiz.py otomatik yapar)
1. **rembg (U^2-Net)** -> arka plani ayirir, grunge/golgeden bagimsiz TEMIZ siluet
   maskesi. (Otsu esiklemesi grunge dokuda kayar; rembg kaymaz.)
2. **Sanal kose + rectify** -> siluetin 6-nokta poligonundan yan/ust kenarlari
   uzatip on-yuz dikdortgeninin koselerini bulur, perspektifi ON YUZE duzeltir.
3. **FastSAM (segment-everything)** -> her ic ogeyi (pencere, vent, yuva) maske
   olarak bulur; kaba sinir kutulari verir.
4. **ALT-PIKSEL kesinlestirme** -> her kutunun 4 kenarini gradyan profili +
   parabolik interpolasyon ile alt-piksel hassasiyetine getirir (SAM maskesi
   blok-blok olsa da kenar konumu tam). Vent icin yatay izgara sayisini olcer.
5. `harita.json` (sub-piksel ic_ogeler) + dogrulama gorselleri yazar.

## Kullanim
```
# YOLO/matplotlib yazma dizinleri (gerekli):
export YOLO_CONFIG_DIR=/tmp/ultra MPLCONFIGDIR=/tmp/mpl
python3 analiz.py <gorsel> <cikti> --en 1.1 --boy 2.1
```
Uretilenler: `harita.json`, `mask.png`, `overlay.png` (orijinal+siluet+koseler),
`rectified_temiz.png`, `rectified_grid.png`, `ogeler.png` (tespitli on yuz).

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
   python3 dogrula.py <cikti>/rectified_temiz.png <model_front.png> fark.png
   ```
   Kirmizi = modelin kenarlari; referans ozellikleri uzerine OTURMAYAN yerler
   sapmadir. fark.png'i Read et, sapan olcuyu duzelt, yeniden uret/dogrula.
   Boylece goz karari kalmaz; model referansa piksel piksel hizalanir.

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
