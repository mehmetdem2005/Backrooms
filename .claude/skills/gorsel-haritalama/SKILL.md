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
3. **FastSAM (segment-everything)** -> duzlestirilmis on yuzde her ic ogeyi
   (pencere, vent, yuva, dugme) maske olarak bulur; kesin sinir kutulari verir.
4. `harita.json` + dogrulama gorselleri yazar.

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
