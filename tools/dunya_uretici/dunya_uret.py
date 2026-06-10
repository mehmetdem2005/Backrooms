# -*- coding: utf-8 -*-
# Backrooms - DUNYA URETICI (TASARLANMIS, 2 KANAT yan yana)
#   python3 tools/dunya_uretici/dunya_uret.py -> dunya_plan.json + krokiler/kat_zemin.png
#
# Kullanici: "sevdigim tasarim (50d8415) gibi olsun ama 2 FARKLI tane yan yana koyup buyut."
# -> Kanat A (orijinal: Resepsiyon/Ofis/Arsiv/Bakim/Kazan/Toplanti/Islak/Otopark/Yaratik/Cikis)
#    + ORTA GECIT koridoru + Kanat B (A'nin AYNALANMISI, FARKLI odalar: Ikinci Lobi/Sunucu/
#    Laboratuvar/Revir/Karantina/Yemekhane/Tuvalet/Ambar/Morg/Kontrol). Ayni stil, ~2x oda.

import json, os, random
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Arc
from matplotlib.lines import Line2D

PROJE="/home/user/Backrooms"; OUT=os.path.join(PROJE,"tools","dunya_uretici")
CELL,WALL_H,Y0=4.0,3.0,0.0; DOOR_W=1.42; FILL_W=(CELL-DOOR_W)/2.0

PARTS={
 "Zemin":{"kind":"floor","tex":"zemin_ref","size":[4,0.12,4]},
 "GriZemin":{"kind":"floor","tex":"gray_tile_wall_01","size":[4,0.12,4]},
 "FayansZemin":{"kind":"floor","tex":"gray_tile_wall_clean","size":[4,0.12,4]},
 "Duvar":{"kind":"wall","tex":"gray_tile_wall_clean","size":[4,3,0.2]},
 "Duvar2":{"kind":"wall","tex":"duvar2","size":[4,3,0.2]},
 "Tavan2":{"kind":"ceil","tex":"tavan2","size":[4,0.12,4]},
 "Kapi":{"kind":"door"},
 "Mazgal":{"kind":"glb","glb":"models/mazgal.glb","yoff":0.239,"col":[0.95,0.45,0.95]},
 "GuvenlikKamerasi":{"kind":"glb","glb":"models/guvenlik_kamerasi.glb","yoff":0.415,"col":None},
 "EndustriyelLamba":{"kind":"glb","glb":"models/endustriyel_lamba.glb","yoff":0.082,"col":None},
 "CopKutusu":{"kind":"glb","glb":"models/cop_kutusu.glb","yoff":0.49,"col":[0.6,0.98,0.6]},
 "ElektrikPanosu":{"kind":"glb","glb":"models/elektrik_panosu.glb","yoff":0.49,"col":[0.28,0.98,0.68]},
 "Canavar":{"kind":"glb","glb":"models/canavar.glb","yoff":0.0,"col":None},
 "Sutun1":{"kind":"glb","glb":"models/sutun1.glb","yoff":0.0,"col":[0.35,1.0,0.35]},
 "Sutun2":{"kind":"glb","glb":"models/sutun2.glb","yoff":0.0,"col":[0.4,1.0,0.4]},
 "Sutun3":{"kind":"glb","glb":"models/sutun3.glb","yoff":0.0,"col":[0.3,1.0,0.3]},
}
FLOOR_TEX={".":"Zemin","g":"GriZemin","f":"FayansZemin"}
ISIK={
 "lobi":([1.00,0.96,0.88],3.4,7.0),"ofis":([1.00,0.90,0.60],2.4,6.2),
 "koridor":([0.84,0.86,0.94],1.7,6.0),"arsiv":([0.92,0.74,0.50],1.2,5.0),
 "bakim":([0.55,0.95,0.68],2.1,6.2),"kazan":([1.00,0.55,0.28],1.8,5.8),
 "toplanti":([0.86,0.86,0.82],1.8,6.0),"islak":([0.48,0.60,0.80],1.0,4.8),
 "otopark":([0.70,0.74,0.80],1.5,7.0),"yaratik":([0.95,0.32,0.28],1.2,5.5),
 "cikis":([0.55,1.00,0.70],3.8,8.0),"lab":([0.70,0.95,0.95],2.2,6.2),
 "morg":([0.50,0.55,0.62],1.0,4.8),
}
# tema -> (zemin, kroki_renk)
THEME={
 "lobi":("g","#d7dbe0"),"ofis":("f","#e7ded0"),"koridor":(".","#cdd2bc"),
 "arsiv":("f","#d8cdb6"),"bakim":("g","#aebfae"),"kazan":("g","#c2a594"),
 "toplanti":("f","#e3dccb"),"islak":(".","#aeb7c2"),"otopark":("f","#ded6c6"),
 "yaratik":(".","#c89a96"),"cikis":("g","#9fdcb0"),"lab":("g","#bcd0cf"),"morg":(".","#9aa0a6"),
}

