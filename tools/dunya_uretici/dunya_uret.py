# -*- coding: utf-8 -*-
# Backrooms - DUNYA URETICI (TASARLANMIS organik: koridor agi + oto bolunmus odalar)
#   python3 tools/dunya_uretici/dunya_uret.py -> dunya_plan.json + krokiler/kat_zemin.png
#
# YAKLASIM: Koridor agi EL ILE tasarlandi (duzensiz/uneven + loop'lu + spur'lu -> organik,
# izgara DEGIL, rastgele DEGIL). Koridor disi bosluklar otomatik ODALARA bolunur (flood-fill)
# -> COK sayida, degisken boyutlu, hepsi koridora bagli oda. Koridor SERBEST gezilir,
# odalara OTO kapi, salonlar kapisiz acilir. Bol ara-baglanti (loop).

import json, os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Arc
from matplotlib.lines import Line2D
from collections import defaultdict, deque

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
# tema -> (ad_kok, zemin, kroki_renk, [isik_renk,enerji,menzil])
TEMA={
 "lobi":("Resepsiyon","g","#cdd3da",[[1.00,0.96,0.88],3.0,7.0]),
 "salon":("Salon","g","#cfd6dd",[[0.96,0.94,0.86],2.7,7.2]),
 "ofis":("Ofis","f","#e7ded0",[[1.00,0.90,0.60],2.2,6.0]),
 "depo":("Depo","f","#ded6c6",[[0.80,0.78,0.62],1.4,5.4]),
 "arsiv":("Arsiv","f","#d8cdb6",[[0.92,0.74,0.50],1.3,5.0]),
 "bakim":("Bakim","g","#aebfae",[[0.55,0.95,0.68],2.0,6.0]),
 "kazan":("Kazan Dairesi","g","#c2a594",[[1.00,0.55,0.28],1.8,5.6]),
 "lab":("Laboratuvar","g","#bcd0cf",[[0.70,0.95,0.95],2.0,6.0]),
 "wc":("Tuvalet","f","#cdd6c8",[[0.86,0.90,0.84],1.6,5.0]),
 "islak":("Islak Koridor",".","#aeb7c2",[[0.48,0.60,0.80],1.1,4.8]),
 "yaratik":("Yaratigin Ini",".","#c89a96",[[0.95,0.32,0.28],1.1,5.2]),
 "cikis":("CIKIS","g","#9fdcb0",[[0.55,1.00,0.70],3.4,7.6]),
 "koridor":("Koridor",".","#cdd2bc",[[0.84,0.86,0.94],1.7,5.8]),
}

# ===================================================== KORIDOR AGI (el ile, organik/uneven + loop)
H,W=60,56
GRID=[['.' for _ in range(W)] for _ in range(H)]
def stamp(i0,i1,j0,j1,ch='c'):
    for i in range(max(0,i0),min(H,i1+1)):
        for j in range(max(0,j0),min(W,j1+1)): GRID[i][j]=ch
# yatay koridorlar (uneven, kismi) -> tam izgara DEGIL, sik
for (i0,i1,j0,j1) in [(7,8,2,53),(14,15,14,53),(21,22,2,45),(28,29,11,53),(34,35,2,41),(40,41,28,53),(46,47,2,47),(51,52,2,53)]:
    stamp(i0,i1,j0,j1)
# dikey koridorlar (uneven, kismi) -> sik
for (i0,i1,j0,j1) in [(7,52,2,3),(7,29,9,10),(14,52,17,18),(7,41,25,26),(21,52,33,34),(7,47,40,41),(28,52,48,49)]:
    stamp(i0,i1,j0,j1)
# ara-baglantilar / spur (loop + organik kivrim, staggered)
for (i0,i1,j0,j1) in [(8,14,46,47),(22,28,21,22),(29,40,43,44),(35,46,15,16),(15,21,30,31),(41,51,25,26),(8,21,52,53),(35,46,52,53)]:
    stamp(i0,i1,j0,j1)

# ===================================================== ODALAR: koridor disi bosluklari otomatik bol
ODA={}; TIP={}; _rect={}; _hc={}
_pool=[ch for ch in "ABDEFGIJKLMNOPQRSTUVWXYZabdefghijkmnopqrstuvwxyz0123456789"]; _pi=0
def _yid():
    global _pi; c=_pool[_pi]; _pi+=1; return c
# 1 hucre ic kenar payi: dis sinir void kalsin
for i in range(H):
    for j in range(W):
        if i==0 or j==0 or i>=H-1 or j>=W-1:
            if GRID[i][j]=='.': pass
