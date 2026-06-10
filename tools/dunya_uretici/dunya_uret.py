# -*- coding: utf-8 -*-
# Backrooms - DUNYA URETICI (tek kaynak: kroki + 3B yerlesim)
#
# Mimari plani (oda-id izgarasi + kapi baglantilari + obje listesi) tanimlar; sundan:
#   1) tools/dunya_uretici/krokiler/kat_zemin.png   -> gercek mimari kroki (matplotlib)
#   2) tools/dunya_uretici/dunya_plan.json          -> tum yerlesim (duvar/zemin/tavan/kapi/obje/isik/leke)
# JSON'u hem Godot insa_dunya.gd (oynanabilir Dunya.tscn) hem Blender render_sinematik.py okur.
# Boylece KROKI = 3B DUNYA = RENDER (tek dogruluk kaynagi).
#
# Kullanim: python3 tools/dunya_uretici/dunya_uret.py

import json, os, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Arc, Circle, FancyArrow
from matplotlib.lines import Line2D

PROJE = "/home/user/Backrooms"
OUT   = os.path.join(PROJE, "tools", "dunya_uretici")
CELL  = 4.0
WALL_H = 3.0
Y0 = 0.0
DOOR_W = 1.42          # Kapi kanat acikligi (gercek olcum)
FILL_W = (CELL - DOOR_W) / 2.0   # kapi yani dolgu duvar genisligi (~1.29)

# -------------------------------------------------- PARCA META (Godot parti + Blender doku)
PARTS = {
    "Zemin":       {"kind":"floor", "tex":"zemin_ref",          "size":[4,0.12,4]},
    "GriZemin":    {"kind":"floor", "tex":"gray_tile_wall_01",  "size":[4,0.12,4]},
    "FayansZemin": {"kind":"floor", "tex":"gray_tile_wall_clean","size":[4,0.12,4]},
    "Duvar":       {"kind":"wall",  "tex":"gray_tile_wall_clean","size":[4,3,0.2]},
    "Duvar2":      {"kind":"wall",  "tex":"duvar2",             "size":[4,3,0.2]},
    "Tavan2":      {"kind":"ceil",  "tex":"tavan2",             "size":[4,0.12,4]},
    "Kapi":        {"kind":"door"},
    "Mazgal":          {"kind":"glb","glb":"models/mazgal.glb","yoff":0.239,"col":[0.95,0.45,0.95]},
    "GuvenlikKamerasi":{"kind":"glb","glb":"models/guvenlik_kamerasi.glb","yoff":0.415,"col":None},
    "EndustriyelLamba":{"kind":"glb","glb":"models/endustriyel_lamba.glb","yoff":0.082,"col":None},
    "CopKutusu":       {"kind":"glb","glb":"models/cop_kutusu.glb","yoff":0.49,"col":[0.6,0.98,0.6]},
    "ElektrikPanosu":  {"kind":"glb","glb":"models/elektrik_panosu.glb","yoff":0.49,"col":[0.28,0.98,0.68]},
    "Canavar":         {"kind":"glb","glb":"models/canavar.glb","yoff":0.0,"col":None},
    "Sutun1":          {"kind":"glb","glb":"models/sutun1.glb","yoff":0.0,"col":[0.35,1.0,0.35]},
    "Sutun2":          {"kind":"glb","glb":"models/sutun2.glb","yoff":0.0,"col":[0.4,1.0,0.4]},
    "Sutun3":          {"kind":"glb","glb":"models/sutun3.glb","yoff":0.0,"col":[0.3,1.0,0.3]},
}
FLOOR_TEX = {".":"Zemin", "g":"GriZemin", "f":"FayansZemin"}

# -------------------------------------------------- KAT PLANI (oda-id izgarasi)
# Her hucre bir oda id'si (bitisik ayni id = tek oda, ic duvar yok). '.' = bosluk.
# HIKAYE: "CIKIS YOK" - 10x buyutulmus, TASARLANMIS (geometrik olmayan) terk tesis.
# Bolgeler dikdortgenlerle elle tasarlandi (prosedurel-rastgele DEGIL); kivrimli koridor
# omurgasi + dallar + cikmazlar + canavar icin COKLU rota (W ve P ikisi de KD'ye baglanir).
# Akis: Resepsiyon -> kivrimli koridor -> ofis/arsiv/bakim/kazan/toplanti dallari ->
# islak koridor + otopark -> en alt koridor -> Yaratigin Ini -> CIKIS (en uzak kose).
H, W = 40, 38   # canvas: satir(H), sutun(W)