# ===================================================== 2 KANAT (A + Gecit + B, B FARKLI tasarim)
H, W = 44, 82
DX_B = 44                 # B kanadi saga ofset
# Kanat A (id, [rect]) - orijinal sevilen yerlesim
A_BASE=[
 ("R",[(1,5,2,9)]), ("O",[(1,5,13,21)]), ("a",[(6,7,3,23)]), ("A",[(8,15,2,8)]),
 ("b",[(8,19,16,17)]), ("V",[(9,15,18,26)]), ("Z",[(9,15,27,35)]), ("c",[(20,21,3,34)]),
 ("T",[(22,27,2,10)]), ("W",[(22,30,16,20)]), ("P",[(22,30,21,33)]), ("d",[(31,32,9,30)]),
 ("N",[(33,40,11,24)]), ("E",[(33,39,25,32)]),
]
A_META={ "R":("Resepsiyon","lobi"),"O":("Acik Ofis","ofis"),"a":("Kuzey Koridor","koridor"),
 "A":("Arsiv","arsiv"),"b":("Dikey Koridor","koridor"),"V":("Bakim / Jenerator","bakim"),
 "Z":("Kazan Dairesi","kazan"),"c":("Orta Koridor","koridor"),"T":("Toplanti","toplanti"),
 "W":("Islak Koridor","islak"),"P":("Otopark / Depo","otopark"),"d":("Guney Koridor","koridor"),
 "N":("Yaratigin Ini","yaratik"),"E":("CIKIS","cikis") }

# Kanat B — FARKLI tasarim (ayna DEGIL): kendine ozgu "merdiven" koridor agi (3 yatay + 2 dikey
# ray) + farkli oda boyut/dizilimi, arastirma/tip/lojistik temasi. B-yerel koord; DX_B ile otelenir.
# Cizim sirasi: once odalar, sonra yatay koridorlar, EN SON dikey raylar (kesisimleri kazansin).
B_BASE=[
 ("G",[(1,8,1,10)]),    ("S",[(1,8,12,21)]),  ("L",[(1,8,23,31)]),     # ust bant odalar
 ("Y",[(11,19,3,11)]),  ("U",[(11,19,13,21)]),("C",[(11,19,23,29)]),   # orta-ust bant
 ("Q",[(22,30,3,11)]),  ("X",[(22,30,13,21)]),("I",[(22,30,23,29)]),   # orta-alt bant
 ("J",[(33,40,1,14)]),  ("K",[(33,40,16,31)]),                          # alt bant
 ("p",[(9,10,1,31)]),   ("q",[(20,21,1,31)]), ("s",[(31,32,1,31)]),     # yatay raylar
 ("e",[(9,32,1,2)]),    ("r",[(9,32,30,31)]),                           # dikey raylar (en son)
]
B_META={ "G":("Ikinci Lobi","lobi"),"S":("Sunucu Odasi","lab"),"L":("Laboratuvar","lab"),
 "Y":("Revir","ofis"),"U":("Yemekhane","toplanti"),"C":("Kontrol Odasi","ofis"),
 "Q":("Karantina","islak"),"X":("Ambar","otopark"),"I":("Sizinti Odasi","islak"),
 "J":("Morg","morg"),"K":("Atik Isleme","kazan"),
 "p":("B-Kuzey Koridor","koridor"),"q":("B-Orta Koridor","koridor"),"s":("B-Guney Koridor","koridor"),
 "e":("Bati Koridor","koridor"),"r":("Dogu Koridor","koridor") }

def shift(rects,dx,dj):
    return [(i0,i1,j0+dj,j1+dj) for (i0,i1,j0,j1) in rects]