# flood: ic (1..H-2,1..W-2) non-koridor bilesenler
seen=[[False]*W for _ in range(H)]
comps=[]
for si in range(1,H-1):
    for sj in range(1,W-1):
        if GRID[si][sj]!='.' or seen[si][sj]: continue
        cells=[]; q=deque([(si,sj)]); seen[si][sj]=True
        while q:
            i,j=q.popleft(); cells.append((i,j))
            for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
                ni,nj=i+di,j+dj
                if 1<=ni<H-1 and 1<=nj<W-1 and not seen[ni][nj] and GRID[ni][nj]=='.':
                    seen[ni][nj]=True; q.append((ni,nj))
        comps.append(cells)
# kucuk slivar bilesenleri koridora kat (mikro-oda olmasin)
rooms=[]
for cells in comps:
    if len(cells)<5:
        for (i,j) in cells: GRID[i][j]='c'
    else:
        rooms.append(cells)

def _bbx(cells):
    ii=[c[0] for c in cells]; jj=[c[1] for c in cells]
    return min(ii),max(ii),min(jj),max(jj)
def _zone(i0,i1):
    fr=((i0+i1)/2.0)/H
    if fr<0.30: return ["ofis","ofis","depo","arsiv","wc"]
    if fr<0.55: return ["arsiv","depo","ofis","lab","bakim"]
    if fr<0.78: return ["bakim","lab","depo","islak","kazan"]
    return ["kazan","islak","bakim","depo"]

