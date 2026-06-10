# -*- coding: utf-8 -*-
# Backrooms - DUNYA URETICI (tek kaynak: kroki + 3B yerlesim)
#
#   python3 tools/dunya_uretici/dunya_uret.py
#     -> tools/dunya_uretici/dunya_plan.json   (duvar/zemin/tavan/kapi/obje/isik/leke)
#     -> tools/dunya_uretici/krokiler/kat_zemin.png
#   JSON'u Godot insa_dunya.gd (Dunya.tscn) ve Blender render_sinematik.py okur.
#
# TASARIM ILKELERI (kullanici + insiyatif):
#  * Koridorlar SERBEST gezilebilir: koridor<->koridor ve koridor<->salon ARASINDA DUVAR YOK.
#    Koridorlar bir IZGARA/RING olusturur -> coklu dongu (cikissiz dongu hissi, canavar kusatma).
#  * Sadece ODALARA kapi: her oda koridora/salona bakan kenarindan OTOMATIK tek (buyukse 2) kapi.
#  * Salonlar (resepsiyon, acik ofis, ana salon) koridora KAPISIZ acilir.
#  * Bolgeler dikdortgenlerle ELLE tasarlandi (prosedurel-rastgele DEGIL). Gercekci tesis akisi.

import json, os, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Arc
from matplotlib.lines import Line2D
from collections import defaultdict

PROJE = "/home/user/Backrooms"
OUT   = os.path.join(PROJE, "tools", "dunya_uretici")
CELL  = 4.0
WALL_H = 3.0
Y0 = 0.0
DOOR_W = 1.42
FILL_W = (CELL - DOOR_W) / 2.0

# -------------------------------------------------- PARCA META
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

# -------------------------------------------------- ISIK PROFILLERI (bolge atmosferi)
ISIK = {
    "lobi":    ([1.00,0.96,0.88], 3.2, 7.0),
    "salon":   ([0.96,0.94,0.86], 2.8, 7.5),
    "ofis":    ([1.00,0.90,0.60], 2.3, 6.2),
    "koridor": ([0.84,0.86,0.94], 1.7, 6.0),
    "arsiv":   ([0.92,0.74,0.50], 1.2, 5.0),
    "bakim":   ([0.55,0.95,0.68], 2.0, 6.2),
    "kazan":   ([1.00,0.55,0.28], 1.7, 5.8),
    "depo":    ([0.80,0.78,0.62], 1.3, 5.5),
    "islak":   ([0.48,0.60,0.80], 1.0, 4.8),
    "yaratik": ([0.95,0.32,0.28], 1.1, 5.5),
    "cikis":   ([0.55,1.00,0.70], 3.6, 8.0),
}

# -------------------------------------------------- KAT PLANI
# (id, ad, zemin, kroki_renk, isik_profili, TIP, [rect(i0,i1,j0,j1) inclusive ...])
# TIP: "koridor" (serbest+acik), "salon" (koridora kapisiz acik), "oda" (otomatik kapi)
# Canvas H satir x W sutun. Koridor "c" tek id: IZGARA (3 yatay x 4 dikey) -> coklu dongu.
H, W = 50, 48
BOLGE = [
    ("c", "Koridor", ".", "#cdd2bc", "koridor", "koridor",
        [(8,9,3,44),(22,23,3,44),(40,41,3,44),                 # yatay omurgalar
         (8,41,3,4),(8,41,16,17),(8,41,29,30),(8,41,43,44)]),  # dikey omurgalar
    ("R", "Resepsiyon",        "g", "#d7dbe0", "lobi",  "salon", [(1,7,16,31)]),
    ("O", "Acik Ofis",         "f", "#e7ded0", "ofis",  "salon", [(10,21,5,15)]),
    ("H", "Ana Salon",         "g", "#cfd6dd", "salon", "salon", [(10,21,18,28)]),
    ("T", "Toplanti",          "f", "#e3dccb", "ofis",  "oda",   [(10,15,31,42)]),
    ("D", "Depo",              "f", "#ded6c6", "depo",  "oda",   [(16,21,31,42)]),
    ("A", "Arsiv",             "f", "#d8cdb6", "arsiv", "oda",   [(24,39,5,15)]),
    ("N", "Yaratigin Ini",     ".", "#c89a96", "yaratik","oda",  [(24,39,18,28)]),
    ("V", "Bakim / Jenerator", "g", "#aebfae", "bakim", "oda",   [(24,31,31,42)]),
    ("Z", "Kazan Dairesi",     "g", "#c2a594", "kazan", "oda",   [(32,39,31,42)]),
    ("E", "CIKIS",             "g", "#9fdcb0", "cikis", "oda",   [(42,46,33,40)]),
]