BOLGE=[]   # (id, ad, tema, rects)
for (aid,rects) in A_BASE:
    nm,th=A_META[aid]; BOLGE.append((aid,nm,th,rects))
for (bid_,rects) in B_BASE:
    nm,th=B_META[bid_]; BOLGE.append((bid_,nm,th,shift(rects,0,DX_B)))
BOLGE.append(("M","Gecit Koridoru","koridor",[(20,21,35,DX_B+1)]))   # A Orta <-> B

GRID=[['.' for _ in range(W)] for _ in range(H)]
ODA={}; TEMA_OF={}; _hc={}
for (rid_,nm,th,rects) in BOLGE:
    zem,renk=THEME[th]
    ODA[rid_]=(nm,zem,renk,th); TEMA_OF[rid_]=th; cs=[]
    for (i0,i1,j0,j1) in rects:
        for i in range(i0,i1+1):
            for j in range(j0,j1+1):
                if 0<=i<H and 0<=j<W: GRID[i][j]=rid_; cs.append((i,j))
    _hc[rid_]=cs
NR,NC=H,W

# KAPILAR: A + B + gecit
A_KAP=[("R","a"),("O","a"),("a","A"),("a","b"),("b","V"),("V","Z"),("b","c"),
       ("c","T"),("c","W"),("c","P"),("W","P"),("W","d"),("P","d"),("d","N"),("N","E")]
B_KAP=[("G","p"),("S","p"),("L","p"),("Y","e"),("U","p"),("C","r"),
       ("Q","e"),("X","q"),("I","r"),("J","s"),("K","s"),
       ("p","e"),("p","r"),("q","e"),("q","r"),("s","e"),("s","r")]   # merdiven koridor agi
KAPILAR = A_KAP + B_KAP + [("c","M"),("M","e")]   # gecit: A Orta Koridor <-> M <-> B Bati Koridor
KAPI_SET=set(tuple(sorted(p)) for p in KAPILAR)

def cell_center(i,j): return (j*CELL,i*CELL)
def rid(i,j):
    if 0<=i<NR and 0<=j<NC and GRID[i][j]!='.': return GRID[i][j]
    return None
def _bb(r):
    cs=_hc[r]; ii=[c[0] for c in cs]; jj=[c[1] for c in cs]; return min(ii),max(ii),min(jj),max(jj)

instances=[]; lights=[]; stains=[]; door_edges_bp=[]; wall_segs_bp=[]
def add_inst(part,x,z,rot=0.0,y=Y0,scale=(1,1,1),col=None):
    instances.append({"part":part,"pos":[round(x,3),round(y,3),round(z,3)],
                      "rot":round(rot,2),"scale":[round(s,4) for s in scale],"col":col})

# ZEMIN + TAVAN + LAMBA + ISIK
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        add_inst(FLOOR_TEX[ODA[r][1]], x,z,0.0,y=Y0,col=[4,0.12,4,0.0])
        add_inst("Tavan2", x,z,0.0,y=Y0+WALL_H)
        add_inst("EndustriyelLamba", x,z,90.0 if (i+j)%2 else 0.0,y=Y0+WALL_H-0.28)
        if i%3==1 and j%3==1:               # ISIK OPT (Faz2): 9 hucrede 1 gercek isik
            col_,en_,rng_=ISIK[ODA[r][3]]
            lights.append({"pos":[x,Y0+WALL_H-0.5,z],"color":col_,"energy":en_*2.6,"range":rng_*1.5})

