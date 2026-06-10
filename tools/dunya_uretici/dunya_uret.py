# -*- coding: utf-8 -*-
# Backrooms - DUNYA URETICI (DUZENSIZ prosedurel, tohumlu/deterministik)
#   python3 tools/dunya_uretici/dunya_uret.py  -> dunya_plan.json + krokiler/kat_zemin.png
#
# GERCEK BACKROOMS: izgara DEGIL. Tohumlu rastgele COK sayida degisik boyutlu oda +
# aralarinda VOID icinden KIVRILAN koridor agi (MST + ekstra dongu) -> kaotik labirent.
# Koridor SERBEST gezilir, odalara OTO kapi, salonlar kapisiz acilir. Kroki tedirgin edici.

import json, os, random, math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Arc
from collections import defaultdict, deque

PROJE="/home/user/Backrooms"; OUT=os.path.join(PROJE,"tools","dunya_uretici")
CELL,WALL_H,Y0=4.0,3.0,0.0; DOOR_W=1.42; FILL_W=(CELL-DOOR_W)/2.0
SEED=11

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
TEMA={ # tema -> (zemin, kroki_renk, [isik_renk, enerji, menzil])
 "lobi":("g","#3a4250",[ [1.00,0.96,0.88],3.0,7.0 ]),
 "salon":("g","#343c48",[ [0.96,0.94,0.86],2.6,7.2 ]),
 "ofis":("f","#4a4636",[ [1.00,0.90,0.60],2.1,5.8 ]),
 "depo":("f","#43403a",[ [0.80,0.78,0.62],1.3,5.2 ]),
 "arsiv":("f","#473e2e",[ [0.92,0.74,0.50],1.1,4.8 ]),
 "bakim":("g","#2f3e36",[ [0.55,0.95,0.68],1.9,5.8 ]),
 "kazan":("g","#4a2f24",[ [1.00,0.50,0.26],1.7,5.4 ]),
 "islak":(".","#2c3642",[ [0.46,0.58,0.80],1.0,4.4 ]),
 "yaratik":(".","#511f1c",[ [0.95,0.30,0.26],1.0,5.0 ]),
 "cikis":("g","#214a30",[ [0.55,1.00,0.70],3.2,7.2 ]),
 "koridor":(".","#262b25",[ [0.82,0.84,0.92],1.5,5.4 ]),
}

# ============================================================ DUZENSIZ (corridor-first + maze + baglilik onarimi)
rng=random.Random(SEED)
H,W=60,56
GRID=[['c' for _ in range(W)] for _ in range(H)]
for i in range(H):
    for j in range(W):
        if i==0 or j==0 or i>=H-1 or j>=W-1: GRID[i][j]='.'   # dis sinir void
ODA={}; TIP={}; _rect={}; _hc=defaultdict(list)
_pool=[ch for ch in "ABDEFGHIJKLMNOPQRSTUVWXYZabdefghijkmnopqrstuvwxyz0123456789"]; _pi=0
def _yid():
    global _pi; c=_pool[_pi]; _pi+=1; return c
rlist=[]
def _cak(i0,i1,j0,j1,m=1):
    for (a0,a1,b0,b1,_t) in rlist:
        if not (j1+m<b0 or j0-m>b1 or i1+m<a0 or i0-m>a1): return True
    return False
def _zt(i0,i1):
    fr=((i0+i1)/2.0)/H
    if fr<0.30: pp=["ofis","ofis","depo","arsiv"]
    elif fr<0.58: pp=["arsiv","depo","ofis","bakim"]
    elif fr<0.80: pp=["bakim","kazan","islak","depo"]
    else: pp=["kazan","islak","bakim","depo"]
    return rng.choice(pp)
tries=0
while len(rlist)<44 and tries<6000:
    tries+=1
    w=rng.randint(2,8); h=rng.randint(2,7)
    j0=rng.randint(2,W-3-w); i0=rng.randint(2,H-3-h); i1,j1=i0+h,j0+w
    if _cak(i0,i1,j0,j1,1): continue
    rlist.append((i0,i1,j0,j1,_zt(i0,i1)))
rlist.sort(key=lambda r:r[0])
rlist[0]=rlist[0][:4]+("lobi",)
ai=max(range(len(rlist)),key=lambda k:rlist[k][1]); rlist[ai]=rlist[ai][:4]+("yaratik",)
ki=max(range(len(rlist)),key=lambda k:rlist[k][0]+rlist[k][2])
if ki!=ai: rlist[ki]=rlist[ki][:4]+("cikis",)
bk=sorted(range(len(rlist)),key=lambda k:-(rlist[k][1]-rlist[k][0])*(rlist[k][3]-rlist[k][2]))
for k in bk[:2]:
    if rlist[k][4] not in("lobi","yaratik","cikis"): rlist[k]=rlist[k][:4]+("salon",)
