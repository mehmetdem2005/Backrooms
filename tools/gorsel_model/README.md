# Görselden Model (genel, deterministik)

Herhangi bir referans görselinden 3B model üretir. **Kapıya özel değildir** —
hangi resmi verirsen onun analiz çıktısından kurar. Hiçbir öğe elle girilmez,
hiçbir oran/üçgen uydurulmaz; her şey görselden ölçülür → deterministik.

## Boru hattı

```
# 1) Analiz: rembg siluet + otomatik perspektif/oran + dış hat + foto
export YOLO_CONFIG_DIR=/tmp/ultra MPLCONFIGDIR=/tmp/mpl
python3 .claude/skills/gorsel-haritalama/analiz.py <resim> <dir>

# 2) İnşa: gerçek dış hat -> katı gövde + gerçek foto doku
blender -b -P tools/gorsel_model/insa.py -- <dir> <cikti.glb> [--boy 2.0] [--kalinlik 0.12]
```

Üretilen `cikti.glb`:
- **Dış hat**: rembg maskesinden çıkarılan gerçek silüet (perspektifi düzeltilmiş)
- **Oran**: 4 köşeden perspektif geometrisiyle hesaplanan gerçek en/boy (varsayım yok)
- **Doku**: düzleştirilmiş gerçek fotoğraf (albedo) → önden bakışta birebir aynı
- **Kalınlık**: `--kalinlik` ile katı gövde

## Tek serbest parametre
Tek bir fotoğraftan **mutlak ölçek** çıkmaz; sadece `--boy` (yükseklik, m)
verilir, genişlik = boy × (ölçülen oran). Diğer her şey görselden gelir.

## Sınır
Tek görsel fronto-paralel olmayan yüzey **derinliğini** içermez (pencere/panel
kabartısı dokudadır, geometride değil) — uydurma kabartı eklenmez. Gerçek
geometrik derinlik için nesnenin birden çok açıdan fotoğrafı (fotogrametri)
gerekir.