# DUVAR + KAPI (kenar bazli; KAPI_SET ciftlerinde kapi)
_ind=set(r for r in TEMA_OF if TEMA_OF[r] in ("bakim","kazan","yaratik","arsiv","islak","lab","morg"))
def wall_part_for(a,b): return "Duvar2" if ({a,b}&_ind) else "Duvar"
def edge_door(a,b): return (a is not None and b is not None and tuple(sorted((a,b))) in KAPI_SET)
def edge_geom(kind,i,j): return (j*CELL-2,i*CELL,90.0) if kind=='V' else (j*CELL,i*CELL-2,0.0)
def seg_bp(kind,x,z): return (x,z-2,x,z+2) if kind=='V' else (x-2,z,x+2,z)
def place_wall(x,z,rot,part): add_inst(part,x,z,rot,y=Y0,col=[4,3,0.2,1.5]); wall_segs_bp.append(seg_bp('V' if abs(rot-90)<1 else 'H',x,z))
def place_door(x,z,rot,part):
    add_inst("Kapi",x,z,rot,y=Y0)
    off=DOOR_W/2+FILL_W/2; sx=FILL_W/CELL; lnt_sx=DOOR_W/CELL; lnt_sy=1.0/WALL_H
    if abs(rot-90)<1 or abs(rot-270)<1:
        add_inst(part,x,z+off,rot,y=Y0,scale=(sx,1,1),col=[4,3,0.2,1.5])
        add_inst(part,x,z-off,rot,y=Y0,scale=(sx,1,1),col=[4,3,0.2,1.5])
    else:
        add_inst(part,x+off,z,rot,y=Y0,scale=(sx,1,1),col=[4,3,0.2,1.5])
        add_inst(part,x-off,z,rot,y=Y0,scale=(sx,1,1),col=[4,3,0.2,1.5])
    add_inst(part,x,z,rot,y=Y0+2.0,scale=(lnt_sx,lnt_sy,1),col=[4,3,0.2,1.5])
for i in range(NR):
    for j in range(NC+1):
        L,R=rid(i,j-1),rid(i,j)
        if L==R and L is not None: continue
        if L is None and R is None: continue
        x,z,rot=edge_geom('V',i,j); part=wall_part_for(L,R)
        if edge_door(L,R): place_door(x,z,rot,part); door_edges_bp.append((x,z,False))
        else: place_wall(x,z,rot,part)
for i in range(NR+1):
    for j in range(NC):
        T,B=rid(i-1,j),rid(i,j)
        if T==B and T is not None: continue
        if T is None and B is None: continue
        x,z,rot=edge_geom('H',i,j); part=wall_part_for(T,B)
        if edge_door(T,B): place_door(x,z,rot,part); door_edges_bp.append((x,z,True))
        else: place_wall(x,z,rot,part)

# OBJELER (tema bazli)
OBJELER=[]
def _o(part,i,j,dx,dz,rot,scale=None): OBJELER.append((part,(i,j),(dx,dz),rot)+((scale,) if scale else ()))
def themed(r):
    th=TEMA_OF[r]; i0,i1,j0,j1=_bb(r); cI,cJ=(i0+i1)//2,(j0+j1)//2
    hi=(i1-i0)>=3; wi=(j1-j0)>=3
    if th=="koridor":
        cs=_hc[r]; _o("GuvenlikKamerasi",cs[0][0],cs[0][1],0,0,90); _o("GuvenlikKamerasi",cs[-1][0],cs[-1][1],0,0,270)
        for k in range(3,len(cs),6): _o("Mazgal",cs[k][0],cs[k][1],0,0,0); return
    if th in ("lobi",):
        if hi and wi:
            for s,(ci,cj) in zip(["Sutun1","Sutun2","Sutun3","Sutun1"],[(i0+1,j0+1),(i0+1,j1-1),(i1-1,j0+1),(i1-1,j1-1)]):
                _o(s,ci,cj,0,0,0,(1.3,2.85,1.3))
        _o("GuvenlikKamerasi",i0,j0,1.4,-1.4,135); _o("CopKutusu",i1,cJ,0.6,0.8,0)
    elif th in ("ofis",):
        _o("ElektrikPanosu",i0,j1,1.4,0,270); _o("CopKutusu",i0+1,j0+1,0,0,0); _o("CopKutusu",i1,j1,0,0,0)
    elif th=="arsiv":
        _o("ElektrikPanosu",i0,j0,1.4,0,270); _o("CopKutusu",i1,j1,0,0,0); _o("CopKutusu",cI,j0,1.0,0,0)
    elif th=="bakim":
        _o("ElektrikPanosu",i0,j0,0,-1.4,180); _o("ElektrikPanosu",i0,min(j0+2,j1),0,-1.4,180); _o("Mazgal",cI,cJ,0,0,0); _o("CopKutusu",i1,j1,0,0,0)
    elif th=="kazan":
        _o("ElektrikPanosu",i1,j0,-1.4,0,90); _o("ElektrikPanosu",i1,j1,1.4,0,270); _o("Mazgal",cI,cJ,0,0,0)
    elif th=="toplanti":
        _o("CopKutusu",i0,j0,0,0,0); _o("CopKutusu",i1,j1,0,0,0); _o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,225)
    elif th=="islak":
        for k,(ci,cj) in enumerate(_hc[r]):
            if k%3==0: _o("Mazgal",ci,cj,0,0,0)
    elif th=="otopark":
        _o("GuvenlikKamerasi",i0,j0,1.4,-1.4,135); _o("CopKutusu",i1,j0+1,0,0,0); _o("CopKutusu",i1,j1-1,0,0,0); _o("Mazgal",cI,cJ,0,0,0)
    elif th=="lab":
        _o("ElektrikPanosu",i0,j0,0,-1.4,180); _o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,225); _o("CopKutusu",i1,j0,0,0,0)
    elif th=="morg":
        for (ci,cj) in [(i0,j0),(i1,j1),(cI,cJ)]: _o("Mazgal",ci,cj,0,0,0)
        _o("GuvenlikKamerasi",i0,j0,1.4,-1.4,120)
    elif th=="yaratik":
        _o("Canavar",i1-1,cJ,0,0,200)
        for (ci,cj) in [(i0,j0+1),(i0,j1-1),(cI,j0),(cI,j1)]: _o("Mazgal",ci,cj,0,0,0)
        _o("GuvenlikKamerasi",i0,j0,1.4,-1.4,120); _o("CopKutusu",i1,j0,0,0,0)
    elif th=="cikis":
        _o("GuvenlikKamerasi",i0,j1,-1.4,-1.4,250)
