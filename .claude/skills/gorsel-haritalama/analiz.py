# -*- coding: utf-8 -*-
"""
Gorsel -> hassas sekil/oran haritalama araci (ML destekli).

Pipeline:
  1) rembg (U^2-Net) ile arka plani ayir -> TEMIZ siluet maskesi
     (grunge/golgeye dayanikli; Otsu'ya gore cok daha guvenilir)
  2) Siluetten 6-nokta poligon -> kenar cizgilerini uzatip SANAL on-yuz
     koselerini bul -> perspektifi ON YUZE duzelt (rectify)
  3) FastSAM (segment-everything) ile duzlestirilmis on yuzde ic ogeleri
     (pencere, vent, dugme, yuva) piksel hassasiyetinde segment et
  4) Hepsini [0..1] normalize edip harita.json'a yaz; dogrulama gorselleri uret

Kullanim:
  python3 analiz.py <gorsel> <cikti> [--en 1.1] [--boy 2.1]
  python3 analiz.py <gorsel> <cikti> --koseler "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"

rembg/ultralytics yoksa otomatik Otsu + OpenCV yedegine duser.
"""
import cv2
import numpy as np
import json
import os
import argparse


# --------------------------------------------------------------- maske (rembg)
def mask_rembg(img):
    from rembg import remove, new_session
    sess = new_session("u2net")
    m = remove(img, session=sess, only_mask=True)
    if m.ndim == 3:
        m = m[:, :, 0]
    return (m > 127).astype(np.uint8) * 255


def mask_otsu(img):
    g = cv2.GaussianBlur(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY), (5, 5), 0)
    _, m = cv2.threshold(g, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    kenar = np.concatenate([m[0], m[-1], m[:, 0], m[:, -1]])
    if kenar.mean() > 127:
        m = 255 - m
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k, 3)
    return cv2.morphologyEx(m, cv2.MORPH_OPEN, k, 1)


def en_buyuk_kontur(mask):
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not cnts:
        raise RuntimeError("kontur yok")
    return max(cnts, key=cv2.contourArea)


# ------------------------------------------------ sanal on-yuz koseleri
def _kesisim(p1, p2, p3, p4):
    x1, y1 = p1; x2, y2 = p2; x3, y3 = p3; x4, y4 = p4
    d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if abs(d) < 1e-6:
        return [(x1 + x3) / 2, (y1 + y3) / 2]
    px = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / d
    py = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / d
    return [px, py]


def sanal_koseler(cnt):
    """Pahli (octagonal-ust) silueti on-yuz dikdortgenine indir."""
    peri = cv2.arcLength(cnt, True)
    pts = cv2.approxPolyDP(cnt, 0.015 * peri, True).reshape(-1, 2).astype(float)
    pts = [list(p) for p in pts]
    if len(pts) < 4:
        raise RuntimeError("yetersiz kose")
    ys = sorted(pts, key=lambda p: p[1])
    xs = sorted(pts, key=lambda p: p[0])
    top = sorted(ys[:2], key=lambda p: p[0])        # ust duz kenar uclari
    left = sorted(xs[:2], key=lambda p: p[1])       # sol kenar (ust,alt)
    right = sorted(xs[-2:], key=lambda p: p[1])     # sag kenar (ust,alt)
    TL = _kesisim(left[0], left[1], top[0], top[1])
    TR = _kesisim(right[0], right[1], top[0], top[1])
    BL = left[1]
    BR = right[1]
    return np.array([TL, TR, BR, BL], np.float32)


def rectify(img, kose, en, boy):
    Ht = 1000
    Wt = max(1, int(round(Ht * float(en) / float(boy))))
    hedef = np.array([[0, 0], [Wt - 1, 0], [Wt - 1, Ht - 1], [0, Ht - 1]], np.float32)
    M = cv2.getPerspectiveTransform(kose.astype(np.float32), hedef)
    return cv2.warpPerspective(img, M, (Wt, Ht)), M, (Wt, Ht)