spawn_cell=creature_cell=exit_cell=None; _lobi=None
for (i0,i1,j0,j1,th) in rlist:
    rid_=_yid(); tip="salon" if th in("lobi","salon") else "oda"
    ODA[rid_]=(th,); TIP[rid_]=tip; _rect[rid_]=(i0,i1,j0,j1)
    for i in range(i0,i1+1):
        for j in range(j0,j1+1):
            GRID[i][j]=rid_; _hc[rid_].append((i,j))
    cI,cJ=(i0+i1)//2,(j0+j1)//2
    if th=="lobi": spawn_cell=(cI,cJ); _lobi=rid_
    elif th=="yaratik": creature_cell=(max(i0,i1-1),cJ)
    elif th=="cikis": exit_cell=(cI,cJ)
def _isc(i,j): return 0<=i<H and 0<=j<W and GRID[i][j]=='c'
for _ in range(150):                      # maze: void cizgiler
    i=rng.randint(1,H-2); j=rng.randint(1,W-2)
    if GRID[i][j]!='c': continue
    L=rng.randint(2,6); hz=rng.random()<0.5
    for k in range(L):
        ii=i if hz else i+k; jj=j+k if hz else j
        if _isc(ii,jj): GRID[ii][jj]='.'
for _ in range(160):                      # maze: pillar noktalar
    i=rng.randint(1,H-2); j=rng.randint(1,W-2)
    if GRID[i][j]=='c': GRID[i][j]='.'
def _wk(i,j):
    if not(0<=i<H and 0<=j<W): return False
    g=GRID[i][j]; return g=='c' or (g!='.' and TIP.get(g)=="salon")
seed=None
if _lobi:
    for (i,j) in _hc[_lobi]:
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            if _isc(i+di,j+dj): seed=(i+di,j+dj); break
        if seed: break
if seed is None: seed=next(((i,j) for i in range(H) for j in range(W) if GRID[i][j]=='c'),None)
reach=set()
if seed:
    reach.add(seed); q=deque([seed])
    while q:
        i,j=q.popleft()
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            ni,nj=i+di,j+dj
            if (ni,nj) not in reach and _wk(ni,nj): reach.add((ni,nj)); q.append((ni,nj))
for i in range(H):                        # ulasilamayan koridor cepleri -> void (daha cok maze)
    for j in range(W):
        if GRID[i][j]=='c' and (i,j) not in reach: GRID[i][j]='.'
def _rreach(r):
    for (i,j) in _hc[r]:
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            if (i+di,j+dj) in reach: return True
    return False
for r in list(ODA.keys()):                # her odayi koridora bagla (gerekirse tunel)
    if _rreach(r): continue
    prev={}; q=deque()
    for (i,j) in _hc[r]:
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            ni,nj=i+di,j+dj
            if 0<=ni<H and 0<=nj<W and GRID[ni][nj]=='.' and (ni,nj) not in prev:
                prev[(ni,nj)]=None; q.append((ni,nj))
    hit=None
    while q and hit is None:
        i,j=q.popleft()
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            ni,nj=i+di,j+dj
            if not(0<=ni<H and 0<=nj<W): continue
            if (ni,nj) in reach: hit=(i,j); break
            if GRID[ni][nj]=='.' and (ni,nj) not in prev: prev[(ni,nj)]=(i,j); q.append((ni,nj))
    cur=hit
    while cur is not None:
        i,j=cur
        if GRID[i][j]=='.': GRID[i][j]='c'; reach.add((i,j))
        cur=prev.get(cur)

NR,NC=H,W
TEMA_OF={r:ODA[r][0] for r in ODA}
def cell_center(i,j): return (j*CELL, i*CELL)
def rid(i,j):
    if 0<=i<NR and 0<=j<NC and GRID[i][j]!='.': return GRID[i][j]
    return None
def theme_of(r): return "koridor" if r=='c' else TEMA_OF.get(r,"koridor")
def floor_of(r): return FLOOR_TEX[TEMA[theme_of(r)][0]]

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
        if i%2==0 and j%2==0:                      # isik 4 hucrede 1 (sahte lamba) - perf
            col_,en_,rng_=TEMA[theme_of(r)][2]
            lights.append({"pos":[x,Y0+WALL_H-0.5,z],"color":col_,"energy":en_*1.7,"range":rng_*1.15})