for r in ODA: themed(r)
for o in OBJELER:
    part,(i,j),(dx,dz),rot=o[0],o[1],o[2],o[3]
    scl=tuple(o[4]) if len(o)>4 else (1,1,1)
    x,z=cell_center(i,j); meta=PARTS[part]; y=Y0
    if part=="GuvenlikKamerasi": y=Y0+WALL_H-1.0
    col=None
    if meta.get("col"): cs=meta["col"]; col=[cs[0],cs[1],cs[2],cs[1]/2.0]
    add_inst(part,x+dx,z+dz,float(rot),y=y,scale=scl,col=col)

# LEKE (desenli: duvar dipleri)
random.seed(7)
floor_cells=[(i,j) for i in range(NR) for j in range(NC) if rid(i,j)]
for idx,(x0,z0,x1,z1) in enumerate(wall_segs_bp):
    if idx%2: continue
    mx,mz=(x0+x1)/2.0,(z0+z1)/2.0
    stains.append({"pos":[round(mx,2),Y0+0.07,round(mz,2)],"normal":[0,1,0],
                   "size":round(0.6+(idx%5)*0.18,2),"tex":"lekeler/leke_%02d"%((idx%16)+1),"rot":float((idx*47)%360)})

# SPAWN (A Resepsiyon ortasi)
sx,sz=cell_center(3,5); spawn=[sx,Y0+1.0,sz]

plan={"cell":CELL,"wall_h":WALL_H,"y0":Y0,"nr":NR,"nc":NC,"parts_meta":PARTS,
      "instances":instances,"lights":lights,"stains":stains,"spawn":spawn,
      "grid":["".join(r) for r in GRID],"rooms":{r:[ODA[r][0],ODA[r][1]] for r in ODA}}
with open(os.path.join(OUT,"dunya_plan.json"),"w") as f: json.dump(plan,f,indent=1)
print("instances:",len(instances),"lights:",len(lights),"oda:",len([r for r in ODA if TEMA_OF[r]!='koridor']),
      "koridor:",len([r for r in ODA if TEMA_OF[r]=='koridor']),"kapi:",sum(1 for _ in door_edges_bp))

# ===================================================== KROKI (50d8415 stili: isimli + lamba noktalari + lejant)
def room_cells(r): return _hc.get(r,[])
fig,ax=plt.subplots(figsize=(20,11)); ax.set_facecolor("#f7f5ef")
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        ax.add_patch(Rectangle((x-2,z-2),CELL,CELL,facecolor=ODA[r][2],edgecolor="#bcb7a8",lw=0.5,zorder=1))
for r in ODA:
    cs=room_cells(r)
    if not cs: continue
    cx=sum(cell_center(i,j)[0] for i,j in cs)/len(cs); cz=sum(cell_center(i,j)[1] for i,j in cs)/len(cs)
    ax.text(cx,cz-0.35,ODA[r][0],ha="center",va="center",fontsize=8.5,weight="bold",color="#2b2b2b",zorder=5)
    ax.text(cx,cz+0.8,"%d m2"%(len(cs)*16),ha="center",va="center",fontsize=6.5,color="#555",zorder=5)
