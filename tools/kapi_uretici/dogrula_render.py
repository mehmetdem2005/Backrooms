# -*- coding: utf-8 -*-
# Backrooms - Tripo kapi birlestirme DOGRULAMA render'i (Blender headless)
# Kullanim:  blender -b -P tools/kapi_uretici/dogrula_render.py
#
# olc_birlestir.py ile AYNI transformlari uygular (ham GLB vertexlerinden mesh kurar,
# Godot Y-up sayilariyla calisir -> konvansiyon karismaz). Cerceve+panel'i birlikte
# yerlestirir; panel'i Mente ekseninde 0/35/90 derece dondurup kareler render eder.
# Cikti: /tmp/kapi_kapali.png (3/4), /tmp/kapi_on.png (cepheden), /tmp/kapi_35.png,
#        /tmp/kapi_90.png

import bpy, bmesh, json, struct, os, math, numpy as np
from mathutils import Vector, Matrix

PROJE="/home/user/Backrooms"
J=json.load(open(os.path.join(PROJE,"models","kapi_birlestir.json")))
FRAME=os.path.join(PROJE,"models","kapi_cerceve_tripo.glb")
PANEL=os.path.join(PROJE,"models","kapi_kanat_tripo.glb")
BOY=J["TARGET_BOY"]; s_c=J["cerceve"]["olcek"]
sX,sY,sZ=J["panel"]["olcek_xyz"]; plo=J["panel"]["local_origin"]; mente=J["mente"]

# ---------------- GLB decode (verts + tris) ----------------
_CT={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
_NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def _glb(path):
    d=open(path,'rb').read(); _,_,L=struct.unpack('<III',d[:12]); o=12; jc=bc=None
    while o<L:
        cl,ct=struct.unpack('<II',d[o:o+8]); o+=8; ch=d[o:o+cl]; o+=cl
        if ct==0x4E4F534A: jc=ch
        elif ct==0x004E4942: bc=ch
    return json.loads(jc),bc
def _acc(j,b,i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    base=bv.get('byteOffset',0)+a.get('byteOffset',0); fmt,sz=_CT[a['componentType']]; nc=_NC[a['type']]
    st=bv.get('byteStride') or sz*nc; out=[]
    for k in range(a['count']):
        out.append(struct.unpack_from('<'+fmt*nc,b,base+k*st))
    return np.array(out)
def mesh_data(path):
    j,b=_glb(path); V=[]; F=[]; base=0
    for ni in j['scenes'][j.get('scene',0)]['nodes']:
        n=j['nodes'][ni]
        if 'mesh' not in n: continue
        for p in j['meshes'][n['mesh']]['primitives']:
            pos=_acc(j,b,p['attributes']['POSITION']).astype(np.float64)
            idx=_acc(j,b,p['indices']).astype(int).reshape(-1,3)
            V.append(pos); F.append(idx+base); base+=len(pos)
    return np.vstack(V), np.vstack(F)

def ry(v,deg):
    a=math.radians(deg); c,s=math.cos(a),math.sin(a)
    x,y,z=v[:,0],v[:,1],v[:,2]
    return np.stack([x*c+z*s, y, -x*s+z*c],1)

def make_obj(name, V, F):
    me=bpy.data.meshes.new(name); ob=bpy.data.objects.new(name,me)
    bpy.context.collection.objects.link(ob)
    me.from_pydata([Vector(p) for p in V.tolist()], [], F.tolist())
    me.update();
    for pol in me.polygons: pol.use_smooth=False
    return ob

bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------- CERCEVE: scale*s_c, Ry90, taban y=0 ----------------
Vf,Ff=mesh_data(FRAME)
Vf=Vf*s_c
Vf=ry(Vf,90)                          # Tripo->oyun
Vf[:,1]-=Vf[:,1].min()                # taban 0
make_obj("Cerceve",Vf,Ff)

# ---------------- PANEL: scale(sX,sY,sZ) Tripo eksende, Ry90, +local origin ----------------
Vp,Fp=mesh_data(PANEL)
Vp=Vp*np.array([sX,sY,sZ])            # Tripo lokal olcek
Vp=ry(Vp,90)
Vp=Vp+np.array(plo)                   # Mente frame'inde panel (sol kenar x=0)

def render_panel_at(angle, tag, cam="34"):
    for o in list(bpy.data.objects):
        if o.name.startswith("Kanat"): bpy.data.objects.remove(o,do_unlink=True)
    Vr=ry(Vp,angle)                   # Mente ekseninde ac
    Vr=Vr+np.array([mente[0],mente[1],mente[2]])
    ob=make_obj("Kanat",Vr,Fp); ob.data.materials.append(clay)
    bb_min=Vr.min(0); bb_max=Vr.max(0)
    print("  panel@%d  world bbox min=%s max=%s" %
          (angle,[round(x,2) for x in bb_min],[round(x,2) for x in bb_max]))
    setup_cam(cam)
    bpy.context.scene.render.filepath=tag
    bpy.ops.render.render(write_still=True)
    print(">>>",tag)

# ---------------- isik + kamera + clay ----------------
def setup_cam(kind):
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o,do_unlink=True)
    hed=Vector((0,BOY/2,0))
    if   kind=="on":  loc=Vector((0.0,BOY/2,5.0))     # tam cepheden (goz hizasi)
    elif kind=="yan": loc=Vector((5.0,BOY/2,0.01))    # tam yandan
    else:             loc=Vector((3.4,BOY/2,3.4))     # 3/4 on-sag, GOZ HIZASI
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam); cam.location=loc; cam.data.lens=45
    cam.rotation_euler=(hed-loc).to_track_quat('-Z','Y').to_euler()
    bpy.context.scene.camera=cam
    for e,loc in [(800,(4,4,5)),(250,(-4,3,2)),(200,(0,5,-4))]:
        L=bpy.data.objects.new("L",bpy.data.lights.new("L",'AREA'))
        bpy.context.collection.objects.link(L); L.data.energy=e; L.data.size=5
        L.location=Vector(loc); L.rotation_euler=(hed-Vector(loc)).to_track_quat('-Z','Y').to_euler()

