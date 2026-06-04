# -*- coding: utf-8 -*-
"""
Gorsel -> hassas sekil/oran haritalama araci.

Bir referans gorselinden (kapi, panel, obje) modelleme icin gereken
GERCEK oranlari cikarir; "goz karari" tahmini ortadan kaldirir.

Adimlar:
  1) On plani arka plandan ayir (Otsu) -> en buyuk kontur = obje silueti
  2) Obje 3/4 perspektifte ise 4 dis koseyi bulup ON YUZE DUZLESTIR (warp)
     -> boylece olculer foreshortening'ten arinmis, gercek on-goruntu oranlari
  3) Duzlestirilmis goruntude ic ogeleri tespit et:
       - koyu bolgeler  -> pencereler / camlar
       - kenar (Canny) konturlari -> dikdortgen ogeler (tus takimi, panel cercevesi)
  4) Hepsini [0..1] normalize edip harita.json'a yaz
  5) Dogrulama icin overlay.png ve rectified.png uret

Kullanim:
  python3 analiz.py <gorsel> <cikti_dizini> [--en 1.1] [--boy 2.1] [--koyu-esik 95]

--en/--boy: objenin gercek dunya en/boy orani (warp hedef en-boy orani icin).
            Bilinmiyorsa varsayilan 1:2 kullanilir; sadece oran onemli.
"""
import cv2
import numpy as np
import json
import os
import argparse


def _kose_sirala(pts):
    """4 noktayi TL, TR, BR, BL sirasina koy."""
    pts = np.array(pts, dtype=np.float32)
    s = pts.sum(axis=1)
    d = np.diff(pts, axis=1).reshape(-1)
    tl = pts[np.argmin(s)]
    br = pts[np.argmax(s)]
    tr = pts[np.argmin(d)]
    bl = pts[np.argmax(d)]
    return np.array([tl, tr, br, bl], dtype=np.float32)


def _dis_kontur(img):
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (5, 5), 0)
    _, mask = cv2.threshold(blur, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    # objenin beyaz olmasini garanti et (kenar pikselleri cogunlukla arka plan)
    kenar = np.concatenate([mask[0, :], mask[-1, :], mask[:, 0], mask[:, -1]])
    if kenar.mean() > 127:
        mask = 255 - mask
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, k, iterations=3)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, k, iterations=1)
    cnts, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    if not cnts:
        raise RuntimeError("Obje konturu bulunamadi")
    cnt = max(cnts, key=cv2.contourArea)
    obj = np.zeros_like(mask)
    cv2.drawContours(obj, [cnt], -1, 255, -1)
    return cnt, obj


def _rectify(img, cnt, en, boy, manuel_kose=None):
    """4 dis koseden on yuze perspektif duzeltme.
    manuel_kose verilirse (TL,TR,BR,BL px) onu kullanir; yoksa otomatik."""
    if manuel_kose is not None:
        kose = np.array(manuel_kose, dtype=np.float32)
    else:
        hull = cv2.convexHull(cnt).reshape(-1, 2)
        kose = _kose_sirala(hull)
    oran = float(en) / float(boy)
    Ht = 1000
    Wt = int(round(Ht * oran))
    hedef = np.array([[0, 0], [Wt - 1, 0], [Wt - 1, Ht - 1], [0, Ht - 1]],
                     dtype=np.float32)
    M = cv2.getPerspectiveTransform(kose, hedef)
    rect = cv2.warpPerspective(img, M, (Wt, Ht))
    return rect, kose, (Wt, Ht)


def _dikdortgen_mi(c, tol=0.04):
    peri = cv2.arcLength(c, True)
    ap = cv2.approxPolyDP(c, tol * peri, True)
    return len(ap) == 4 and cv2.isContourConvex(ap)