WALK={"koridor","salon"}
_ind=set(k for k in TEMA_OF if TEMA_OF[k] in("bakim","kazan","yaratik","arsiv","islak"))
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
    nk=2 if (len(_hc[oda])>=40 and len(sr)>=2) else 1
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
    if (kind,i,j) in kapi_edges:
        place_door(x,z,rot,part); door_edges_bp.append((x,z,kind=='H'))
    else:
        place_wall(x,z,rot,part); wall_segs_bp.append(seg_bp(kind,x,z))
for (kind,i,j,a,b) in duvar_edges:
    x,z,rot=edge_geom(kind,i,j); part=wall_part_for(a,b)
    place_wall(x,z,rot,part); wall_segs_bp.append(seg_bp(kind,x,z))

# OBJELER (tema bazli, desenli)
OBJELER=[]
def _o(part,i,j,dx,dz,rot,scale=None): OBJELER.append((part,(i,j),(dx,dz),rot)+((scale,) if scale else ()))
def _ic(v,a,b): return max(a,min(b,v))
def themed(th,i0,i1,j0,j1,idx):
    cI,cJ=(i0+i1)//2,(j0+j1)//2; hi=(i1-i0)>=3; wi=(j1-j0)>=3
    if th in ("lobi","salon"):
        if hi and wi:
            for s,(ci,cj) in zip(["Sutun1","Sutun2","Sutun3","Sutun1"],
                                 [(i0+1,j0+1),(i0+1,j1-1),(i1-1,j0+1),(i1-1,j1-1)]):
                _o(s,ci,cj,0,0,0,(1.3,2.85,1.3))
        _o("GuvenlikKamerasi",i0,j0,1.0,-1.0,135); _o("CopKutusu",i1,cJ,0.4,0.6,0)
    elif th=="ofis":
        _o("ElektrikPanosu",i0,j0,0,-1.0,180); _o("CopKutusu",i1,j1,0,0,0)
    elif th=="depo":
        _o("CopKutusu",i0,j0,0,0,0); _o("CopKutusu",i1,j1,0,0,0)
    elif th=="arsiv":
        _o("ElektrikPanosu",i0,j0,1.0,0,270); _o("CopKutusu",cI,j0,0.6,0,0)
    elif th=="bakim":
        _o("ElektrikPanosu",i0,j0,0,-1.0,180); _o("ElektrikPanosu",i0,_ic(j0+2,j0,j1),0,-1.0,180); _o("Mazgal",cI,cJ,0,0,0)
    elif th=="kazan":
        _o("ElektrikPanosu",i1,j0,-1.0,0,90); _o("Mazgal",cI,cJ,0,0,0)
    elif th=="islak":
        _o("Mazgal",i0,cJ,0,0,0); _o("Mazgal",i1,cJ,0,0,0)
    elif th=="yaratik":
        for (ci,cj) in [(i0,j0),(i0,j1),(i1,j0),(i1,j1),(cI,cJ)]: _o("Mazgal",_ic(ci,i0,i1),_ic(cj,j0,j1),0,0,0)
        _o("GuvenlikKamerasi",i0,j0,1.0,-1.0,120)
    elif th=="cikis":
        _o("GuvenlikKamerasi",i0,j1,-1.0,-1.0,250)
for ri,r in enumerate(ODA):
    i0,i1,j0,j1=_rect[r]; themed(theme_of(r),i0,i1,j0,j1,ri)
if creature_cell: _o("Canavar",creature_cell[0],creature_cell[1],0,0,200)
cor=[(i,j) for i in range(NR) for j in range(NC) if GRID[i][j]=='c']
for k in range(0,len(cor),19): _o("Mazgal",cor[k][0],cor[k][1],0,0,0)

for o in OBJELER:
    part,(i,j),(dx,dz),rot=o[0],o[1],o[2],o[3]
    scl=tuple(o[4]) if len(o)>4 else (1,1,1)
    x,z=cell_center(i,j); meta=PARTS[part]; y=Y0
    if part=="GuvenlikKamerasi": y=Y0+WALL_H-1.0
    col=None
    if meta.get("col"): cs=meta["col"]; col=[cs[0],cs[1],cs[2],cs[1]/2.0]
    add_inst(part,x+dx,z+dz,float(rot),y=y,scale=scl,col=col)

for idx,(x0,z0,x1,z1) in enumerate(wall_segs_bp):
    if idx%2: continue
    mx,mz=(x0+x1)/2.0,(z0+z1)/2.0
    stains.append({"pos":[round(mx,2),Y0+0.07,round(mz,2)],"normal":[0,1,0],
                   "size":round(0.6+(idx%5)*0.18,2),"tex":"lekeler/leke_%02d"%((idx%16)+1),"rot":float((idx*47)%360)})