# ------------------------------------------------ ic ogeler (FastSAM)
def ogeler_fastsam(rect_path, Wt, Ht):
    os.environ.setdefault("YOLO_CONFIG_DIR", "/tmp/ultra")
    os.environ.setdefault("MPLCONFIGDIR", "/tmp/mpl")
    from ultralytics import FastSAM
    model = FastSAM("FastSAM-s.pt")
    res = model(rect_path, device="cpu", retina_masks=True,
                imgsz=1024, conf=0.4, iou=0.9, verbose=False)[0]
    out = []
    if res.masks is None:
        return out
    for mk in res.masks.data.cpu().numpy():
        mm = (mk > 0.5).astype(np.uint8)
        a = mm.sum() / float(Wt * Ht)
        ys, xs = np.where(mm)
        if len(xs) == 0:
            continue
        x0, x1 = xs.min() / Wt, xs.max() / Wt
        y0, y1 = ys.min() / Ht, ys.max() / Ht
        w, h = x1 - x0, y1 - y0
        # ic oge filtresi
        if 0.004 < a < 0.12 and w < 0.55 and h < 0.6 \
           and x0 > 0.12 and x1 < 0.92 and y0 > 0.10 and y1 < 0.92:
            out.append([a, x0, y0, x1, y1])
    return out


