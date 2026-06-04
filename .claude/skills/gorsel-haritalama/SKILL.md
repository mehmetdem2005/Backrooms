---
name: gorsel-haritalama
description: Bir referans gorselinden (kapi, panel, obje, arayuz) 3D/2D modelleme icin GERCEK sekil ve oranlari cikarir; "goz karari" / "aklimda kaldigi gibi" tahmini ortadan kaldirir. Perspektifli (3/4) fotograflari on yuze duzlestirir (rectify), siluet konturunu ve ic ogeleri (pencere, panel, dugme, yuva) olcer, dogrulama icin overlay/izgara uretir. Bir gorselden birebir model istendiginde KULLAN.
---

# Gorselden Birebir Haritalama

Amac: referans gorseli "bakip hatirlayarak" degil, **olcerek** modellemek.
Cikan normalize koordinatlar dogrudan modelleme scriptine beslenir.

## Akis

1. **Calistir** (perspektifli gorsellerde once otomatik dene):
   ```
   python3 analiz.py <gorsel> <cikti_dizini> --en <gercek_en> --boy <gercek_boy>
   ```
   Uretilenler: `harita.json`, `overlay.png` (orijinal+siluet+koseler),
   `rectified_temiz.png` (perspektifi duzeltilmis on yuz),
   `rectified_grid.png` (0.1 izgarali), `rectified.png` (tespitli).

2. **overlay.png**'i Read ile gor. 4 kose (kirmizi) objenin on yuzunu dogru
   sariyor mu? Grunge/golge yuzunden otomatik kose kayarsa, koseleri **gozle**
   gorselden oku ve manuel ver (en guvenilir yontem):
   ```
   python3 analiz.py <gorsel> <cikti> --en 1.1 --boy 2.1 \
       --koseler "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"
   ```
   Koseleri okumak icin gorseli piksel izgarasiyla bir gecici dosyaya cizip
   (cv2.line) Read et.

3. **rectified_grid.png / rectified_temiz.png**'i Read ile gor. Artik
   perspektifsiz, duz on goruntu var. Her ogenin (pencere, panel, dugme)
   sol/sag/ust/alt kenarini 0..1 izgaradan oku. Gerekirse bolgeleri kirp+buyut.

4. **Dogrula (kritik adim):** okudugun dikdortgenleri rectified goruntu uzerine
   cv2.rectangle ile ciz, Read et, hizalanana kadar duzelt. Tahmini burada kapatirsin.

5. **Donustur:** normalize on-yuz (nx,ny) -> model koordinati:
   ```
   model_x = x_min + nx * (x_max - x_min)        # sol->sag
   model_z = z_max - ny * (z_max - z_min)         # ust(ny=0)->z_max
   ```
   Olculen degerleri modelleme scriptinde parametre olarak kullan.

## Notlar
- `--en/--boy` sadece **oran** icin onemli (warp hedef en/boy). Bilinmiyorsa
  gorseldeki obje oranini tahmin et; mutlak olcek modelde ayri belirlenir.
- 3/4 perspektif: ust pahli (chamfer) koseler warp sonrasi kose ucgenleri olarak
  gorunur; bu sayede pah boyutu da olculebilir.
- Bu beceri sadece olcum/haritalama icindir; modeli olusturmaz. Cikan sayilari
  ilgili modelleme scriptine (or. tools/kapi_uretici/kapi_olustur.py) ver.

## Gereksinimler
`opencv-python-headless`, `numpy` (yoksa: `pip install --break-system-packages opencv-python-headless`).
