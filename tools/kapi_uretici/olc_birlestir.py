# -*- coding: utf-8 -*-
# Backrooms - Tripo cerceve + panel GLB'lerini oyun kapisina oturtmak icin
# OLCUM + TRANSFORM hesaplayici (saf numpy, Blender gerekmez).
#
# Kullanim:  python3 tools/kapi_uretici/olc_birlestir.py
#
# Ne yapar:
#   - Iki ham GLB'nin vertex bulutunu decode eder (POSITION accessor).
#   - Tripo uzayini (X=derinlik, Y=yukseklik, Z=genislik) OYUN uzayina dondurur
#     (Y'de +90: Tripo-Z->oyun-X[genislik], Tripo-X->oyun-Z[derinlik]).
#   - Cerceveyi TARGET_BOY=2.0m yukseklige uniform olcekler, tabani y=0.
#   - Cerceve ic ACIKLIGINI gercek geometriden olcer (jamb ic yuzleri).
#   - Panel'i acikliga ~1cm boslukla oturtur, menteseyi SOL kenara koyar.
#   - Godot Transform3D + collision kutularini hesaplar; ekrana ve
#     models/kapi_birlestir.json'a yazar (Kapi.tscn bunlardan bake edilir).

import json, struct, os, numpy as np

PROJE = "/home/user/Backrooms"
FRAME = os.path.join(PROJE, "models", "kapi_cerceve_tripo.glb")
PANEL = os.path.join(PROJE, "models", "kapi_kanat_tripo.glb")

TARGET_BOY = 2.0       # kapi yuksekligi (m) - kullanici karari
CLR        = 0.01      # panel ile aciklik arasi bosluk (her kenar, m)
PANEL_DERINLIK = 0.10  # panel son derinligi (m); cerceve derinligi icinde otursun