for x0,z0,x1,z1 in wall_segs_bp:
    ax.plot([x0,x1],[z0,z1],color="#1c1c1c",lw=4,solid_capstyle="butt",zorder=6)
for x,z,yatay in door_edges_bp:
    if yatay:
        ax.plot([x-DOOR_W/2,x+DOOR_W/2],[z,z],color="#f7f5ef",lw=5,zorder=7)
        ax.add_patch(Arc((x-DOOR_W/2,z),DOOR_W*2,DOOR_W*2,theta1=0,theta2=80,color="#8a6d3b",lw=1,zorder=8))
    else:
        ax.plot([x,x],[z-DOOR_W/2,z+DOOR_W/2],color="#f7f5ef",lw=5,zorder=7)
        ax.add_patch(Arc((x,z-DOOR_W/2),DOOR_W*2,DOOR_W*2,theta1=10,theta2=90,color="#8a6d3b",lw=1,zorder=8))
OBJ_STYLE={"CopKutusu":("o","#3b7a3b","Cop Kutusu"),"ElektrikPanosu":("s","#b5651d","Elektrik Panosu"),
           "GuvenlikKamerasi":("^","#b00020","Guvenlik Kamerasi"),"Mazgal":("P","#3a3a3a","Mazgal"),
           "Canavar":("X","#cc0033","CANAVAR"),"Sutun1":("H","#7d828b","Sutun"),
           "Sutun2":("H","#7d828b","Sutun"),"Sutun3":("H","#7d828b","Sutun")}
for o in OBJELER:
    part,(i,j),(dx,dz),rot=o[0],o[1],o[2],o[3]
    if part not in OBJ_STYLE: continue
    x,z=cell_center(i,j); m,c,lab=OBJ_STYLE[part]
    ax.scatter([x+dx],[z+dz],marker=m,s=(150 if part=="Canavar" else 80),color=c,edgecolor="white",lw=0.6,zorder=9)
for i,j in floor_cells:
    x,z=cell_center(i,j); ax.scatter([x],[z],marker="*",s=22,color="#d4a017",alpha=0.45,zorder=4)
ax.scatter([spawn[0]],[spawn[2]],marker="X",s=170,color="#0050b3",edgecolor="white",lw=1,zorder=10)
ax.text(spawn[0],spawn[2]-0.9,"BASLANGIC",ha="center",fontsize=8,color="#0050b3",weight="bold",zorder=10)
ax.set_xlim(-4,NC*CELL); ax.set_ylim(NR*CELL,-4); ax.set_aspect("equal"); ax.set_xlabel("X (m)"); ax.set_ylabel("Z (m)")
ax.set_title("BACKROOMS — ZEMIN KAT (2 KANAT: A + Gecit + B)\n%d oda · %d m2 · iki farkli kanat yan yana"%(
    len([r for r in ODA if TEMA_OF[r]!='koridor']), len(floor_cells)*16), fontsize=14, weight="bold")
leg=[]
seen=set()
for (m,c,lab) in OBJ_STYLE.values():
    if lab in seen: continue
    seen.add(lab); leg.append(Line2D([0],[0],marker=m,color="w",markerfacecolor=c,markersize=10,label=lab))
leg.append(Line2D([0],[0],color="#1c1c1c",lw=4,label="Duvar"))
leg.append(Line2D([0],[0],marker="X",color="w",markerfacecolor="#0050b3",markersize=11,label="Baslangic"))
ax.legend(handles=leg,loc="upper left",bbox_to_anchor=(1.005,1.0),fontsize=8,frameon=True)
plt.tight_layout()
fig.savefig(os.path.join(OUT,"krokiler","kat_zemin.png"),dpi=120,bbox_inches="tight")
print("KROKI ->",os.path.join(OUT,"krokiler","kat_zemin.png"))