for r in ODA:
    i0,i1,j0,j1=_rect[r]; cx,cz=cell_center((i0+i1)//2,(j0+j1)//2)
    stains.append({"pos":[round(cx,2),Y0+0.07,round(cz,2)],"normal":[0,1,0],
                   "size":1.1,"tex":"lekeler/leke_%02d"%((abs(hash(r))%16)+1),"rot":float(abs(hash(r))%360)})

if spawn_cell is None: spawn_cell=cor[0] if cor else (1,1)
sx,sz=cell_center(*spawn_cell); spawn=[sx,Y0+1.0,sz]

plan={"cell":CELL,"wall_h":WALL_H,"y0":Y0,"nr":NR,"nc":NC,"parts_meta":PARTS,
      "instances":instances,"lights":lights,"stains":stains,"spawn":spawn,
      "grid":["".join(r) for r in GRID],"rooms":{r:[theme_of(r),floor_of(r)] for r in ODA}}
with open(os.path.join(OUT,"dunya_plan.json"),"w") as f: json.dump(plan,f,indent=1)
# baglilik dogrula (walk agi + odalar)
def _walk(i,j): return 0<=i<H and 0<=j<W and GRID[i][j]!='.' and _tip(GRID[i][j]) in WALK
tot=sum(1 for i in range(H) for j in range(W) if _walk(i,j))
st=next(((i,j) for i in range(H) for j in range(W) if _walk(i,j)),None)
seen=set()
if st:
    seen.add(st); q=deque([st])
    while q:
        i,j=q.popleft()
        for di,dj in((0,1),(0,-1),(1,0),(-1,0)):
            if _walk(i+di,j+dj) and (i+di,j+dj) not in seen: seen.add((i+di,j+dj)); q.append((i+di,j+dj))
erisilemez=[r for r in ODA if not any(_walk(i+di,j+dj) and (i+di,j+dj) in seen
            for (i,j) in _hc[r] for di,dj in((0,1),(0,-1),(1,0),(-1,0)))]
oda_say=sum(1 for r in ODA if TIP[r]=="oda"); salon_say=sum(1 for r in ODA if TIP[r]=="salon")
print("instances:",len(instances),"lights:",len(lights),"oda:",oda_say,"salon:",salon_say,
      "kapi:",len(kapi_edges),"walk tek-parca:",len(seen)==tot,"erisilemez oda:",erisilemez or "YOK")

# ============================================================ KROKI (tedirgin edici / karanlik)
fig,ax=plt.subplots(figsize=(15,16)); fig.patch.set_facecolor("#0a0a0c"); ax.set_facecolor("#0a0a0c")
for i in range(NR):
    for j in range(NC):
        r=rid(i,j)
        if r is None: continue
        x,z=cell_center(i,j); rc=TEMA[theme_of(r)][1]
        ax.add_patch(Rectangle((x-2,z-2),CELL,CELL,facecolor=rc,edgecolor="#000000",lw=0.15,zorder=1))
for x0,z0,x1,z1 in wall_segs_bp:
    ax.plot([x0,x1],[z0,z1],color="#05060a",lw=2.4,solid_capstyle="butt",zorder=6)
for x,z,yatay in door_edges_bp:
    if yatay: ax.plot([x-DOOR_W/2,x+DOOR_W/2],[z,z],color="#6a3030",lw=3,zorder=7)
    else: ax.plot([x,x],[z-DOOR_W/2,z+DOOR_W/2],color="#6a3030",lw=3,zorder=7)
# canavar + spawn
if creature_cell:
    cx,cz=cell_center(*creature_cell); ax.scatter([cx],[cz],marker="X",s=200,color="#ff1a1a",edgecolor="#000",lw=1,zorder=9)
    ax.text(cx,cz+3,"o",ha="center",color="#ff2a2a",fontsize=14,zorder=9)
ax.scatter([spawn[0]],[spawn[2]],marker="*",s=200,color="#6aa9ff",edgecolor="#000",lw=0.8,zorder=10)
ax.text(spawn[0],spawn[2]-3,"...",ha="center",color="#6aa9ff",fontsize=12,zorder=10)
ax.set_xlim(-4,NC*CELL); ax.set_ylim(NR*CELL,-4); ax.set_aspect("equal"); ax.axis("off")
ax.set_title("ÇIKIŞ YOK",color="#9b1c1c",fontsize=26,weight="bold",fontfamily="monospace",pad=18)
fig.text(0.5,0.012,"%d oda · %d salon · buradan çıkış yok · o hâlâ burada"%(oda_say,salon_say),
         ha="center",color="#5a5a5a",fontsize=11,fontfamily="monospace")
plt.tight_layout()
fig.savefig(os.path.join(OUT,"krokiler","kat_zemin.png"),dpi=110,bbox_inches="tight",facecolor="#0a0a0c")
print("KROKI ->",os.path.join(OUT,"krokiler","kat_zemin.png"))
