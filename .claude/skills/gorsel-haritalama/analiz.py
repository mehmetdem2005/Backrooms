# -*- coding: utf-8 -*-
"""
Gorsel -> hassas sekil/oran haritalama araci (ML destekli, DETAYLI surum).

Pipeline:
  1) rembg (U^2-Net) ile arka plani ayir -> TEMIZ siluet maskesi
     (grunge/golgeye dayanikli; Otsu'ya gore cok daha guvenilir)
  2) Siluetten 6-nokta poligon -> kenar cizgilerini uzatip SANAL on-yuz
     koselerini bul -> perspektifi ON YUZE duzelt (rectify)
  3) FastSAM (segment-everything) ile duzlestirilmis on yuzde ic ogeleri
     (pencere, vent, dugme, yuva) piksel hassasiyetinde segment et
  4) HER ic oge icin: alt-piksel kenar + IC-ICE alt-ogeler (kabarik cubuk,
     girintili cep, alt-cerceve) + izgara sayisi + CIVATA/RIVET tespiti
  5) Hepsini [0..1] normalize edip harita.json'a yaz; INCE ETIKETLI grid +
     her oge icin otomatik zoom-grid dogrulama gorselleri uret

Kullanim:
  python3 analiz.py <gorsel> <cikti> [--en 1.1] [--boy 2.1]
  python3 analiz.py <gorsel> <cikti> --koseler "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"
  python3 analiz.py <gorsel> <cikti> --grid 0.02   # grid araligi (vars. 0.01)

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


def en_boy_orani(kose, W, H):
    """Perspektifteki dikdortgenin GERCEK en/boy oranini koselerden hesapla
    (Zhang-He metrik rektifikasyon). kose: TL,TR,BR,BL piksel."""
    tl, tr, br, bl = [np.asarray(p, float) for p in kose]
    u0, v0 = W / 2.0, H / 2.0
    m1 = np.array([tl[0], tl[1], 1.0]); m2 = np.array([tr[0], tr[1], 1.0])
    m3 = np.array([bl[0], bl[1], 1.0]); m4 = np.array([br[0], br[1], 1.0])
    k2 = np.dot(np.cross(m1, m4), m3) / np.dot(np.cross(m2, m4), m3)
    k3 = np.dot(np.cross(m1, m4), m2) / np.dot(np.cross(m3, m4), m2)
    n2 = k2 * m2 - m1
    n3 = k3 * m3 - m1
    n21, n22, n23 = n2; n31, n32, n33 = n3
    f2 = -(1.0/(n23*n33)) * ((n21*n31 - (n21*n33+n23*n31)*u0 + n23*n33*u0*u0)
                             + (n22*n32 - (n22*n33+n23*n32)*v0 + n23*n33*v0*v0))
    if f2 <= 0:
        return None
    f = f2 ** 0.5
    A = np.array([[f, 0, u0], [0, f, v0], [0, 0, 1.0]])
    Ai = np.linalg.inv(A); B = Ai.T @ Ai
    ar2 = (n2 @ B @ n2) / (n3 @ B @ n3)
    return float(ar2 ** 0.5) if ar2 > 0 else None


def kamera_poz(kose, en, boy, W, H):
    """Focal + kamera pozu (solvePnP). Derinlik/3B akil yurutme icin.
    Doner: {focal, mesafe_m, yaw_deg, pitch_deg, px_per_m}."""
    tl, tr, br, bl = [np.asarray(p, float) for p in kose]
    u0, v0 = W/2.0, H/2.0
    m1 = np.array([tl[0], tl[1], 1.0]); m2 = np.array([tr[0], tr[1], 1.0])
    m3 = np.array([bl[0], bl[1], 1.0]); m4 = np.array([br[0], br[1], 1.0])
    k2 = np.dot(np.cross(m1, m4), m3) / np.dot(np.cross(m2, m4), m3)
    k3 = np.dot(np.cross(m1, m4), m2) / np.dot(np.cross(m3, m4), m2)
    n2 = k2*m2 - m1; n3 = k3*m3 - m1
    n21, n22, n23 = n2; n31, n32, n33 = n3
    f2 = -(1.0/(n23*n33))*((n21*n31-(n21*n33+n23*n31)*u0+n23*n33*u0*u0)
                           + (n22*n32-(n22*n33+n23*n32)*v0+n23*n33*v0*v0))
    if f2 <= 0:
        return None
    f = float(f2**0.5)
    K = np.array([[f, 0, u0], [0, f, v0], [0, 0, 1.0]])
    obj = np.array([[0, 0, 0], [en, 0, 0], [en, boy, 0], [0, boy, 0]], np.float32)
    imgp = np.array([tl, tr, br, bl], np.float32)
    ok, rvec, tvec = cv2.solvePnP(obj, imgp, K, None)
    if not ok:
        return {"focal": round(f, 1)}
    R, _ = cv2.Rodrigues(rvec)
    nrm = R @ np.array([0, 0, 1.0])
    p0, _ = cv2.projectPoints(np.array([[0, boy/2, 0]], np.float32), rvec, tvec, K, None)
    p1, _ = cv2.projectPoints(np.array([[0.1, boy/2, 0]], np.float32), rvec, tvec, K, None)
    ppm = float(np.linalg.norm(p1 - p0) / 0.1)
    return {
        "focal": round(f, 1),
        "mesafe_m": round(float(np.linalg.norm(tvec)), 3),
        "yaw_deg": round(float(np.degrees(np.arctan2(nrm[0], nrm[2]))), 2),
        "pitch_deg": round(float(np.degrees(np.arctan2(nrm[1], nrm[2]))), 2),
        "px_per_m_sol": round(ppm, 1),
        "not_derinlik": "yan-serit_px / px_per_m_sol ~ derinlik*sin(yaw); sol kenardan olc",
    }


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


def _subpix(sig, i):
    if 0 < i < len(sig) - 1:
        a, b, c = sig[i-1], sig[i], sig[i+1]
        d = a - 2*b + c
        if abs(d) > 1e-6:
            return i + 0.5 * (a - c) / d
    return float(i)


def refine_bbox(gray, x0, y0, x1, y1, m=10, pad=6):
    """SAM kaba kutusunu gradyan zirvesiyle ALT-PIKSEL kesinlige getir."""
    H, W = gray.shape
    px0, px1 = int(x0*W), int(x1*W)
    py0, py1 = int(y0*H), int(y1*H)

    def dik(px, ya, yb):     # dikey kenar (x) ara
        prof = np.abs(cv2.Sobel(gray[ya:yb, :], cv2.CV_32F, 1, 0, 3)).mean(0)
        lo, hi = max(0, px-m), min(W-1, px+m)
        return _subpix(prof, lo + int(np.argmax(prof[lo:hi]))) / W

    def yat(py, xa, xb):     # yatay kenar (y) ara
        prof = np.abs(cv2.Sobel(gray[:, xa:xb], cv2.CV_32F, 0, 1, 3)).mean(1)
        lo, hi = max(0, py-m), min(H-1, py+m)
        return _subpix(prof, lo + int(np.argmax(prof[lo:hi]))) / H

    L = dik(px0, py0+pad, py1-pad); R = dik(px1, py0+pad, py1-pad)
    T = yat(py0, px0+pad, px1-pad); B = yat(py1, px0+pad, px1-pad)
    return L, T, R, B


def vent_izgara(gray, x0, y0, x1, y1):
    """Vent bolgesindeki yatay izgara cizgi (oluk) sayisini sag-lam olc.
    Ic banttan (kenar pahlarini disla) profil al, zirve grupla."""
    H, W = gray.shape
    # ic banti hafif kucult: yanlardan cerceve pahini disla, dikeyde TAM al
    dx = (x1 - x0) * 0.14; dy = (y1 - y0) * 0.04
    band = gray[int((y0+dy)*H):int((y1-dy)*H), int((x0+dx)*W):int((x1-dx)*W)]
    if band.size == 0 or band.shape[0] < 6:
        return 0
    # her satirin ortalama parlakligi: oluk(koyu)/rib(parlak) salinimi
    sat = band.astype(np.float32).mean(1)
    sat = cv2.GaussianBlur(sat.reshape(-1, 1), (1, 3), 0).ravel()
    try:
        from scipy.signal import find_peaks
        rng = sat.max() - sat.min()
        if rng < 6:
            return 0
        dist = max(2, band.shape[0] // 14)
        # oluk = parlaklik minimumu (ters profil zirvesi)
        pk, _ = find_peaks(sat.max() - sat, distance=dist, prominence=rng*0.18)
        return int(len(pk))
    except Exception:
        return 0


# ---------------------------------------------------- CIVATA / RIVET tespiti
def _civata_skoru(s, cx, cy, r):
    """Aday dairenin GERCEK civata olma skoru: ic disk ile cevre halka
    arasi net kontrast + dusuk ic-varyans (duzgun disk) + kenar gradyani."""
    H, W = s.shape
    cx, cy, r = int(cx), int(cy), int(max(2, r))
    if cx-2*r < 0 or cy-2*r < 0 or cx+2*r >= W or cy+2*r >= H:
        return 0.0
    yy, xx = np.ogrid[cy-2*r:cy+2*r+1, cx-2*r:cx+2*r+1]
    d = np.sqrt((xx-cx)**2 + (yy-cy)**2)
    patch = s[cy-2*r:cy+2*r+1, cx-2*r:cx+2*r+1].astype(np.float32)
    ic = patch[d <= r*0.6]
    halka = patch[(d >= r*1.1) & (d <= r*1.8)]
    if ic.size < 4 or halka.size < 4:
        return 0.0
    kontrast = abs(float(ic.mean()) - float(halka.mean()))
    duzgun = max(0.0, 1.0 - float(ic.std()) / 40.0)   # ic ne kadar duz
    return kontrast * duzgun


def tespit_civata(gray, x0, y0, x1, y1, rmin=3, rmax=11, esik=20.0, max_say=24):
    """Bir bolgedeki civata/rivet (kucuk daire) konumlarini bul.
    Grunge'a karsi: CLAHE + HoughCircles -> RADYAL KONTRAST dogrulamasi.
    Sadece duzgun disk + cevreyle net kontrast veren adaylar kalir."""
    H, W = gray.shape
    px0, py0 = int(x0*W), int(y0*H)
    sub = gray[py0:int(y1*H), px0:int(x1*W)]
    if sub.size == 0:
        return []
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    s = clahe.apply(sub)
    sb = cv2.medianBlur(s, 3)
    aday = []
    for p2 in (22, 18, 15):
        c = cv2.HoughCircles(sb, cv2.HOUGH_GRADIENT, dp=1, minDist=12,
                             param1=100, param2=p2, minRadius=rmin, maxRadius=rmax)
        if c is not None:
            for cx, cy, r in c[0]:
                aday.append((cx, cy, r))
            if len(aday) >= 6:
                break
    # RADYAL dogrulama + skor
    skorlu = []
    for cx, cy, r in aday:
        sk = _civata_skoru(s, cx, cy, r)
        if sk >= esik:
            skorlu.append((sk, (px0+cx)/W, (py0+cy)/H, r/W))
    skorlu.sort(key=lambda t: -t[0])
    sel = []
    for sk, gx, gy, gr in skorlu:
        if all((gx-b[0])**2 + (gy-b[1])**2 > (0.012)**2 for b in sel):
            sel.append((gx, gy, gr))
        if len(sel) >= max_say:
            break
    return [[round(float(a), 4), round(float(bb), 4), round(float(rr), 4)]
            for a, bb, rr in sel]


# ---------------------------------------------------- IC-ICE alt-ogeler
def alt_ogeler(rect, x0, y0, x1, y1):
    """Bir oge kutusu icinde KABARIK/GIRINTILI alt-yapilari bul:
    - kabarik dikey/yatay cubuk (handle/rail)  - alt-cerceve  - ic cep
    Parlaklik kontrasti + kontur ile; [0..1] normalize bbox + tur doner."""
    H, W = rect.shape[:2]
    g = cv2.cvtColor(rect, cv2.COLOR_BGR2GRAY)
    px0, py0, px1, py1 = int(x0*W), int(y0*H), int(x1*W), int(y1*H)
    sub = g[py0:py1, px0:px1]
    if sub.size == 0 or min(sub.shape) < 8:
        return []
    sw, sh = sub.shape[1], sub.shape[0]
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(6, 6))
    s = clahe.apply(sub)
    med = float(np.median(s))
    alt = []
    # KABARIK (parlak) ve GIRINTILI (koyu) bolgeleri ayri yakala
    for tur, m in (("kabarik", cv2.inRange(s, int(med+22), 255)),
                   ("girinti", cv2.inRange(s, 0, int(med-22)))):
        k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, k, 1)
        m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k, 2)
        cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        for c in cnts:
            a = cv2.contourArea(c) / float(sw*sh)
            if not (0.03 < a < 0.7):
                continue
            bx, by, bw, bh = cv2.boundingRect(c)
            # kenara yapisik veya cok ince olanlari ele
            if bw < sw*0.06 or bh < sh*0.06:
                continue
            nx0 = x0 + bx/sw*(x1-x0); ny0 = y0 + by/sh*(y1-y0)
            nx1 = x0 + (bx+bw)/sw*(x1-x0); ny1 = y0 + (by+bh)/sh*(y1-y0)
            oran = bw/max(bh, 1)
            sekil = ("dikey_cubuk" if oran < 0.5 else
                     "yatay_cubuk" if oran > 2.0 else "cep")
            alt.append({"tur": tur, "sekil": sekil,
                        "x": round(nx0, 4), "y": round(ny0, 4),
                        "x1": round(nx1, 4), "y1": round(ny1, 4),
                        "alan": round(float(a), 3)})
    # alan'a gore buyukten kucuge, en fazla 4 (gurultuyu sinirleyici)
    alt.sort(key=lambda d: -d["alan"])
    return alt[:4]


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


# ---------------------------------------------------- INCE ETIKETLI GRID
def ince_grid(img, adim=0.01, buyut=1):
    """[0..1] uzerine ince (minor=adim) + kalin (major=5*adim) etiketli grid."""
    o = img.copy()
    if buyut != 1:
        o = cv2.resize(o, (o.shape[1]*buyut, o.shape[0]*buyut),
                       interpolation=cv2.INTER_NEAREST)
    H, W = o.shape[:2]
    nmaj = int(round(0.05 / adim)) if adim > 0 else 5
    n = int(round(1.0 / adim))
    for i in range(0, n+1):
        v = i * adim
        px = int(round(v * (W-1))); py = int(round(v * (H-1)))
        major = (i % nmaj == 0)
        col = (0, 150, 255) if major else (55, 80, 110)
        cv2.line(o, (px, 0), (px, H), col, 1)
        cv2.line(o, (0, py), (W, py), col, 1)
        if major:
            cv2.putText(o, "%.2f" % v, (min(px+1, W-26), 11),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1, cv2.LINE_AA)
            cv2.putText(o, "%.2f" % v, (1, max(py-2, 9)),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.32, (0, 255, 255), 1, cv2.LINE_AA)
    return o


def oge_zoom_grid(rect, x0, y0, x1, y1, ad, ekstra=0.04):
    """Bir oge cevresini kirpip ince GLOBAL-etiketli grid bas (gozle okuma)."""
    H, W = rect.shape[:2]
    gx0 = max(0.0, x0-ekstra); gy0 = max(0.0, y0-ekstra)
    gx1 = min(1.0, x1+ekstra); gy1 = min(1.0, y1+ekstra)
    c = rect[int(gy0*H):int(gy1*H), int(gx0*W):int(gx1*W)].copy()
    if c.size == 0:
        return None
    S = max(2, int(420 / max(c.shape[1], 1)))
    c = cv2.resize(c, (c.shape[1]*S, c.shape[0]*S), interpolation=cv2.INTER_CUBIC)
    Hc, Wc = c.shape[:2]
    v = np.ceil(gx0/ad)*ad
    while v < gx1:
        px = int((v-gx0)/(gx1-gx0)*Wc)
        maj = round(v/ad) % 5 == 0
        cv2.line(c, (px, 0), (px, Hc), (0, 150, 255) if maj else (55, 80, 110), 1)
        if maj:
            cv2.putText(c, "%.2f" % v, (px+1, 11), cv2.FONT_HERSHEY_SIMPLEX,
                        0.3, (0, 255, 255), 1, cv2.LINE_AA)
        v += ad
    v = np.ceil(gy0/ad)*ad
    while v < gy1:
        py = int((v-gy0)/(gy1-gy0)*Hc)
        maj = round(v/ad) % 5 == 0
        cv2.line(c, (0, py), (Wc, py), (0, 150, 255) if maj else (55, 80, 110), 1)
        if maj:
            cv2.putText(c, "%.2f" % v, (1, py-2), cv2.FONT_HERSHEY_SIMPLEX,
                        0.3, (0, 255, 255), 1, cv2.LINE_AA)
        v += ad
    return c


# --------------------------------------------------------------- ana akis
def analiz(gorsel, cikti, en=1.1, boy=2.1, manuel_kose=None, grid_adim=0.01):
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

    # GERCEK en/boy: kullanici vermediyse perspektiften hesapla (varsayma!)
    oran_kaynak = "verilen"
    if en is None or boy is None:
        ar = en_boy_orani(kose, W, H)
        if ar is None:
            en, boy, oran_kaynak = 1.0, 2.0, "varsayilan(hesaplanamadi)"
        else:
            en, boy, oran_kaynak = ar, 1.0, "perspektiften_hesaplandi"

    rect, M, (Wt, Ht) = rectify(img, kose, en, boy)
    cv2.imwrite(os.path.join(cikti, "rectified_temiz.png"), rect)
    # genel model insasi icin: rectified siluet maskesi
    maske_r = cv2.warpPerspective(mask, M, (Wt, Ht))
    maske_r = (maske_r > 127).astype(np.uint8) * 255
    cv2.imwrite(os.path.join(cikti, "mask_rectified.png"), maske_r)
    # genel (deterministik) model insasi icin dis hat [0..1]
    mc, _ = cv2.findContours(maske_r, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if mc:
        oc = max(mc, key=cv2.contourArea)
        oc = cv2.approxPolyDP(oc, 0.004 * cv2.arcLength(oc, True), True).reshape(-1, 2)
        outline = [[round(float(x)/Wt, 5), round(float(y)/Ht, 5)] for x, y in oc]
        with open(os.path.join(cikti, "outline.json"), "w") as f:
            json.dump({"outline_normalize": outline, "rectified_boyut": [Wt, Ht]}, f, indent=1)

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

    # ALT-PIKSEL kesinlestirme (SAM kaba kutu -> gradyan kenari)
    gray = cv2.GaussianBlur(cv2.cvtColor(rect, cv2.COLOR_BGR2GRAY), (3, 3), 0).astype(np.float32)
    gray8 = cv2.cvtColor(rect, cv2.COLOR_BGR2GRAY)
    ogeler = []
    for a, x0, y0, x1, y1 in sorted(feats, key=lambda f: f[2]):
        try:
            rx0, ry0, rx1, ry1 = refine_bbox(gray, x0, y0, x1, y1)
            if rx1 > rx0 and ry1 > ry0:
                x0, y0, x1, y1 = rx0, ry0, rx1, ry1
        except Exception:
            pass
        x0, y0, x1, y1 = float(x0), float(y0), float(x1), float(y1)
        et = _etiket(x0, y0, x1, y1)
        d = {
            "etiket": et,
            "x": round(x0, 4), "y": round(y0, 4),
            "x1": round(x1, 4), "y1": round(y1, 4),
            "w": round(x1 - x0, 4), "h": round(y1 - y0, 4),
            "alan": round(float(a), 4),
        }
        if et == "vent":
            d["izgara_sayisi"] = int(vent_izgara(gray, x0, y0, x1, y1))
        # IC-ICE alt-ogeler (kabarik cubuk / cep / alt-cerceve)
        alt = alt_ogeler(rect, x0, y0, x1, y1)
        if alt:
            d["alt_ogeler"] = alt
        # her ogenin civatalarini bolgesel olarak ara
        cv = tespit_civata(gray8, max(0, x0-0.02), max(0, y0-0.02),
                           min(1, x1+0.02), min(1, y1+0.02))
        if cv:
            d["civatalar"] = cv
        ogeler.append(d)

    # TUM on yuzde civata/rivet haritasi (genel)
    civatalar = tespit_civata(gray8, 0.05, 0.05, 0.95, 0.97)

    harita = {
        "kaynak": os.path.basename(gorsel),
        "gorsel_boyut": [W, H],
        "gercek_en_boy": [round(en, 5), round(boy, 5)],
        "en_boy_orani": round(en / boy, 5),
        "oran_kaynak": oran_kaynak,
        "maske_kaynak": mkaynak,
        "oge_kaynak": okaynak,
        "kose_kaynak": "manuel" if manuel_kose is not None else "rembg_sanal",
        "grid_adim": grid_adim,
        "sanal_koseler_px": kose.tolist(),
        "rectified_boyut": [Wt, Ht],
        "siluet_rectified_normalize": sil_n,
        "ic_ogeler": ogeler,
        "civatalar_global": civatalar,
        "kamera": kamera_poz(kose, en, boy, W, H),
        "not": "ic_ogeler/siluet/civata ON YUZE duzlestirilmis [0..1] normalize. "
               "alt_ogeler her ic ogenin kabarik/girintili alt-yapilari.",
    }
    with open(os.path.join(cikti, "harita.json"), "w") as f:
        json.dump(harita, f, indent=2, ensure_ascii=False)

    # --- gorseller ---
    ov = img.copy()
    cv2.drawContours(ov, [cnt], -1, (0, 255, 0), 2)
    for p in kose:
        cv2.circle(ov, tuple(np.int32(p)), 9, (0, 0, 255), -1)
    cv2.imwrite(os.path.join(cikti, "overlay.png"), ov)

    # INCE etiketli grid (tum on yuz)
    cv2.imwrite(os.path.join(cikti, "rectified_grid.png"),
                ince_grid(rect, grid_adim))

    rv = rect.copy()
    renk = {"dikey_pencere": (255, 80, 80), "vent": (80, 200, 255),
            "yuva": (80, 80, 255), "oge": (0, 200, 0)}
    for o in ogeler:
        c = renk.get(o["etiket"], (0, 200, 0))
        cv2.rectangle(rv, (int(o["x"]*Wt), int(o["y"]*Ht)),
                      (int(o["x1"]*Wt), int(o["y1"]*Ht)), c, 2)
        cv2.putText(rv, o["etiket"], (int(o["x"]*Wt), max(0, int(o["y"]*Ht)-5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.45, c, 1, cv2.LINE_AA)
        for al in o.get("alt_ogeler", []):
            ac = (0, 255, 255) if al["tur"] == "kabarik" else (255, 0, 255)
            cv2.rectangle(rv, (int(al["x"]*Wt), int(al["y"]*Ht)),
                          (int(al["x1"]*Wt), int(al["y1"]*Ht)), ac, 1)
    for b in civatalar:
        cv2.circle(rv, (int(b[0]*Wt), int(b[1]*Ht)), max(2, int(b[2]*Wt)),
                   (0, 255, 0), 2)
    cv2.imwrite(os.path.join(cikti, "ogeler.png"), rv)

    # her ic oge icin otomatik ZOOM-GRID (gozle hassas okuma)
    zdir = os.path.join(cikti, "zoom")
    os.makedirs(zdir, exist_ok=True)
    for i, o in enumerate(ogeler):
        z = oge_zoom_grid(rect, o["x"], o["y"], o["x1"], o["y1"], grid_adim)
        if z is not None:
            cv2.imwrite(os.path.join(zdir, "oge_%d_%s.png" % (i, o["etiket"])), z)

    print("maske:", mkaynak, "| oge:", okaynak, "| oge sayisi:", len(ogeler),
          "| global civata:", len(civatalar))
    for o in ogeler:
        ek = ""
        if "izgara_sayisi" in o:
            ek += " izgara=%d" % o["izgara_sayisi"]
        if "alt_ogeler" in o:
            ek += " alt=%d" % len(o["alt_ogeler"])
        if "civatalar" in o:
            ek += " civata=%d" % len(o["civatalar"])
        print("  {etiket:14s} x[{x:.3f},{x1:.3f}] y[{y:.3f},{y1:.3f}]".format(**o) + ek)
    print("cikti:", cikti, "| zoom-grid:", zdir)
    return harita


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("gorsel")
    ap.add_argument("cikti")
    ap.add_argument("--en", type=float, default=None,
                    help="verilmezse perspektiften GERCEK oran hesaplanir")
    ap.add_argument("--boy", type=float, default=None)
    ap.add_argument("--koseler", type=str, default=None,
                    help='Manuel: "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"')
    ap.add_argument("--grid", type=float, default=0.01,
                    help="grid minor araligi [0..1] (vars. 0.01; major=5x)")
    a = ap.parse_args()
    mk = None
    if a.koseler:
        mk = [[float(v) for v in p.split(",")] for p in a.koseler.split()]
        assert len(mk) == 4
    analiz(a.gorsel, a.cikti, a.en, a.boy, mk, a.grid)