# ===== GRID + ODA + TIP =====  (sonra cizilen kazanir; koridoru SONA koy ki acik kalsin)
GRID = [['.' for _ in range(W)] for _ in range(H)]
ODA = {}; TIP = {}; _hc = {}
for _rid, _ad, _zem, _renk, _isik, _tip, _rects in sorted(BOLGE, key=lambda b: 0 if b[5]!="koridor" else 1):
    ODA[_rid] = (_ad, _zem, _renk, _isik); TIP[_rid] = _tip
    cs = []
    for (i0, i1, j0, j1) in _rects:
        for i in range(i0, i1 + 1):
            for j in range(j0, j1 + 1):
                GRID[i][j] = _rid
    # hucreleri (kazanan id'ye gore) sonra topla
NR, NC = H, W
for i in range(NR):
    for j in range(NC):
        r = GRID[i][j]
        if r != '.': _hc.setdefault(r, []).append((i, j))

def cell_center(i, j): return (j*CELL, i*CELL)
def rid(i, j):
    if 0 <= i < NR and 0 <= j < NC and GRID[i][j] != '.': return GRID[i][j]
    return None
def _bb(r):
    cs = _hc[r]; ii=[c[0] for c in cs]; jj=[c[1] for c in cs]
    return min(ii),max(ii),min(jj),max(jj)

instances = []; lights = []; stains = []
door_edges_bp = []; wall_segs_bp = []
def add_inst(part, x, z, rot=0.0, y=Y0, scale=(1,1,1), col=None):
    instances.append({"part":part,"pos":[round(x,3),round(y,3),round(z,3)],
                      "rot":round(rot,2),"scale":[round(s,4) for s in scale],"col":col})

# ---- ZEMIN + TAVAN + LAMBA + ISIK (her dolu hucre); sahte lamba ile isik ~yariya
for i in range(NR):
    for j in range(NC):
        r = rid(i,j)
        if r is None: continue
        x,z = cell_center(i,j)
        add_inst(FLOOR_TEX[ODA[r][1]], x, z, 0.0, y=Y0, col=[4,0.12,4,0.0])
        add_inst("Tavan2", x, z, 0.0, y=Y0+WALL_H)
        add_inst("EndustriyelLamba", x, z, 90.0 if (i+j)%2 else 0.0, y=Y0+WALL_H-0.28)
        if (i+j) % 2 == 0:                                   # SAHTE LAMBA opt (#9)
            col_,en_,rng_ = ISIK[ODA[r][3]]
            lights.append({"pos":[x,Y0+WALL_H-0.5,z],"color":col_,"energy":en_*1.3,"range":rng_})

# ---- DUVAR DOKUSU secimi
def wall_part_for(a,b):
    s = {a,b} & {"V","Z","N","A"}      # sanayi/derin/arsiv -> farkli doku
    return "Duvar2" if s else "Duvar"