def _ic_ogeler(rect):
    """Duzlestirilmis goruntude ic ogeleri bul."""
    H, W = rect.shape[:2]
    gray = cv2.cvtColor(rect, cv2.COLOR_BGR2GRAY)
    alan_tum = float(H * W)
    # kenarlardan biraz ic kal (cerceve disini ele)
    ic = np.zeros((H, W), np.uint8)
    cv2.rectangle(ic, (int(0.04 * W), int(0.04 * H)),
                  (int(0.96 * W), int(0.96 * H)), 255, -1)

    bulgular = []

    # (a) koyu bolgeler -> pencereler / camlar
    koyu = cv2.inRange(gray, 0, 95)
    koyu = cv2.bitwise_and(koyu, ic)
    koyu = cv2.morphologyEx(koyu, cv2.MORPH_OPEN,
                            cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5)))
    cnts, _ = cv2.findContours(koyu, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        a = cv2.contourArea(c)
        if a < 0.0010 * alan_tum or a > 0.30 * alan_tum:
            continue
        x, y, w, h = cv2.boundingRect(c)
        if w > 0.75 * W or h > 0.85 * H:   # tum paneli kapsayan sahte bulgu
            continue
        bulgular.append(("koyu", x, y, w, h, a))

    # (b) Canny kenar konturlari -> dikdortgen ogeler (tus takimi vb.)
    kenar = cv2.Canny(gray, 40, 120)
    kenar = cv2.dilate(kenar, np.ones((3, 3), np.uint8), iterations=1)
    cnts, _ = cv2.findContours(kenar, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    for c in cnts:
        a = cv2.contourArea(c)
        if a < 0.0015 * alan_tum or a > 0.25 * alan_tum:
            continue
        if not _dikdortgen_mi(c):
            continue
        x, y, w, h = cv2.boundingRect(c)
        cx, cy = x + w / 2, y + h / 2
        if ic[int(cy), int(cx)] == 0:
            continue
        bulgular.append(("kutu", x, y, w, h, a))

    # IoU ile tekrarlari ele (buyugu tut)
    bulgular.sort(key=lambda b: -b[5])
    secili = []

    def _iou(a, b):
        ax, ay, aw, ah = a[1:5]
        bx, by, bw, bh = b[1:5]
        x1, y1 = max(ax, bx), max(ay, by)
        x2, y2 = min(ax + aw, bx + bw), min(ay + ah, by + bh)
        inter = max(0, x2 - x1) * max(0, y2 - y1)
        uni = aw * ah + bw * bh - inter
        return inter / uni if uni else 0

    for b in bulgular:
        if all(_iou(b, s) < 0.3 for s in secili):
            secili.append(b)

    # konuma gore etiketle
    ogeler = []
    for tip, x, y, w, h, a in secili:
        nx, ny, nw, nh = x / W, y / H, w / W, h / H
        cx, cy = nx + nw / 2, ny + nh / 2
        oran_wh = w / h if h else 0
        if oran_wh < 0.6 and nh > 0.25:
            etiket = "dikey_pencere"
        elif cy < 0.5 and nw < 0.35 and nh < 0.2:
            etiket = "kucuk_pencere"
        elif cy >= 0.4 and nw < 0.35 and nh < 0.3:
            etiket = "tus_takimi"
        else:
            etiket = "oge"
        ogeler.append({
            "etiket": etiket, "kaynak": tip,
            "x": round(nx, 4), "y": round(ny, 4),
            "w": round(nw, 4), "h": round(nh, 4),
            "merkez": [round(cx, 4), round(cy, 4)],
            "alan_oran": round(a / alan_tum, 4),
        })
    ogeler.sort(key=lambda o: (o["y"], o["x"]))
    return ogeler


def analiz(gorsel, cikti, en=1.1, boy=2.1, manuel_kose=None):
    os.makedirs(cikti, exist_ok=True)
    img = cv2.imread(gorsel)
    if img is None:
        raise RuntimeError("Gorsel okunamadi: " + gorsel)
    H, W = img.shape[:2]

    cnt, obj = _dis_kontur(img)
    # ham siluet (perspektifli) - bbox normalize
    peri = cv2.arcLength(cnt, True)
    approx = cv2.approxPolyDP(cnt, 0.012 * peri, True).reshape(-1, 2)
    bx, by, bw, bh = cv2.boundingRect(cnt)
    silo = [[round((px - bx) / bw, 4), round((py - by) / bh, 4)]
            for px, py in approx]

    rect, kose, (Wt, Ht) = _rectify(img, cnt, en, boy, manuel_kose)
    ogeler = _ic_ogeler(rect)

    harita = {
        "kaynak": os.path.basename(gorsel),
        "gorsel_boyut": [W, H],
        "gercek_en_boy": [en, boy],
        "siluet_ham_normalize": silo,
        "dis_koseler_px": kose.tolist(),
        "rectified_boyut": [Wt, Ht],
        "ic_ogeler_rectified_normalize": ogeler,
        "kose_kaynak": "manuel" if manuel_kose is not None else "otomatik",
        "not": "ic_ogeler ON YUZE duzlestirilmis goruntude [0..1] normalize edilmistir.",
    }
    with open(os.path.join(cikti, "harita.json"), "w") as f:
        json.dump(harita, f, indent=2, ensure_ascii=False)

    # --- overlay (orijinal) ---
    ov = img.copy()
    cv2.drawContours(ov, [cnt], -1, (0, 255, 0), 2)
    for p in kose:
        cv2.circle(ov, tuple(np.int32(p)), 8, (0, 0, 255), -1)
    cv2.imwrite(os.path.join(cikti, "overlay.png"), ov)

    # --- rectified + ogeler ---
    rv = rect.copy()
    renkler = {"dikey_pencere": (255, 80, 80), "kucuk_pencere": (80, 200, 255),
               "tus_takimi": (80, 255, 80), "oge": (200, 200, 0)}
    for o in ogeler:
        x, y = int(o["x"] * Wt), int(o["y"] * Ht)
        w, h = int(o["w"] * Wt), int(o["h"] * Ht)
        col = renkler.get(o["etiket"], (200, 200, 0))
        cv2.rectangle(rv, (x, y), (x + w, y + h), col, 3)
        cv2.putText(rv, o["etiket"], (x, max(0, y - 6)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, col, 1, cv2.LINE_AA)
    cv2.imwrite(os.path.join(cikti, "rectified.png"), rv)

    # --- rectified + olcu izgarasi (gozle birebir okumak icin) ---
    rg = rect.copy()
    for i in range(1, 10):
        gx = int(i / 10 * Wt)
        gy = int(i / 10 * Ht)
        renk = (0, 165, 255) if i == 5 else (60, 60, 60)
        cv2.line(rg, (gx, 0), (gx, Ht), renk, 1)
        cv2.line(rg, (0, gy), (Wt, gy), renk, 1)
        cv2.putText(rg, ".%d" % i, (gx + 1, 12), cv2.FONT_HERSHEY_SIMPLEX,
                    0.32, (0, 165, 255), 1, cv2.LINE_AA)
        cv2.putText(rg, ".%d" % i, (1, gy - 2), cv2.FONT_HERSHEY_SIMPLEX,
                    0.32, (0, 165, 255), 1, cv2.LINE_AA)
    cv2.imwrite(os.path.join(cikti, "rectified_grid.png"), rg)
    # temiz on yuz (kutusuz)
    cv2.imwrite(os.path.join(cikti, "rectified_temiz.png"), rect)

    print("YAZILDI:", os.path.join(cikti, "harita.json"))
    print("  overlay.png  (orijinal + siluet/koseler)")
    print("  rectified.png(on yuz + tespit edilen ogeler)")
    print("OGE SAYISI:", len(ogeler))
    for o in ogeler:
        print("  - {etiket:14s} x={x:.3f} y={y:.3f} w={w:.3f} h={h:.3f}".format(**o))
    return harita


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("gorsel")
    ap.add_argument("cikti")
    ap.add_argument("--en", type=float, default=1.1)
    ap.add_argument("--boy", type=float, default=2.1)
    ap.add_argument("--koseler", type=str, default=None,
                    help='Manuel 4 kose px: "TLx,TLy TRx,TRy BRx,BRy BLx,BLy"')
    a = ap.parse_args()
    mk = None
    if a.koseler:
        mk = [[float(v) for v in p.split(",")] for p in a.koseler.split()]
        assert len(mk) == 4, "4 kose gerekli (TL TR BR BL)"
    analiz(a.gorsel, a.cikti, a.en, a.boy, mk)