def ogeler_cv(rect):
    """FastSAM yoksa: kenar-koruyan filtre + kontur yedegi."""
    H, W = rect.shape[:2]
    g = cv2.cvtColor(cv2.bilateralFilter(rect, 9, 75, 75), cv2.COLOR_BGR2GRAY)
    out = []
    koyu = cv2.inRange(g, 0, 95)
    cnts, _ = cv2.findContours(koyu, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        a = cv2.contourArea(c) / float(W * H)
        if not (0.004 < a < 0.12):
            continue
        x, y, w, h = cv2.boundingRect(c)
        x0, y0 = x / W, y / H
        if x0 > 0.12 and (x + w) / W < 0.92 and y0 > 0.10 and (y + h) / H < 0.92:
            out.append([a, x0, y0, (x + w) / W, (y + h) / H])
    return out


def _dedupe(feats):
    feats = sorted(feats, key=lambda f: -f[0])
    sel = []

    def iou(A, B):
        x1 = max(A[1], B[1]); y1 = max(A[2], B[2])
        x2 = min(A[3], B[3]); y2 = min(A[4], B[4])
        inter = max(0, x2 - x1) * max(0, y2 - y1)
        ua = (A[3]-A[1])*(A[4]-A[2]) + (B[3]-B[1])*(B[4]-B[2]) - inter
        return inter / ua if ua else 0
    for f in feats:
        if all(iou(f, s) < 0.4 for s in sel):
            sel.append(f)
    return sel


def _etiket(x0, y0, x1, y1):
    w, h = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if w / max(h, 1e-6) < 0.55 and h > 0.30:
        return "dikey_pencere"
    if cx > 0.55 and h < 0.12:
        return "vent"
    if cx > 0.55 and h >= 0.12:
        return "yuva"
    return "oge"


# --------------------------------------------------------------- ana akis
def analiz(gorsel, cikti, en=1.1, boy=2.1, manuel_kose=None):
    os.makedirs(cikti, exist_ok=True)
    img = cv2.imread(gorsel)
    if img is None:
        raise RuntimeError("gorsel okunamadi: " + gorsel)
    H, W = img.shape[:2]

    try:
        mask = mask_rembg(img); mkaynak = "rembg"
    except Exception as e:
        mask = mask_otsu(img); mkaynak = "otsu(%s)" % type(e).__name__
    cv2.imwrite(os.path.join(cikti, "mask.png"), mask)
    cnt = en_buyuk_kontur(mask)

    if manuel_kose is not None:
        kose = np.array(manuel_kose, np.float32)
    else:
        kose = sanal_koseler(cnt)

    rect, M, (Wt, Ht) = rectify(img, kose, en, boy)
    cv2.imwrite(os.path.join(cikti, "rectified_temiz.png"), rect)

    # siluet noktalarini rectified uzaya tasi (ust pah olcumu icin)
    sil = cv2.approxPolyDP(cnt, 0.015 * cv2.arcLength(cnt, True), True).reshape(-1, 2)
    sil_r = cv2.perspectiveTransform(sil.reshape(-1, 1, 2).astype(np.float32), M).reshape(-1, 2)
    sil_n = [[round(float(x) / Wt, 4), round(float(y) / Ht, 4)] for x, y in sil_r]

    try:
        feats = ogeler_fastsam(os.path.join(cikti, "rectified_temiz.png"), Wt, Ht)
        okaynak = "fastsam"
        if not feats:
            raise RuntimeError("bos")
    except Exception as e:
        feats = ogeler_cv(rect); okaynak = "opencv(%s)" % type(e).__name__
    feats = _dedupe(feats)

    ogeler = []
    for a, x0, y0, x1, y1 in sorted(feats, key=lambda f: f[2]):
        ogeler.append({
            "etiket": _etiket(x0, y0, x1, y1),
            "x": round(x0, 4), "y": round(y0, 4),
            "x1": round(x1, 4), "y1": round(y1, 4),
            "w": round(x1 - x0, 4), "h": round(y1 - y0, 4),
            "alan": round(a, 4),
        })

    harita = {
        "kaynak": os.path.basename(gorsel),
        "gorsel_boyut": [W, H],
        "gercek_en_boy": [en, boy],
        "maske_kaynak": mkaynak,
        "oge_kaynak": okaynak,
        "kose_kaynak": "manuel" if manuel_kose is not None else "rembg_sanal",
        "sanal_koseler_px": kose.tolist(),
        "rectified_boyut": [Wt, Ht],
        "siluet_rectified_normalize": sil_n,
        "ic_ogeler": ogeler,
        "not": "ic_ogeler ve siluet ON YUZE duzlestirilmis [0..1] normalize.",
    }
    with open(os.path.join(cikti, "harita.json"), "w") as f:
        json.dump(harita, f, indent=2, ensure_ascii=False)

    # --- gorseller ---
    ov = img.copy()
    cv2.drawContours(ov, [cnt], -1, (0, 255, 0), 2)
    for p in kose:
        cv2.circle(ov, tuple(np.int32(p)), 9, (0, 0, 255), -1)
    cv2.imwrite(os.path.join(cikti, "overlay.png"), ov)

    rg = rect.copy()
    for i in range(1, 10):
        cv2.line(rg, (int(i/10*Wt), 0), (int(i/10*Wt), Ht), (0, 140, 255), 1)
        cv2.line(rg, (0, int(i/10*Ht)), (Wt, int(i/10*Ht)), (0, 140, 255), 1)
    cv2.imwrite(os.path.join(cikti, "rectified_grid.png"), rg)

    rv = rect.copy()
    renk = {"dikey_pencere": (255, 80, 80), "vent": (80, 200, 255),
            "yuva": (80, 80, 255), "oge": (0, 200, 0)}
    for o in ogeler:
        c = renk.get(o["etiket"], (0, 200, 0))
        cv2.rectangle(rv, (int(o["x"]*Wt), int(o["y"]*Ht)),
                      (int(o["x1"]*Wt), int(o["y1"]*Ht)), c, 2)
        cv2.putText(rv, o["etiket"], (int(o["x"]*Wt), max(0, int(o["y"]*Ht)-5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, c, 1, cv2.LINE_AA)
    cv2.imwrite(os.path.join(cikti, "ogeler.png"), rv)

    print("maske:", mkaynak, "| oge:", okaynak, "| oge sayisi:", len(ogeler))
    for o in ogeler:
        print("  {etiket:14s} x[{x:.3f},{x1:.3f}] y[{y:.3f},{y1:.3f}]".format(**o))
    print("cikti:", cikti)
    return harita


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("gorsel")
    ap.add_argument("cikti")
    ap.add_argument("--en", type=float, default=1.1)
    ap.add_argument("--boy", type=float, default=2.1)
    ap.add_argument("--koseler", type=str, default=None,
                    help='Manuel: "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"')
    a = ap.parse_args()
    mk = None
    if a.koseler:
        mk = [[float(v) for v in p.split(",")] for p in a.koseler.split()]
        assert len(mk) == 4
    analiz(a.gorsel, a.cikti, a.en, a.boy, mk)
