# -*- coding: utf-8 -*-
"""
Model <-> referans birebir dogrulama (kapatma dongusu).

Modelin ORTOGRAFIK ON render'ini, referansin perspektifi-duzeltilmis on yuzu
(rectified_temiz.png) uzerine bindirip kenar farkini gosterir. Kirmizi cizgiler
modelin kenarlari; referans ozellikleri uzerine oturmazsa oradan duzeltirsin.

Kullanim:
  python3 dogrula.py <rectified_temiz.png> <model_front.png> <cikti.png>

Model render'i: kapinin on yuzune dik bakan ortografik kamera, arka plan
saydam (film_transparent), kadraj objenin on yuzunu tam dolduracak sekilde.
"""
import cv2
import numpy as np
import sys


def dogrula(ref_path, model_path, cikti, buyut=2):
    ref = cv2.imread(ref_path)
    mdl = cv2.imread(model_path, cv2.IMREAD_UNCHANGED)
    if ref is None or mdl is None:
        raise RuntimeError("girdi okunamadi")
    H, W = ref.shape[:2]
    mdl = cv2.resize(mdl, (W, H))
    mg = cv2.cvtColor(mdl[:, :, :3], cv2.COLOR_BGR2GRAY)
    ed = cv2.dilate(cv2.Canny(mg, 40, 120), np.ones((2, 2), np.uint8), 1)
    ov = ref.copy()
    ov[ed > 0] = (0, 0, 255)
    if buyut != 1:
        ov = cv2.resize(ov, (W*buyut, H*buyut), interpolation=cv2.INTER_NEAREST)
        Hb, Wb = ov.shape[:2]
        for i in range(1, 10):
            cv2.line(ov, (int(i/10*Wb), 0), (int(i/10*Wb), Hb), (0, 140, 255), 1)
            cv2.line(ov, (0, int(i/10*Hb)), (Wb, int(i/10*Hb)), (0, 140, 255), 1)
    cv2.imwrite(cikti, ov)
    # sayisal fark: kenar ortusme orani
    rg = cv2.dilate(cv2.Canny(cv2.cvtColor(ref, cv2.COLOR_BGR2GRAY), 40, 120),
                    np.ones((3, 3), np.uint8), 1)
    ed0 = cv2.dilate(cv2.Canny(mg, 40, 120), np.ones((3, 3), np.uint8), 1)
    ortusme = (ed0 & rg).sum() / max(ed0.sum(), 1)
    print("yazildi:", cikti, "| model-kenari referansa ortusme: %.1f%%" % (100*ortusme))
    return ortusme


if __name__ == "__main__":
    dogrula(sys.argv[1], sys.argv[2], sys.argv[3])