# Bolge atmosfer isik profilleri: (renk[r,g,b], enerji, menzil)  -- menzil oda-ici tutulur (sizma az)
ISIK = {
    "lobi":    ([1.00,0.96,0.88], 3.4, 7.0),
    "ofis":    ([1.00,0.90,0.60], 2.4, 6.2),
    "koridor": ([0.84,0.86,0.94], 1.7, 6.0),
    "arsiv":   ([0.92,0.74,0.50], 1.2, 5.0),
    "bakim":   ([0.55,0.95,0.68], 2.1, 6.2),
    "kazan":   ([1.00,0.55,0.28], 1.8, 5.8),   # turuncu kazan/firin
    "toplanti":([0.86,0.86,0.82], 1.8, 6.0),
    "islak":   ([0.48,0.60,0.80], 1.0, 4.8),   # karanlik mavi, sizinti
    "otopark": ([0.70,0.74,0.80], 1.5, 7.0),   # genis los
    "yaratik": ([0.95,0.32,0.28], 1.2, 5.5),   # kirmizi, tehlike
    "cikis":   ([0.55,1.00,0.70], 3.8, 8.0),   # parlak yesil, umut
}

# (id, ad, zemin, kroki_renk, isik_profili, [rect(i0,i1,j0,j1) inclusive ...])
BOLGE = [
    ("R", "Resepsiyon",        "g", "#d7dbe0", "lobi",    [(1,5,2,9)]),
    ("O", "Acik Ofis",         "f", "#e7ded0", "ofis",    [(1,5,13,21)]),
    ("a","Kuzey Koridor",     ".", "#cdd2bc", "koridor", [(6,7,3,23)]),
    ("A", "Arsiv",             "f", "#d8cdb6", "arsiv",   [(8,15,2,8)]),
    ("b","Dikey Koridor",     ".", "#cdd2bc", "koridor", [(8,19,16,17)]),
    ("V", "Bakim / Jenerator", "g", "#aebfae", "bakim",   [(9,15,18,26)]),
    ("Z", "Kazan Dairesi",     "g", "#c2a594", "kazan",   [(9,15,27,35)]),
    ("c","Orta Koridor",      ".", "#cdd2bc", "koridor", [(20,21,3,34)]),
    ("T", "Toplanti",          "f", "#e3dccb", "toplanti",[(22,27,2,10)]),
    ("W", "Islak Koridor",     ".", "#aeb7c2", "islak",   [(22,30,16,20)]),
    ("P", "Otopark / Depo",    "f", "#ded6c6", "otopark", [(22,30,21,33)]),
    ("d","Guney Koridor",     ".", "#cdd2bc", "koridor", [(31,32,9,30)]),
    ("N", "Yaratigin Ini",     ".", "#c89a96", "yaratik", [(33,38,11,24)]),
    ("E", "CIKIS",             "g", "#9fdcb0", "cikis",   [(33,37,25,32)]),
]

# ===== GRID'i tasarlanmis bolgelerden insa et =====
GRID = [['.' for _ in range(W)] for _ in range(H)]
ODA = {}          # id -> (ad, zemin, renk, isik)
_hc = {}          # id -> [(i,j) ...]
for _rid, _ad, _zem, _renk, _isik, _rects in BOLGE:
    ODA[_rid] = (_ad, _zem, _renk, _isik)
    _cs = []
    for (i0, i1, j0, j1) in _rects:
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                GRID[i][j] = _rid; _cs.append((i, j))
    _hc[_rid] = _cs
NR, NC = H, W

# Kapi baglantilari (akis). Komsu olan bu id ciftlerinde kapi acilir; gerisi duvar.
KAPILAR = [("R","a"),("O","a"),("a","A"),("a","b"),
           ("b","V"),("V","Z"),("b","c"),
           ("c","T"),("c","W"),("c","P"),("W","P"),
           ("W","d"),("P","d"),("d","N"),("N","E")]
KAPI_SET = set(tuple(sorted(p)) for p in KAPILAR)

def _bb(rid_):
    cs = _hc[rid_]; ii = [c[0] for c in cs]; jj = [c[1] for c in cs]
    return min(ii), max(ii), min(jj), max(jj)

# ===== OBJELER: bolge tipine gore DESENLI (rastgele DEGIL) yerlestirme =====
OBJELER = []
def _o(part, i, j, dx, dz, rot, scale=None):
    OBJELER.append((part, (i, j), (dx, dz), rot) + ((scale,) if scale else ()))