# ---------------------------------------------------------------- GLB decode
_CT = {5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
_NC = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def _load_glb(path):
    with open(path,'rb') as f: data=f.read()
    _,_,length = struct.unpack('<III', data[:12])
    off=12; jchunk=bchunk=None
    while off < length:
        clen,ctype = struct.unpack('<II', data[off:off+8]); off+=8
        chunk=data[off:off+clen]; off+=clen
        if ctype==0x4E4F534A: jchunk=chunk
        elif ctype==0x004E4942: bchunk=chunk
    return json.loads(jchunk), bchunk

def _accessor(j, bin_, idx):
    acc=j['accessors'][idx]; bv=j['bufferViews'][acc['bufferView']]
    base=bv.get('byteOffset',0)+acc.get('byteOffset',0)
    fmt,sz=_CT[acc['componentType']]; nc=_NC[acc['type']]
    stride=bv.get('byteStride') or sz*nc
    out=np.empty((acc['count'],nc),dtype=np.float32)
    for i in range(acc['count']):
        o=base+i*stride
        out[i]=struct.unpack_from('<'+fmt*nc, bin_, o)
    return out

def _node_matrix(n):
    if 'matrix' in n: return np.array(n['matrix'],dtype=np.float64).reshape(4,4).T
    M=np.eye(4)
    if 'scale' in n: M[:3,:3]=np.diag(n['scale'])
    if 'rotation' in n:
        x,y,z,w=n['rotation']
        R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                    [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                    [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
        M[:3,:3]=R@M[:3,:3]
    if 'translation' in n: M[:3,3]=n['translation']
    return M

def verts_oyun(path):
    """GLB vertexlerini node transformlariyla cikar, sonra Y'de +90 dondur
    (Tripo X=derinlik->oyun Z; Tripo Z=genislik->oyun X; Y=yukseklik sabit)."""
    j,bin_=_load_glb(path)
    allv=[]
    # sahne node'larini tek seviye gez (Tripo: 1 node, transform yok ama saglam ol)
    def walk(ni, parent):
        n=j['nodes'][ni]; M=parent@_node_matrix(n)
        if 'mesh' in n:
            for p in j['meshes'][n['mesh']]['primitives']:
                pos=_accessor(j,bin_,p['attributes']['POSITION'])
                h=np.hstack([pos,np.ones((len(pos),1))])
                allv.append((M@h.T).T[:,:3])
        for c in n.get('children',[]): walk(c,M)
    scene=j.get('scene',0); roots=j['scenes'][scene]['nodes']
    for r in roots: walk(r, np.eye(4))
    V=np.vstack(allv).astype(np.float64)
    # Ry(+90): x'=z, z'=-x
    out=np.empty_like(V)
    out[:,0]=V[:,2]; out[:,1]=V[:,1]; out[:,2]=-V[:,0]
    return out

def bbox(V):
    return V.min(0), V.max(0)

# ================================================================ CERCEVE
Fc = verts_oyun(FRAME)              # oyun-yonlu (henuz olceksiz, Tripo-merkezli)
mn,mx = bbox(Fc)
H_tripo = mx[1]-mn[1]
s_c = TARGET_BOY / H_tripo          # uniform olcek
Fc *= s_c
# tabani y=0'a tasi, x/z merkezde kalsin (Tripo zaten merkezli)
mn,mx = bbox(Fc)
Fc[:,1] -= mn[1]
mn,mx = bbox(Fc)
W = mx[0]-mn[0]; D = mx[2]-mn[2]    # cerceve genislik / derinlik
xmin,xmax = mn[0],mx[0]
zmin,zmax = mn[2],mx[2]
Hmid = TARGET_BOY/2.0

# --- ic ACIKLIK olcumu (jamb ic yuzleri) ---
sol = Fc[(Fc[:,0]<0) & (np.abs(Fc[:,1]-Hmid)<0.3*TARGET_BOY)]
sag = Fc[(Fc[:,0]>0) & (np.abs(Fc[:,1]-Hmid)<0.3*TARGET_BOY)]
ic_sol = sol[:,0].max(); ic_sag = sag[:,0].min()
alt = Fc[(np.abs(Fc[:,0])<0.3*W) & (Fc[:,1]<Hmid)]
ust = Fc[(np.abs(Fc[:,0])<0.3*W) & (Fc[:,1]>Hmid)]
ic_alt = alt[:,1].max(); ic_ust = ust[:,1].min()
ac_en = ic_sag-ic_sol; ac_boy = ic_ust-ic_alt

# ================================================================ PANEL
Pp = verts_oyun(PANEL)
pmn,pmx = bbox(Pp)
pW = pmx[0]-pmn[0]   # Tripo-Z -> oyun X (genislik)
pH = pmx[1]-pmn[1]   # Tripo-Y -> oyun Y (yukseklik)
pD = pmx[2]-pmn[2]   # Tripo-X -> oyun Z (derinlik)

panel_en  = ac_en  - 2*CLR
panel_boy = ac_boy - 2*CLR
panel_der = PANEL_DERINLIK
# LOKAL olcekler (Tripo eksenlerine): height=Y, width=Z, depth=X
sY = panel_boy / pH      # yukseklik
sZ = panel_en  / pW      # genislik
sX = panel_der / pD      # derinlik

# Mente (menteseden donus) dunya konumu: sol-ic kenar, aciklik alt+clr
hinge_x = ic_sol + CLR
base_y  = ic_alt + CLR
mente = (round(hinge_x,4), round(base_y,4), 0.0)
# panel instance LOKAL origin (Mente altinda): sol kenar x=0, taban y=0, z merkez
p_local_origin = (round(panel_en/2,4), round(panel_boy/2,4), 0.0)

# ---------------------------------------------------------------- collision
def box(cx,cy,cz,sx,sy,sz):
    return {"center":[round(cx,4),round(cy,4),round(cz,4)],
            "size":[round(sx,4),round(sy,4),round(sz,4)]}
col_sol = box((xmin+ic_sol)/2, Hmid, 0,  ic_sol-xmin, TARGET_BOY, D)
col_sag = box((ic_sag+xmax)/2, Hmid, 0,  xmax-ic_sag, TARGET_BOY, D)
col_ust = box((ic_sol+ic_sag)/2,(ic_ust+TARGET_BOY)/2,0, ac_en, TARGET_BOY-ic_ust, D)
col_alt = box((ic_sol+ic_sag)/2, ic_alt/2,0, ac_en, ic_alt, D)
# panel collision (Mente altinda, panel ile ayni offset)
col_panel = box(panel_en/2, panel_boy/2, 0, panel_en, panel_boy, panel_der)

# ---------------------------------------------------------------- Godot Transform3D
# Istenen lineer harita (world = M*local), local = ham glTF vert
# (lx=glTF X=derinlik, ly=glTF Y=yukseklik, lz=glTF Z=genislik):
#   world_x = sZ*lz (genislik) ; world_y = sY*ly (yukseklik) ; world_z = -sX*lx (derinlik)
# => M satirlari: [0,0,sZ] [0,sY,0] [-sX,0,0]
# ONEMLI: Godot .tscn Transform3D'nin 9 basis sayisini SATIR-major okur (Basis.rows),
# bu yuzden basis'i satir olarak yaziyoruz (sutun degil).
def tf3d(sX,sY,sZ,o):
    return "Transform3D(%g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g, %g)" % (
        0,0,sZ, 0,sY,0, -sX,0,0, o[0],o[1],o[2])
frame_tf = tf3d(s_c,s_c,s_c,(0.0,TARGET_BOY/2.0,0.0))   # not: taban kaymasi icin merkez y
# cerceve merkezi y=TARGET_BOY/2 (taban 0)
panel_tf = tf3d(sX,sY,sZ,p_local_origin)

out = {
  "TARGET_BOY":TARGET_BOY, "CLR":CLR,
  "cerceve":{"olcek":round(s_c,5),"genislik":round(W,4),"derinlik":round(D,4),
             "x":[round(xmin,4),round(xmax,4)],"z":[round(zmin,4),round(zmax,4)],
             "transform":frame_tf},
  "aciklik":{"sol":round(ic_sol,4),"sag":round(ic_sag,4),
             "alt":round(ic_alt,4),"ust":round(ic_ust,4),
             "en":round(ac_en,4),"boy":round(ac_boy,4)},
  "panel":{"ham":[round(pW,4),round(pH,4),round(pD,4)],
           "son_en":round(panel_en,4),"son_boy":round(panel_boy,4),"son_der":round(panel_der,4),
           "olcek_xyz":[round(sX,5),round(sY,5),round(sZ,5)],
           "local_origin":list(p_local_origin),"transform":panel_tf},
  "mente":list(mente),
  "collision":{"sol":col_sol,"sag":col_sag,"ust":col_ust,"alt":col_alt,"panel":col_panel},
}
with open(os.path.join(PROJE,"models","kapi_birlestir.json"),"w") as f:
    json.dump(out,f,indent=2)

print(json.dumps(out,indent=2,ensure_ascii=False))
print("\n>>> Cerceve  : olcek=%.4f  genislik=%.3f  derinlik=%.3f" % (s_c,W,D))
print(">>> Aciklik  : en=%.3f boy=%.3f  (sol=%.3f sag=%.3f alt=%.3f ust=%.3f)"
      % (ac_en,ac_boy,ic_sol,ic_sag,ic_alt,ic_ust))
print(">>> Panel    : son en=%.3f boy=%.3f der=%.3f  olcek(X,Y,Z)=(%.3f,%.3f,%.3f)"
      % (panel_en,panel_boy,panel_der,sX,sY,sZ))
print(">>> Mente    : %s" % (mente,))
print(">>> JSON     : models/kapi_birlestir.json")