# ---- KENAR SINIFLANDIRMA: ACIK / DUVAR / KAPI-ADAYI
WALK = {"koridor","salon"}
duvar_edges = []                 # (kind,i,j,a,b) kesin duvar
aday = {}                        # (kind,i,j) -> (a,b)  oda<->walk kenari (kapi adayi)
oda_aday = defaultdict(list)     # oda -> [(kind,i,j,grup,sira)]
def _kenar(kind,i,j,a,b):
    if a == b: return
    if a is None and b is None: return
    if a is None or b is None:
        duvar_edges.append((kind,i,j,a,b)); return        # dis sinir
    ta,tb = TIP.get(a),TIP.get(b)
    if ta in WALK and tb in WALK: return                  # ACIK (koridor/salon)
    if ta=="oda" and tb=="oda":
        duvar_edges.append((kind,i,j,a,b)); return
    oda = a if ta=="oda" else b                           # oda <-> walk -> kapi adayi
    grup = ('V',j) if kind=='V' else ('H',i)
    sira = i if kind=='V' else j
    aday[(kind,i,j)] = (a,b); oda_aday[oda].append((kind,i,j,grup,sira))

for i in range(NR):
    for j in range(NC+1):
        _kenar('V',i,j, rid(i,j-1), rid(i,j))
for i in range(NR+1):
    for j in range(NC):
        _kenar('H',i,j, rid(i-1,j), rid(i,j))

