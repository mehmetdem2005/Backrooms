# -*- coding: utf-8 -*-
"""
Monoküler DERINLIK (Depth Anything V2) — gerçek kabartı için.
Derinlik BENIM varsayimimdan degil, goruntuyu analiz eden modelden gelir.

Girdi : <dir> (analiz.py ciktisi: rectified_temiz.png + mask_rectified.png)
Cikti : <dir>/depth16.png   (16-bit, 1.0 = en ON/kabarik, 0 = en arka/cukur)
        <dir>/depth_view.png (gri onizleme)

Kullanim: python3 tools/gorsel_model/derinlik.py <dir> [model]
"""
import sys, os
import numpy as np
import cv2

DIR = sys.argv[1]
# Super gelismisten basla, olmazsa dus (genel: herhangi bir gorsel icin):
if len(sys.argv) > 2:
    ADAYLAR = [sys.argv[2]]
else:
    ADAYLAR = [
        "apple/DepthPro-hf",                          # SOTA: keskin kenar, metrik
        "depth-anything/Depth-Anything-V2-Large-hf",  # hiz/dogruluk dengesi
        "depth-anything/Depth-Anything-V2-Small-hf",  # en hizli yedek
    ]

alb = cv2.imread(os.path.join(DIR, "rectified_temiz.png"))
mask = cv2.imread(os.path.join(DIR, "mask_rectified.png"), 0)
H, W = alb.shape[:2]

# --- Monokuler derinlik (CPU) — en gelismis kullanilabilir model ---
from transformers import pipeline
from PIL import Image
rgb = Image.fromarray(cv2.cvtColor(alb, cv2.COLOR_BGR2RGB))
depth = None
KULLANILAN = None
for mdl in ADAYLAR:
    try:
        pipe = pipeline("depth-estimation", model=mdl, device="cpu")
        out = pipe(rgb)
        depth = np.asarray(out["predicted_depth"] if "predicted_depth" in out
                           else out["depth"], dtype=np.float32)
        KULLANILAN = mdl
        break
    except Exception as e:
        print("  (atlandi: %s -> %s)" % (mdl, type(e).__name__))
if depth is None:
    raise RuntimeError("hicbir derinlik modeli yuklenemedi")
if depth.shape != (H, W):
    depth = cv2.resize(depth, (W, H), interpolation=cv2.INTER_CUBIC)
# DepthPro metrik mesafe verir (buyuk=UZAK); diger modeller buyuk=YAKIN.
# Tutarli olsun: buyuk = YAKIN/kabarik. DepthPro ise tersine cevir.
if "depthpro" in KULLANILAN.lower():
    depth = -depth

# Depth Anything: buyuk deger = YAKIN (kameraya yakin = kabarik/on).
m = mask > 127
if m.sum() < 100:
    m = np.ones_like(mask, bool)

# DETREND: global egimi (perspektif kalintisi) cikar -> kapi DUZ, sadece yerel kabarti
ys, xs = np.where(m)
z = depth[m].astype(np.float64)
A = np.c_[xs, ys, np.ones_like(xs)]
coef, *_ = np.linalg.lstsq(A, z, rcond=None)
Y, Xg = np.mgrid[0:H, 0:W]
plane = coef[0]*Xg + coef[1]*Y + coef[2]
resid = depth - plane                               # yerel kabarti (egimsiz)

lo, hi = np.percentile(resid[m], 2), np.percentile(resid[m], 98)
d = np.clip((resid - lo) / max(hi - lo, 1e-6), 0, 1)   # 0..1, 1=kabarik
d[~m] = 0.0                                          # silüet disi = arka

# hafif kenar-koruyan yumusatma (gurultu azalt, yapi korunur)
d = cv2.bilateralFilter(d.astype(np.float32), 7, 0.08, 5)
d[~m] = 0.0

cv2.imwrite(os.path.join(DIR, "depth16.png"), (d * 65535).astype(np.uint16))
cv2.imwrite(os.path.join(DIR, "depth_view.png"), (d * 255).astype(np.uint8))
print("yazildi: depth16.png (%dx%d) model=%s" % (W, H, KULLANILAN))
print("derinlik araligi (silüet ici): min=%.3f max=%.3f" % (d[m].min(), d[m].max()))
