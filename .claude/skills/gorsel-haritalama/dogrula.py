# -*- coding: utf-8 -*-
"""
Model <-> referans birebir dogrulama (kapatma dongusu, DETAYLI surum).

Modelin ORTOGRAFIK ON render'ini, referansin perspektifi-duzeltilmis on yuzu
(rectified_temiz.png) uzerine bindirip kenar farkini gosterir. Kirmizi cizgiler
modelin kenarlari; referans ozellikleri uzerine oturmazsa oradan duzeltirsin.

Yeni:
  - INCE etiketli grid (vars. 0.05 araligi; --grid ile degistir)
  - referans kenarlari YESIL + model kenarlari KIRMIZI ust uste (hizalama net)
  - sayisal: model->referans ve referans->model ortusme + yon-bazli rapor

Kullanim:
  python3 dogrula.py <rectified_temiz.png> <model_front.png> <cikti.png> [--grid 0.05]

Model render'i: kapinin on yuzune dik bakan ortografik kamera, arka plan
saydam (film_transparent), kadraj objenin on yuzunu tam dolduracak sekilde.
"""
import cv2
import numpy as np
import argparse


def _grid(o, ad):
    H, W = o.shape[:2]
    n = int(round(1.0/ad))
    for i in range(n+1):
        v = i*ad
        px = int(round(v*(W-1))); py = int(round(v*(H-1)))
        maj = (round(v/ad) % 5 == 0)
        col = (0, 150, 255) if maj else (50, 75, 105)
        cv2.line(o, (px, 0), (px, H), col, 1)
        cv2.line(o, (0, py), (W, py), col, 1)
        if maj:
            cv2.putText(o, "%.2f" % v, (min(px+1, W-26), 11),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1, cv2.LINE_AA)
            cv2.putText(o, "%.2f" % v, (1, max(py-2, 9)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1, cv2.LINE_AA)
    return o


def dogrula(ref_path, model_path, cikti, grid_ad=0.05, buyut=2):
    ref = cv2.imread(ref_path)
    mdl = cv2.imread(model_path, cv2.IMREAD_UNCHANGED)
    if ref is None or mdl is None:
        raise RuntimeError("girdi okunamadi")
    H, W = ref.shape[:2]
    mdl = cv2.resize(mdl, (W, H))
    mg = cv2.cvtColor(mdl[:, :, :3], cv2.COLOR_BGR2GRAY)
    me = cv2.Canny(mg, 40, 120)
    re = cv2.Canny(cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY), 40, 120)
    med = cv2.dilate(me, np.ones((2, 2), np.uint8), 1)
    red = cv2.dilate(re, np.ones((2, 2), np.uint8), 1)

    ov = ref.copy()
    ov[red > 0] = (0, 220, 0)        # referans kenarlari = YESIL
    ov[med > 0] = (0, 0, 255)        # model kenarlari    = KIRMIZI
    if buyut != 1:
        ov = cv2.resize(ov, (W*buyut, H*buyut), interpolation=cv2.INTER_NEAREST)
    ov = _grid(ov, grid_ad)
    cv2.imwrite(cikti, ov)

    # sayisal: cift yonlu ortusme + bant-bazli (ust/orta/alt, sol/sag)
    me3 = cv2.dilate(me, np.ones((3, 3), np.uint8), 1)
    re3 = cv2.dilate(re, np.ones((3, 3), np.uint8), 1)
    m2r = (me3 & re3).sum() / max(me3.sum(), 1)     # model kenari referansa
    r2m = (me3 & re3).sum() / max(re3.sum(), 1)     # referans kenari modelde
    print("yazildi:", cikti)
    print("  model->ref ortusme: %.1f%%  |  ref->model kapsama: %.1f%%"
          % (100*m2r, 100*r2m))
    # eksik bolge: referans kenari olup model olmayan (kacirilan detay)
    eksik = (re3 > 0) & (me3 == 0)
    for ad, (y0, y1) in [("ust", (0, H//3)), ("orta", (H//3, 2*H//3)),
                         ("alt", (2*H//3, H))]:
        e = eksik[y0:y1].sum() / max(re3[y0:y1].sum(), 1)
        print("  eksik(%s bant): %.1f%% referans kenari modelde yok" % (ad, 100*e))
    return m2r, r2m


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("ref"); ap.add_argument("model"); ap.add_argument("cikti")
    ap.add_argument("--grid", type=float, default=0.05)
    a = ap.parse_args()
    dogrula(a.ref, a.model, a.cikti, a.grid)