# Resepsiyon: 4 gorkemli tas sutun + giris kameralari + cop
i0,i1,j0,j1 = _bb("R")
for s,(ci,cj) in zip(["Sutun1","Sutun2","Sutun3","Sutun1"],
                     [(i0+1,j0+1),(i0+1,j1-1),(i1-1,j0+1),(i1-1,j1-1)]):
    _o(s, ci, cj, 0,0, 0, (1.3,2.85,1.3))
_o("GuvenlikKamerasi", i0,j0, 1.4,-1.4,135); _o("GuvenlikKamerasi", i0,j1, -1.4,-1.4,225)
_o("CopKutusu", i1,(j0+j1)//2, 0.8,1.0,0)
# Acik Ofis: panolar + kamera + cop (terk)
i0,i1,j0,j1 = _bb("O")
_o("ElektrikPanosu", i0,j1, 1.4,0,270); _o("GuvenlikKamerasi", i0,j1, -1.4,-1.4,225)
_o("CopKutusu", i0+1,j0+1, 0,0,0); _o("CopKutusu", i1,j1, 0,0,0)
# Koridorlar: uc kameralari + duzenli havalandirma mazgallari
for kid in ["a","b","c","d"]:
    cs = _hc[kid]; a=cs[0]; b=cs[-1]
    _o("GuvenlikKamerasi", a[0],a[1], 0,0, 90); _o("GuvenlikKamerasi", b[0],b[1], 0,0, 270)
    for k in range(3, len(cs), 6):
        _o("Mazgal", cs[k][0], cs[k][1], 0,0,0)
# Arsiv: pano + kutular (karanlik)
i0,i1,j0,j1 = _bb("A")
_o("ElektrikPanosu", i0,j0, 1.4,0,270); _o("CopKutusu", i1,j1, 0,0,0); _o("CopKutusu", (i0+i1)//2,j0, 1.0,0,0)
# Bakim/Jenerator: cok pano + mazgal (sanayi)
i0,i1,j0,j1 = _bb("V")
_o("ElektrikPanosu", i0,j0, 0,-1.4,180); _o("ElektrikPanosu", i0,j0+2, 0,-1.4,180); _o("ElektrikPanosu", i0,j0+4, 0,-1.4,180)
_o("Mazgal", (i0+i1)//2,(j0+j1)//2, 0,0,0); _o("CopKutusu", i1,j1, 0,0,0)
# Kazan Dairesi: panolar + mazgallar (turuncu)
i0,i1,j0,j1 = _bb("Z")
_o("ElektrikPanosu", i1,j0, -1.4,0,90); _o("ElektrikPanosu", i1,j1, 1.4,0,270)
_o("Mazgal", i0+1,j0+1, 0,0,0); _o("Mazgal", i1-1,j1-1, 0,0,0)
# Toplanti: kutular + kamera
i0,i1,j0,j1 = _bb("T")
_o("CopKutusu", i0,j0, 0,0,0); _o("CopKutusu", i1,j1, 0,0,0); _o("GuvenlikKamerasi", i0,j1, -1.4,-1.4,225)
# Islak Koridor: yogun mazgal (sizinti) + kutu
for k,(ci,cj) in enumerate(_hc["W"]):
    if k % 3 == 0: _o("Mazgal", ci,cj, 0,0,0)
i0,i1,j0,j1 = _bb("W"); _o("CopKutusu", i1,j0, 0,0,0)
# Otopark/Depo: kameralar + kutular + pano + mazgal (genis)
i0,i1,j0,j1 = _bb("P")
_o("GuvenlikKamerasi", i0,j0, 1.4,-1.4,135); _o("GuvenlikKamerasi", i0,j1, -1.4,-1.4,225)
_o("CopKutusu", i1,j0+1, 0,0,0); _o("CopKutusu", i1,j1-1, 0,0,0)
_o("Mazgal", (i0+i1)//2,(j0+j1)//2, 0,0,0); _o("ElektrikPanosu", i1,j1, 1.4,0,270)
# Yaratigin Ini: CANAVAR + girip ciktigi delikler + kirik kamera + kutu
i0,i1,j0,j1 = _bb("N")
_o("Canavar", i1-1,(j0+j1)//2, 0,0, 200)
for (ci,cj) in [(i0,j0+1),(i0,j1-1),((i0+i1)//2,j0),((i0+i1)//2,j1)]:
    _o("Mazgal", ci,cj, 0,0,0)
_o("GuvenlikKamerasi", i0,j0, 1.4,-1.4,120); _o("CopKutusu", i1,j0, 0,0,0)
# Cikis: kamera
i0,i1,j0,j1 = _bb("E")
_o("GuvenlikKamerasi", i0,j1, -1.4,-1.4,250)

# ==================================================================== TUREME
def cell_center(i,j): return (j*CELL, i*CELL)
def rid(i,j):
    if 0<=i<NR and 0<=j<NC and GRID[i][j]!='.':
        return GRID[i][j]
    return None

instances = []   # {"part","pos":[x,y,z],"rot":deg,"scale":[..],"col":[sx,sy,sz,offy] | None}
lights    = []   # {"pos":[x,y,z],"color":[r,g,b],"energy","range"}
stains    = []   # {"pos":[x,y,z],"normal":[..],"size":s,"tex":"leke_xx"}
door_edges_bp = []  # kroki icin kapi cizimi: (x,z,yatay?)
wall_segs_bp  = []  # kroki duvar: (x0,z0,x1,z1)

def add_inst(part,x,z,rot=0.0,y=Y0,scale=(1,1,1),col=None):
    instances.append({"part":part,"pos":[round(x,3),round(y,3),round(z,3)],
                      "rot":round(rot,2),"scale":[round(s,4) for s in scale],"col":col})

# ---- ZEMIN + TAVAN (her dolu hucre) + tavan isigi/lamba
for i in range(NR):
    for j in range(NC):
        r = rid(i,j)
        if r is None: continue
        x,z = cell_center(i,j)
        add_inst(FLOOR_TEX[ODA[r][1]], x, z, 0.0, y=Y0, col=[4,0.12,4,0.0])
        add_inst("Tavan2", x, z, 0.0, y=Y0+WALL_H)
        # tavan lambasi + omni (her hucre)
        add_inst("EndustriyelLamba", x, z, 90.0 if (i+j)%2 else 0.0, y=Y0+WALL_H-0.28)
        # SAHTE LAMBA optimizasyonu (#9): lamba mesh'i her hucrede ama gercek OmniLight
        # 2 hucrede 1 -> sahte lambalar komsu isigi paylasir; isik sayisi ~yariya iner.
        if (i + j) % 2 == 0:
            col_, en_, rng_ = ISIK[ODA[r][3]]        # bolgeye gore atmosfer isigi
            lights.append({"pos":[x,Y0+WALL_H-0.5,z],"color":col_,"energy":en_*1.25,"range":rng_})

# ---- DUVARLAR + KAPILAR (kenar bazli)
def wall_part_for(r1,r2):
    # sanayi/derin bolgeler farkli duvar dokusu (atmosfer geciSi)
    s = {r1,r2} & {"V","W","N","A"}
    return "Duvar2" if s else "Duvar"

def edge_door(a,b):
    if a is None or b is None: return False
    return tuple(sorted((a,b))) in KAPI_SET

def place_wall_seg(x,z,rot,part):
    add_inst(part, x, z, rot, y=Y0, col=[4,3,0.2,1.5])

def place_door(x,z,rot,part):
    # kapi (2m) + iki yan dolgu (tam boy) + ust lento (2..3m, kapi ustu delik kapanir)
    add_inst("Kapi", x, z, rot, y=Y0)
    off = DOOR_W/2 + FILL_W/2
    sx = FILL_W/CELL
    lnt_sx = DOOR_W/CELL; lnt_sy = 1.0/WALL_H     # lento: kapi genisligi x (3-2)=1m boy
    if abs(rot-90)<1 or abs(rot-270)<1:   # dikey (Z boyunca)
        add_inst(part, x, z+off, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
        add_inst(part, x, z-off, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
    else:
        add_inst(part, x+off, z, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
        add_inst(part, x-off, z, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
    add_inst(part, x, z, rot, y=Y0+2.0, scale=(lnt_sx,lnt_sy,1), col=[4,3,0.2,1.5])

# dikey kenarlar (x = j*4-2), sol=(i,j-1) sag=(i,j)
for i in range(NR):
    for j in range(NC+1):
        L,R = rid(i,j-1), rid(i,j)
        if L==R and L is not None: continue          # oda ici -> acik
        if L is None and R is None: continue
        x = j*CELL - 2; z = i*CELL
        part = wall_part_for(L,R)
        if edge_door(L,R):
            place_door(x,z,90.0,part); door_edges_bp.append((x,z,False))
        else:
            place_wall_seg(x,z,90.0,part); wall_segs_bp.append((x,z-2,x,z+2))
# yatay kenarlar (z = i*4-2), ust=(i-1,j) alt=(i,j)
for i in range(NR+1):
    for j in range(NC):
        T,B = rid(i-1,j), rid(i,j)
        if T==B and T is not None: continue
        if T is None and B is None: continue
        x = j*CELL; z = i*CELL - 2
        part = wall_part_for(T,B)
        if edge_door(T,B):
            place_door(x,z,0.0,part); door_edges_bp.append((x,z,True))
        else:
            place_wall_seg(x,z,0.0,part); wall_segs_bp.append((x-2,z,x+2,z))

# ---- OBJELER
for o in OBJELER:
    part,(i,j),(dx,dz),rot = o[0],o[1],o[2],o[3]
    scl = tuple(o[4]) if len(o)>4 else (1,1,1)
    x,z = cell_center(i,j)
    meta = PARTS[part]
    # NOT: wrapper .tscn modeli zaten tabani y=0'a kaldirir -> burada yoff EKLENMEZ.
    y = Y0
    if part=="GuvenlikKamerasi": y = Y0+WALL_H-1.0      # duvar ustu, tavan alti
    col = None
    if meta.get("col"):
        cs = meta["col"]; col=[cs[0],cs[1],cs[2], cs[1]/2.0]
    add_inst(part, x+dx, z+dz, float(rot), y=y, scale=scl, col=col)

# ---- LEKE / KIR (zemine ve bazi duvar diplerine; "katmanli" kirlilik)
import random
random.seed(7)
floor_cells = [(i,j) for i in range(NR) for j in range(NC) if rid(i,j)]
for _ in range(int(len(floor_cells)*1.6)):
    i,j = random.choice(floor_cells)
    x,z = cell_center(i,j)
    px = x + random.uniform(-1.8,1.8); pz = z + random.uniform(-1.8,1.8)
    stains.append({"pos":[round(px,2),Y0+0.07,round(pz,2)],"normal":[0,1,0],
                   "size":round(random.uniform(0.6,1.9),2),
                   "tex":"lekeler/leke_%02d"%random.randint(1,16),
                   "rot":round(random.uniform(0,360),1)})

# ---- OYUNCU SPAWN (resepsiyon ortasi)
sx,sz = cell_center(3,5); spawn=[sx, Y0+1.0, sz]

# ==================================================================== JSON
plan = {
  "cell":CELL,"wall_h":WALL_H,"y0":Y0,"nr":NR,"nc":NC,
  "parts_meta":PARTS,"instances":instances,"lights":lights,"stains":stains,
  "spawn":spawn,
  "grid":["".join(r) for r in GRID],
  "rooms":{k:[v[0],v[1]] for k,v in ODA.items()},
}
with open(os.path.join(OUT,"dunya_plan.json"),"w") as f:
    json.dump(plan,f,indent=1)
print("instances:",len(instances),"lights:",len(lights),"stains:",len(stains))

# ==================================================================== KROKI (matplotlib)
def room_cells(rid_):
    return [(i,j) for i in range(NR) for j in range(NC) if GRID[i][j]==rid_]

fig,ax = plt.subplots(figsize=(13,11))
ax.set_facecolor("#f7f5ef")
# zemin hucreleri
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        ax.add_patch(Rectangle((x-2,z-2),CELL,CELL,facecolor=ODA[r][2],
                     edgecolor="#bcb7a8",lw=0.6,zorder=1))
# oda etiketleri (centroid)
for r,info in ODA.items():
    ad,ft,col = info[0],info[1],info[2]
    cs=room_cells(r)
    if not cs: continue
    cx=sum(cell_center(i,j)[0] for i,j in cs)/len(cs)
    cz=sum(cell_center(i,j)[1] for i,j in cs)/len(cs)
    alan=len(cs)*CELL*CELL
    ax.text(cx,cz-0.35,ad,ha="center",va="center",fontsize=11,weight="bold",color="#2b2b2b",zorder=5)
    ax.text(cx,cz+0.7,"%d m²"%alan,ha="center",va="center",fontsize=8,color="#555",zorder=5)
# duvarlar
for x0,z0,x1,z1 in wall_segs_bp:
    ax.plot([x0,x1],[z0,z1],color="#1c1c1c",lw=5,solid_capstyle="butt",zorder=6)
# kapilar (acikligi + acilis yayi)
for x,z,yatay in door_edges_bp:
    if yatay:
        ax.plot([x-DOOR_W/2,x+DOOR_W/2],[z,z],color="#f7f5ef",lw=6,zorder=7)
        ax.add_patch(Arc((x-DOOR_W/2,z),DOOR_W*2,DOOR_W*2,angle=0,theta1=0,theta2=80,color="#8a6d3b",lw=1.2,zorder=8))
    else:
        ax.plot([x,x],[z-DOOR_W/2,z+DOOR_W/2],color="#f7f5ef",lw=6,zorder=7)
        ax.add_patch(Arc((x,z-DOOR_W/2),DOOR_W*2,DOOR_W*2,angle=0,theta1=10,theta2=90,color="#8a6d3b",lw=1.2,zorder=8))
# objeler (semboller)
OBJ_STYLE={"CopKutusu":("o","#3b7a3b","Cop Kutusu"),
           "ElektrikPanosu":("s","#b5651d","Elektrik Panosu"),
           "GuvenlikKamerasi":("^","#b00020","Guvenlik Kamerasi"),
           "Mazgal":("P","#3a3a3a","Mazgal"),
           "EndustriyelLamba":("*","#d4a017","Tavan Lambasi"),
           "Canavar":("X","#cc0033","CANAVAR"),
           "Sutun1":("H","#7d828b","Sutun"),"Sutun2":("H","#7d828b","Sutun"),"Sutun3":("H","#7d828b","Sutun")}
for o in OBJELER:
    part,(i,j),(dx,dz),rot = o[0],o[1],o[2],o[3]
    x,z=cell_center(i,j); m,c,lab=OBJ_STYLE[part]
    sz_=170 if part=="Canavar" else 90
    ax.scatter([x+dx],[z+dz],marker=m,s=sz_,color=c,edgecolor="white",lw=0.7,zorder=9)
# lamba sembolleri (her hucre)
for i,j in floor_cells:
    x,z=cell_center(i,j)
    ax.scatter([x],[z],marker="*",s=55,color="#d4a017",alpha=0.5,zorder=4)
# spawn
ax.scatter([spawn[0]],[spawn[2]],marker="X",s=160,color="#0050b3",edgecolor="white",lw=1,zorder=10)
ax.text(spawn[0],spawn[2]-0.9,"BASLANGIC",ha="center",fontsize=8,color="#0050b3",weight="bold",zorder=10)

# izgara + olcek
for j in range(NC+1): ax.plot([j*CELL-2,j*CELL-2],[-2,NR*CELL-2],color="#e2ddd0",lw=0.5,zorder=0)
for i in range(NR+1): ax.plot([-2,NC*CELL-2],[i*CELL-2,i*CELL-2],color="#e2ddd0",lw=0.5,zorder=0)
# olcek cubugu
bx,bz=-2, NR*CELL-1.0
ax.plot([bx,bx+8],[bz,bz],color="#1c1c1c",lw=3); ax.text(bx+4,bz+0.5,"8 m",ha="center",fontsize=9)
# kuzey oku
ax.annotate("K",xy=(NC*CELL-3.0,-3.3),xytext=(NC*CELL-3.0,-1.0),
            arrowprops=dict(arrowstyle="-|>",color="#1c1c1c",lw=1.6),ha="center",fontsize=11,weight="bold")

ax.set_xlim(-4, NC*CELL); ax.set_ylim(NR*CELL, -4)   # z asagi
ax.set_aspect("equal"); ax.set_xlabel("X (m)"); ax.set_ylabel("Z (m)")
ax.set_title("BACKROOMS — ZEMIN KAT MIMARI KROKISI\n%d oda · %d m² · 4 m izgara"%(
    len(ODA), len(floor_cells)*CELL*CELL), fontsize=14, weight="bold")
# lejant
_seenlab=set(); leg=[]
for (m,c,lab) in OBJ_STYLE.values():
    if lab in _seenlab: continue
    _seenlab.add(lab)
    leg.append(Line2D([0],[0],marker=m,color="w",markerfacecolor=c,markersize=10,label=lab))
leg.append(Line2D([0],[0],color="#1c1c1c",lw=5,label="Duvar"))
leg.append(Line2D([0],[0],marker="X",color="w",markerfacecolor="#0050b3",markersize=11,label="Baslangic"))
ax.legend(handles=leg,loc="upper left",bbox_to_anchor=(1.01,1.0),fontsize=9,frameon=True)
plt.tight_layout()
fig.savefig(os.path.join(OUT,"krokiler","kat_zemin.png"),dpi=130,bbox_inches="tight")
print("KROKI ->", os.path.join(OUT,"krokiler","kat_zemin.png"))