# ozel odalar: resepsiyon (en ust buyuk), ana salon (en buyuk), yaratik (en alt), cikis (uzak kose)
rooms.sort(key=lambda c:_bbx(c)[0])
import hashlib
def _ci(c): i0,i1,j0,j1=_bbx(c); return ((i0+i1)//2,(j0+j1)//2)
res_idx=0
big_idx=max(range(len(rooms)),key=lambda k:len(rooms[k]))
yar_idx=max(range(len(rooms)),key=lambda k:_ci(rooms[k])[0])
cik_idx=max(range(len(rooms)),key=lambda k:_ci(rooms[k])[0]+_ci(rooms[k])[1])
ozel={res_idx:"lobi"}
if big_idx not in ozel: ozel[big_idx]="salon"
ozel[yar_idx]="yaratik";
if cik_idx not in (yar_idx,res_idx): ozel[cik_idx]="cikis"

ad_say=defaultdict(int)
spawn_cell=creature_cell=exit_cell=None
rng_seed=12345
for k,cells in enumerate(rooms):
    i0,i1,j0,j1=_bbx(cells)
    if k in ozel: th=ozel[k]
    else:
        pool=_zone(i0,i1); th=pool[(i0*7+j0*3+k)%len(pool)]   # deterministik (rastgele degil)
    rid_=_yid()
    tip="salon" if th in("lobi","salon") else "oda"
    ad_say[th]+=1
    ad=TEMA[th][0]+("" if th in("lobi","cikis","yaratik","salon") or ad_say[th]==1 else " %d"%ad_say[th])
    ODA[rid_]=(th,ad); TIP[rid_]=tip; _rect[rid_]=(i0,i1,j0,j1); _hc[rid_]=cells
    for (i,j) in cells: GRID[i][j]=rid_
    cI,cJ=_ci(cells)
    if th=="lobi": spawn_cell=(cI,cJ)
    elif th=="yaratik": creature_cell=(min(i1, max(i0, i1-1)),cJ)
    elif th=="cikis": exit_cell=(cI,cJ)

NR,NC=H,W
TEMA_OF={r:ODA[r][0] for r in ODA}
def cell_center(i,j): return (j*CELL,i*CELL)
def rid(i,j):
    if 0<=i<NR and 0<=j<NC and GRID[i][j]!='.': return GRID[i][j]
    return None
def theme_of(r): return "koridor" if r=='c' else TEMA_OF.get(r,"koridor")
def name_of(r): return "Koridor" if r=='c' else ODA[r][1]
def floor_of(r): return FLOOR_TEX[TEMA[theme_of(r)][1]]

instances=[]; lights=[]; stains=[]; door_edges_bp=[]; wall_segs_bp=[]
def add_inst(part,x,z,rot=0.0,y=Y0,scale=(1,1,1),col=None):
    instances.append({"part":part,"pos":[round(x,3),round(y,3),round(z,3)],
                      "rot":round(rot,2),"scale":[round(s,4) for s in scale],"col":col})

for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        add_inst(floor_of(r),x,z,0.0,y=Y0,col=[4,0.12,4,0.0])
        add_inst("Tavan2",x,z,0.0,y=Y0+WALL_H)
        add_inst("EndustriyelLamba",x,z,90.0 if (i+j)%2 else 0.0,y=Y0+WALL_H-0.28)
        if i%2==0 and j%2==0:
            col_,en_,rng_=TEMA[theme_of(r)][3]
            lights.append({"pos":[x,Y0+WALL_H-0.5,z],"color":col_,"energy":en_*1.7,"range":rng_*1.15})

WALK={"koridor","salon"}
_ind=set(r for r in TEMA_OF if theme_of(r) in("bakim","kazan","yaratik","arsiv","islak","lab"))
def wall_part_for(a,b): return "Duvar2" if ({a,b}&_ind) else "Duvar"
duvar_edges=[]; aday={}; oda_aday=defaultdict(list)
def _tip(r): return "koridor" if r=='c' else TIP.get(r)
def _kenar(kind,i,j,a,b):
    if a==b: return
    if a is None and b is None: return
    if a is None or b is None: duvar_edges.append((kind,i,j,a,b)); return
    ta,tb=_tip(a),_tip(b)
    if ta in WALK and tb in WALK: return
    if ta=="oda" and tb=="oda": duvar_edges.append((kind,i,j,a,b)); return
    oda=a if ta=="oda" else b
    grup=('V',j) if kind=='V' else ('H',i); sira=i if kind=='V' else j
    aday[(kind,i,j)]=(a,b); oda_aday[oda].append((kind,i,j,grup,sira))
for i in range(NR):
    for j in range(NC+1): _kenar('V',i,j,rid(i,j-1),rid(i,j))
for i in range(NR+1):
    for j in range(NC): _kenar('H',i,j,rid(i-1,j),rid(i,j))
kapi_edges=set()
for oda,ad in oda_aday.items():
    gr=defaultdict(list)
    for e in ad: gr[e[3]].append(e)
    sr=sorted(gr.values(),key=lambda g:-len(g))
    nk=2 if (len(_hc[oda])>=55 and len(sr)>=2) else 1
    for g in sr[:nk]:
        g2=sorted(g,key=lambda e:e[4]); mid=g2[len(g2)//2]; kapi_edges.add((mid[0],mid[1],mid[2]))
def edge_geom(kind,i,j): return (j*CELL-2,i*CELL,90.0) if kind=='V' else (j*CELL,i*CELL-2,0.0)
def seg_bp(kind,x,z): return (x,z-2,x,z+2) if kind=='V' else (x-2,z,x+2,z)
def place_wall(x,z,rot,part): add_inst(part,x,z,rot,y=Y0,col=[4,3,0.2,1.5])
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
for (kind,i,j) in list(aday.keys()):
    a,b=aday[(kind,i,j)]; x,z,rot=edge_geom(kind,i,j); part=wall_part_for(a,b)
    if (kind,i,j) in kapi_edges: place_door(x,z,rot,part); door_edges_bp.append((x,z,kind=='H'))
    else: place_wall(x,z,rot,part); wall_segs_bp.append(seg_bp(kind,x,z))
for (kind,i,j,a,b) in duvar_edges:
    x,z,rot=edge_geom(kind,i,j); part=wall_part_for(a,b)
    place_wall(x,z,rot,part); wall_segs_bp.append(seg_bp(kind,x,z))

# OBJELER (tema bazli, ROOM hucrelerine - void'e tasmaz)
OBJELER=[]
def _o(part,i,j,rot,scale=None): OBJELER.append((part,(i,j),rot)+((scale,) if scale else ()))
def _anchors(cells):
    s=sorted(cells); n=len(s)
    return {"tl":s[0],"br":s[-1],"mid":s[n//2],"q1":s[n//4],"q3":s[(3*n)//4]}
def themed(th,cells):
    a=_anchors(cells)
    if th in("lobi","salon"):
        for key,part in [("tl","Sutun1"),("br","Sutun2"),("q1","Sutun3"),("q3","Sutun1")]:
            i,j=a[key]; _o(part,i,j,0,(1.3,2.85,1.3))
        i,j=a["mid"]; _o("GuvenlikKamerasi",i,j,135)
    elif th=="ofis":
        i,j=a["tl"]; _o("ElektrikPanosu",i,j,180); i,j=a["br"]; _o("CopKutusu",i,j,0)
    elif th=="depo":
        i,j=a["tl"]; _o("CopKutusu",i,j,0); i,j=a["br"]; _o("CopKutusu",i,j,0); i,j=a["mid"]; _o("ElektrikPanosu",i,j,90)
    elif th=="arsiv":
        i,j=a["tl"]; _o("ElektrikPanosu",i,j,270); i,j=a["mid"]; _o("CopKutusu",i,j,0)
    elif th=="bakim":
        i,j=a["tl"]; _o("ElektrikPanosu",i,j,180); i,j=a["q1"]; _o("ElektrikPanosu",i,j,180); i,j=a["mid"]; _o("Mazgal",i,j,0)
    elif th=="kazan":
        i,j=a["tl"]; _o("ElektrikPanosu",i,j,90); i,j=a["mid"]; _o("Mazgal",i,j,0); i,j=a["br"]; _o("Mazgal",i,j,0)
    elif th=="lab":
        i,j=a["tl"]; _o("ElektrikPanosu",i,j,180); i,j=a["mid"]; _o("GuvenlikKamerasi",i,j,200)
    elif th=="wc":
        i,j=a["mid"]; _o("CopKutusu",i,j,0)
    elif th=="islak":
        i,j=a["tl"]; _o("Mazgal",i,j,0); i,j=a["br"]; _o("Mazgal",i,j,0)
    elif th=="yaratik":
        for key in ("tl","br","q1","q3","mid"):
            i,j=a[key]; _o("Mazgal",i,j,0)
        i,j=a["tl"]; _o("GuvenlikKamerasi",i,j,120)
    elif th=="cikis":
        i,j=a["mid"]; _o("GuvenlikKamerasi",i,j,250)
for r in ODA: themed(theme_of(r),_hc[r])
if creature_cell: _o("Canavar",creature_cell[0],creature_cell[1],200)
cor=[(i,j) for i in range(NR) for j in range(NC) if GRID[i][j]=='c']
for k in range(0,len(cor),21): _o("Mazgal",cor[k][0],cor[k][1],0)

for o in OBJELER:
    part,(i,j),rot=o[0],o[1],o[2]; scl=tuple(o[3]) if len(o)>3 else (1,1,1)
    x,z=cell_center(i,j); meta=PARTS[part]; y=Y0
    if part=="GuvenlikKamerasi": y=Y0+WALL_H-1.0
    col=None
    if meta.get("col"): cs=meta["col"]; col=[cs[0],cs[1],cs[2],cs[1]/2.0]
    add_inst(part,x,z,float(rot),y=y,scale=scl,col=col)

for idx,(x0,z0,x1,z1) in enumerate(wall_segs_bp):
    if idx%2: continue
    mx,mz=(x0+x1)/2.0,(z0+z1)/2.0
    stains.append({"pos":[round(mx,2),Y0+0.07,round(mz,2)],"normal":[0,1,0],
                   "size":round(0.6+(idx%5)*0.18,2),"tex":"lekeler/leke_%02d"%((idx%16)+1),"rot":float((idx*47)%360)})
for r in ODA:
    i0,i1,j0,j1=_rect[r]; cx,cz=cell_center((i0+i1)//2,(j0+j1)//2)
    stains.append({"pos":[round(cx,2),Y0+0.07,round(cz,2)],"normal":[0,1,0],
                   "size":1.1,"tex":"lekeler/leke_%02d"%((abs(hash(r))%16)+1),"rot":float(abs(hash(r))%360)})

if spawn_cell is None: spawn_cell=cor[0] if cor else (2,2)
sx,sz=cell_center(*spawn_cell); spawn=[sx,Y0+1.0,sz]

plan={"cell":CELL,"wall_h":WALL_H,"y0":Y0,"nr":NR,"nc":NC,"parts_meta":PARTS,
      "instances":instances,"lights":lights,"stains":stains,"spawn":spawn,
      "grid":["".join(r) for r in GRID],"rooms":{r:[name_of(r),floor_of(r)] for r in ODA}}
with open(os.path.join(OUT,"dunya_plan.json"),"w") as f: json.dump(plan,f,indent=1)
# baglilik
def _wk(i,j):
    if not(0<=i<H and 0<=j<W): return False
    g=GRID[i][j]; return g=='c' or (g!='.' and TIP.get(g)=="salon")
st=next(((i,j) for i in range(H) for j in range(W) if GRID[i][j]=='c'),None)
rset=set()
if st:
    rset.add(st); q=deque([st])
    while q:
        i,j=q.popleft()
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            if _wk(i+di,j+dj) and (i+di,j+dj) not in rset: rset.add((i+di,j+dj)); q.append((i+di,j+dj))
unreach=[r for r in ODA if not any((i+di,j+dj) in rset for (i,j) in _hc[r] for di,dj in((0,1),(0,-1),(1,0),(-1,0)))]
print("instances:",len(instances),"lights:",len(lights),"oda:",len(ODA),
      "kapi:",len(kapi_edges),"koridor tek-parca:", len(rset)==sum(1 for i in range(H) for j in range(W) if _wk(i,j)),
      "erisilemez:",unreach or "YOK")

# ===================================================== KROKI (okunakli, isimli)
fig,ax=plt.subplots(figsize=(16,17)); ax.set_facecolor("#f6f4ee")
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j)
        ax.add_patch(Rectangle((x-2,z-2),CELL,CELL,facecolor=TEMA[theme_of(r)][2],edgecolor="#cfcabd",lw=0.25,zorder=1))
for r in ODA:
    i0,i1,j0,j1=_rect[r]; cx,cz=cell_center((i0+i1)//2,(j0+j1)//2)
    ax.text(cx,cz,name_of(r),ha="center",va="center",fontsize=6.2,color="#222",zorder=5)
for x0,z0,x1,z1 in wall_segs_bp:
    ax.plot([x0,x1],[z0,z1],color="#1c1c1c",lw=2.6,solid_capstyle="butt",zorder=6)
for x,z,yatay in door_edges_bp:
    if yatay:
        ax.plot([x-DOOR_W/2,x+DOOR_W/2],[z,z],color="#f6f4ee",lw=3.5,zorder=7)
        ax.add_patch(Arc((x-DOOR_W/2,z),DOOR_W*2,DOOR_W*2,theta1=0,theta2=80,color="#8a6d3b",lw=0.8,zorder=8))
    else:
        ax.plot([x,x],[z-DOOR_W/2,z+DOOR_W/2],color="#f6f4ee",lw=3.5,zorder=7)
        ax.add_patch(Arc((x,z-DOOR_W/2),DOOR_W*2,DOOR_W*2,theta1=10,theta2=90,color="#8a6d3b",lw=0.8,zorder=8))
ST={"CopKutusu":("o","#3b7a3b","Cop"),"ElektrikPanosu":("s","#b5651d","Pano"),
    "GuvenlikKamerasi":("^","#b00020","Kamera"),"Mazgal":("P","#3a3a3a","Mazgal"),
    "Canavar":("X","#cc0033","CANAVAR"),"Sutun1":("H","#7d828b","Sutun"),
    "Sutun2":("H","#7d828b","Sutun"),"Sutun3":("H","#7d828b","Sutun")}
for o in OBJELER:
    part,(i,j),rot=o[0],o[1],o[2]
    if part not in ST: continue
    x,z=cell_center(i,j); m,c,_=ST[part]
    ax.scatter([x],[z],marker=m,s=(150 if part=="Canavar" else 42),color=c,edgecolor="white",lw=0.5,zorder=9)
ax.scatter([spawn[0]],[spawn[2]],marker="*",s=240,color="#0050b3",edgecolor="white",lw=1,zorder=10)
ax.text(spawn[0],spawn[2]-1.6,"BASLANGIC",ha="center",fontsize=9,color="#0050b3",weight="bold",zorder=10)
ax.set_xlim(-4,NC*CELL); ax.set_ylim(NR*CELL,-4); ax.set_aspect("equal"); ax.axis("off")
ax.set_title("BACKROOMS 'CIKIS YOK' — ZEMIN KAT\n%d oda | %d m2 | organik koridor agi (acik), odalar kapili, bol baglanti"%(
    len(ODA), (sum(len(c) for c in _hc.values())+len(cor))*16),fontsize=13,weight="bold")
leg=[Line2D([0],[0],marker=m,color="w",markerfacecolor=c,markersize=9,label=l) for (m,c,l) in
     {("^","#b00020","Kamera"),("o","#3b7a3b","Cop"),("s","#b5651d","Pano"),("P","#3a3a3a","Mazgal"),
      ("X","#cc0033","CANAVAR"),("H","#7d828b","Sutun")}]
leg.append(Line2D([0],[0],color="#1c1c1c",lw=3,label="Duvar"))
leg.append(Line2D([0],[0],marker="*",color="w",markerfacecolor="#0050b3",markersize=12,label="Baslangic"))
ax.legend(handles=leg,loc="upper left",bbox_to_anchor=(1.01,1.0),fontsize=8,frameon=True)
plt.tight_layout()
fig.savefig(os.path.join(OUT,"krokiler","kat_zemin.png"),dpi=110,bbox_inches="tight")
print("KROKI ->",os.path.join(OUT,"krokiler","kat_zemin.png"))