# clay materyal (gri) - sadece geometri/fit kontrolu icin
clay=bpy.data.materials.new("clay"); clay.use_nodes=True
clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.55,0.55,0.57,1)
clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=0.7
for ob in bpy.data.objects:
    if ob.type=='MESH': ob.data.materials.append(clay)

# zemin referansi (y=0) - oryantasyon belirsizligini kaldirir
gm=bpy.data.meshes.new("Zemin"); gob=bpy.data.objects.new("Zemin",gm)
bpy.context.collection.objects.link(gob)
gm.from_pydata([(-6,0,-6),(6,0,-6),(6,0,6),(-6,0,6)],[],[(0,1,2,3)]); gm.update()
gmat=bpy.data.materials.new("zmat"); gmat.use_nodes=True
gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.18,0.18,0.2,1)
gob.data.materials.append(gmat)

w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.06,0.06,0.07,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.5
sc=bpy.context.scene
sc.render.engine='CYCLES'           # headless: EEVEE EGL ister, Cycles CPU calisir
sc.cycles.device='CPU'; sc.cycles.samples=24; sc.cycles.use_denoising=False
sc.render.resolution_x=720; sc.render.resolution_y=900
sc.view_settings.view_transform='AgX'

# kapali: cepheden + yandan + 3/4 ; sonra 3/4'ten acik kareler (yatay swing testi)
render_panel_at(0,"/tmp/kapi_on.png",cam="on")
render_panel_at(0,"/tmp/kapi_yan.png",cam="yan")
render_panel_at(0,"/tmp/kapi_kapali.png",cam="34")
render_panel_at(35,"/tmp/kapi_35.png",cam="34")
render_panel_at(90,"/tmp/kapi_90.png",cam="34")
print(">>> BITTI")