# ---- ODA basina OTOMATIK kapi sec (kucuk:1, buyuk:2) en uzun walk-kenarinin ORTASINDAN
kapi_edges = set()
for oda,ad in oda_aday.items():
    gruplar = defaultdict(list)
    for e in ad: gruplar[e[3]].append(e)
    sirali = sorted(gruplar.values(), key=lambda g:-len(g))
    n_kapi = 2 if (len(_hc[oda]) >= 90 and len(sirali) >= 2) else 1
    for g in sirali[:n_kapi]:
        g2 = sorted(g, key=lambda e:e[4]); mid = g2[len(g2)//2]
        kapi_edges.add((mid[0],mid[1],mid[2]))

# ---- YERLESTIRME (kapi + duvar)
def edge_geom(kind,i,j):
    return (j*CELL-2, i*CELL, 90.0) if kind=='V' else (j*CELL, i*CELL-2, 0.0)
def place_wall(x,z,rot,part):
    add_inst(part, x, z, rot, y=Y0, col=[4,3,0.2,1.5])
def place_door(x,z,rot,part):
    add_inst("Kapi", x, z, rot, y=Y0)
    off = DOOR_W/2 + FILL_W/2; sx = FILL_W/CELL
    lnt_sx = DOOR_W/CELL; lnt_sy = 1.0/WALL_H
    if abs(rot-90)<1 or abs(rot-270)<1:
        add_inst(part, x, z+off, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
        add_inst(part, x, z-off, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
    else:
        add_inst(part, x+off, z, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
        add_inst(part, x-off, z, rot, y=Y0, scale=(sx,1,1), col=[4,3,0.2,1.5])
    add_inst(part, x, z, rot, y=Y0+2.0, scale=(lnt_sx,lnt_sy,1), col=[4,3,0.2,1.5])

for (kind,i,j) in list(aday.keys()):       # oda kenarlari: kapi ya da duvar
    a,b = aday[(kind,i,j)]; x,z,rot = edge_geom(kind,i,j); part = wall_part_for(a,b)
    if (kind,i,j) in kapi_edges:
        place_door(x,z,rot,part); door_edges_bp.append((x,z, kind=='H'))
    else:
        place_wall(x,z,rot,part); wall_segs_bp.append((x-(0 if kind=='V' else 2), z-(2 if kind=='V' else 0),
                                                       x+(0 if kind=='V' else 2), z+(2 if kind=='V' else 0)))
for (kind,i,j,a,b) in duvar_edges:          # oda-oda + dis sinir: kesin duvar
    x,z,rot = edge_geom(kind,i,j); part = wall_part_for(a,b)
    place_wall(x,z,rot,part)
    wall_segs_bp.append((x-(0 if kind=='V' else 2), z-(2 if kind=='V' else 0),
                         x+(0 if kind=='V' else 2), z+(2 if kind=='V' else 0)))

# ---- OBJELER: bolge tipine gore DESENLI (rastgele DEGIL)
OBJELER = []
def _o(part,i,j,dx,dz,rot,scale=None):
    OBJELER.append((part,(i,j),(dx,dz),rot) + ((scale,) if scale else ()))
# Resepsiyon: 4 gorkemli sutun + kameralar + cop
i0,i1,j0,j1=_bb("R")
for s,(ci,cj) in zip(["Sutun1","Sutun2","Sutun3","Sutun1"],
                     [(i0+1,j0+2),(i0+1,j1-2),(i1-1,j0+2),(i1-1,j1-2)]):
    _o(s,ci,cj,0,0,0,(1.3,2.85,1.3))
_o("GuvenlikKamerasi",i0,j0,1.4,-1.4,135); _o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,225)
_o("CopKutusu",i1,(j0+j1)//2,0.8,1.0,0)
# Acik Ofis (salon): panolar + kutular + kamera
i0,i1,j0,j1=_bb("O")
_o("ElektrikPanosu",i0,j0,0,-1.4,180); _o("CopKutusu",i0+1,j1,0,0,0); _o("CopKutusu",i1,j0,0,0,0)
_o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,225)
# Ana Salon (salon): merkezde 2 sutun + kamera
i0,i1,j0,j1=_bb("H")
_o("Sutun2",(i0+i1)//2,j0+1,0,0,0,(1.4,2.85,1.4)); _o("Sutun3",(i0+i1)//2,j1-1,0,0,0,(1.4,2.85,1.4))
_o("GuvenlikKamerasi",i0,(j0+j1)//2,0,-1.4,180); _o("CopKutusu",i1,j0,0,0,0)
# Toplanti
i0,i1,j0,j1=_bb("T")
_o("CopKutusu",i0,j0,0,0,0); _o("CopKutusu",i1,j1,0,0,0); _o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,225)
# Depo
i0,i1,j0,j1=_bb("D")
_o("CopKutusu",i0,j0,0,0,0); _o("CopKutusu",i1,j1,0,0,0); _o("ElektrikPanosu",i1,j0,-1.4,0,90)
# Arsiv (karanlik)
i0,i1,j0,j1=_bb("A")
_o("ElektrikPanosu",i0,j0,1.4,0,270); _o("CopKutusu",i1,j1,0,0,0); _o("CopKutusu",(i0+i1)//2,j0,1.0,0,0)
# Bakim/Jenerator (sanayi yogun)
i0,i1,j0,j1=_bb("V")
_o("ElektrikPanosu",i0,j0,0,-1.4,180); _o("ElektrikPanosu",i0,j0+2,0,-1.4,180); _o("ElektrikPanosu",i0,j0+4,0,-1.4,180)
_o("Mazgal",(i0+i1)//2,(j0+j1)//2,0,0,0); _o("CopKutusu",i1,j1,0,0,0)
# Kazan (turuncu)
i0,i1,j0,j1=_bb("Z")
_o("ElektrikPanosu",i1,j0,-1.4,0,90); _o("ElektrikPanosu",i1,j1,1.4,0,270)
_o("Mazgal",i0+1,j0+1,0,0,0); _o("Mazgal",i1-1,j1-1,0,0,0)
# Yaratigin Ini: CANAVAR + delikler + kirik kamera
i0,i1,j0,j1=_bb("N")
_o("Canavar",i1-2,(j0+j1)//2,0,0,200)
for (ci,cj) in [(i0,j0+1),(i0,j1-1),((i0+i1)//2,j0),((i0+i1)//2,j1),(i1,(j0+j1)//2)]:
    _o("Mazgal",ci,cj,0,0,0)
_o("GuvenlikKamerasi",i0,j0,1.4,-1.4,120); _o("CopKutusu",i1,j0,0,0,0)
# Cikis
i0,i1,j0,j1=_bb("E")
_o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,250)
# Koridorlar: ring koselerinde kamera + duzenli havalandirma mazgallari
ck=_hc["c"]; ci0=min(c[0] for c in ck); ci1=max(c[0] for c in ck); cj0=min(c[1] for c in ck); cj1=max(c[1] for c in ck)
_o("GuvenlikKamerasi",ci0,cj0,1.4,1.4,135); _o("GuvenlikKamerasi",ci0,cj1,-1.4,1.4,225)
_o("GuvenlikKamerasi",ci1,cj0,1.4,-1.4,45); _o("GuvenlikKamerasi",ci1,cj1,-1.4,-1.4,315)
for k in range(0,len(ck),11):
    _o("Mazgal",ck[k][0],ck[k][1],0,0,0)

# ---- OBJELERI sahneye ekle
for o in OBJELER:
    part,(i,j),(dx,dz),rot = o[0],o[1],o[2],o[3]
    scl = tuple(o[4]) if len(o)>4 else (1,1,1)
    x,z = cell_center(i,j); meta = PARTS[part]
    y = Y0
    if part=="GuvenlikKamerasi": y = Y0+WALL_H-1.0
    col = None
    if meta.get("col"):
        cs = meta["col"]; col=[cs[0],cs[1],cs[2], cs[1]/2.0]
    add_inst(part, x+dx, z+dz, float(rot), y=y, scale=scl, col=col)

# ---- LEKE/KIR: DESENLI (duvar diplerinde birikir) - #12 + #18 (rastgele degil)
for idx,(x0,z0,x1,z1) in enumerate(wall_segs_bp):
    if idx % 2: continue
    mx,mz = (x0+x1)/2.0, (z0+z1)/2.0
    stains.append({"pos":[round(mx,2),Y0+0.07,round(mz,2)],"normal":[0,1,0],
                   "size":round(0.7 + (idx%5)*0.18, 2),
                   "tex":"lekeler/leke_%02d"%((idx%16)+1),
                   "rot":float((idx*47) % 360)})
# oda merkezlerine de hafif kir
for r,cs in _hc.items():
    if TIP[r]=="koridor": continue
    i0,i1,j0,j1=_bb(r); cx,cz=cell_center((i0+i1)//2,(j0+j1)//2)
    stains.append({"pos":[round(cx,2),Y0+0.07,round(cz,2)],"normal":[0,1,0],
                   "size":1.3,"tex":"lekeler/leke_%02d"%((hash(r)%16)+1),"rot":float(hash(r)%360)})

# ---- OYUNCU SPAWN (resepsiyon ortasi)
i0,i1,j0,j1=_bb("R"); sx,sz=cell_center((i0+i1)//2,(j0+j1)//2); spawn=[sx, Y0+1.0, sz]

# ==================================================================== JSON
plan = {
  "cell":CELL,"wall_h":WALL_H,"y0":Y0,"nr":NR,"nc":NC,
  "parts_meta":PARTS,"instances":instances,"lights":lights,"stains":stains,
  "spawn":spawn,
  "grid":["".join(r) for r in GRID],
  "rooms":{k:[ODA[k][0],ODA[k][1]] for k in ODA},
}
with open(os.path.join(OUT,"dunya_plan.json"),"w") as f:
    json.dump(plan,f,indent=1)
print("instances:",len(instances),"lights:",len(lights),"stains:",len(stains),
      "kapi:",len(kapi_edges),"duvar:",len(wall_segs_bp))

# ==================================================================== KROKI
def room_cells(r): return _hc.get(r,[])
fig,ax = plt.subplots(figsize=(16,16)); ax.set_facecolor("#f7f5ef")
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        ax.add_patch(Rectangle((x-2,z-2),CELL,CELL,facecolor=ODA[r][2],edgecolor="#cfcabd",lw=0.3,zorder=1))
for r in ODA:
    cs=room_cells(r)
    if not cs or TIP[r]=="koridor": continue
    cx=sum(cell_center(i,j)[0] for i,j in cs)/len(cs); cz=sum(cell_center(i,j)[1] for i,j in cs)/len(cs)
    ax.text(cx,cz-0.4,ODA[r][0],ha="center",va="center",fontsize=10,weight="bold",color="#222",zorder=5)
    ax.text(cx,cz+0.8,"%d m2"%(len(cs)*16),ha="center",va="center",fontsize=7,color="#555",zorder=5)
for x0,z0,x1,z1 in wall_segs_bp:
    ax.plot([x0,x1],[z0,z1],color="#1c1c1c",lw=4,solid_capstyle="butt",zorder=6)
for x,z,yatay in door_edges_bp:
    if yatay:
        ax.plot([x-DOOR_W/2,x+DOOR_W/2],[z,z],color="#f7f5ef",lw=5,zorder=7)
        ax.add_patch(Arc((x-DOOR_W/2,z),DOOR_W*2,DOOR_W*2,theta1=0,theta2=80,color="#8a6d3b",lw=1,zorder=8))
    else:
        ax.plot([x,x],[z-DOOR_W/2,z+DOOR_W/2],color="#f7f5ef",lw=5,zorder=7)
        ax.add_patch(Arc((x,z-DOOR_W/2),DOOR_W*2,DOOR_W*2,theta1=10,theta2=90,color="#8a6d3b",lw=1,zorder=8))
OBJ_STYLE={"CopKutusu":("o","#3b7a3b","Cop"),"ElektrikPanosu":("s","#b5651d","Pano"),
           "GuvenlikKamerasi":("^","#b00020","Kamera"),"Mazgal":("P","#3a3a3a","Mazgal"),
           "Canavar":("X","#cc0033","CANAVAR"),"Sutun1":("H","#7d828b","Sutun"),
           "Sutun2":("H","#7d828b","Sutun"),"Sutun3":("H","#7d828b","Sutun"),
           "EndustriyelLamba":("*","#d4a017","Lamba")}
for o in OBJELER:
    part,(i,j),(dx,dz),rot = o[0],o[1],o[2],o[3]
    if part not in OBJ_STYLE: continue
    x,z=cell_center(i,j); m,c,lab=OBJ_STYLE[part]
    ax.scatter([x+dx],[z+dz],marker=m,s=(170 if part=="Canavar" else 70),color=c,edgecolor="white",lw=0.6,zorder=9)
ax.scatter([spawn[0]],[spawn[2]],marker="*",s=240,color="#0050b3",edgecolor="white",lw=1,zorder=10)
ax.text(spawn[0],spawn[2]-1.2,"BASLANGIC",ha="center",fontsize=9,color="#0050b3",weight="bold",zorder=10)
ax.set_xlim(-4,NC*CELL); ax.set_ylim(NR*CELL,-4); ax.set_aspect("equal")
ax.set_title("BACKROOMS - 'CIKIS YOK' - ZEMIN KAT\n%d bolge | %d m2 | koridorlar acik, odalar kapili"%(
    len([b for b in BOLGE if b[5]!='koridor']), sum(len(c) for c in _hc.values())*16),fontsize=14,weight="bold")
leg=[Line2D([0],[0],marker=m,color="w",markerfacecolor=c,markersize=9,label=lab)
     for (m,c,lab) in {v for v in OBJ_STYLE.values()}]
leg.append(Line2D([0],[0],color="#1c1c1c",lw=4,label="Duvar"))
leg.append(Line2D([0],[0],marker="*",color="w",markerfacecolor="#0050b3",markersize=12,label="Baslangic"))
ax.legend(handles=leg,loc="upper left",bbox_to_anchor=(1.01,1.0),fontsize=8,frameon=True)
plt.tight_layout()
fig.savefig(os.path.join(OUT,"krokiler","kat_zemin.png"),dpi=110,bbox_inches="tight")
print("KROKI ->", os.path.join(OUT,"krokiler","kat_zemin.png"))
