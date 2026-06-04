# -*- coding: utf-8 -*-
# Backrooms - Tripo kapi birlestirme DOKULU dogrulama render'i (Blender-native Z-up).
# Mesh'ler glTF importer ile MATERYAL+DOKU dahil yuklenir (Tripo pas dokusu KORUNUR).
# olc_birlestir.py'nin OLCUMLERINI (aciklik/olcek/mente) kullanir; transformlar dogrudan
# Blender Z-up'ta kurulur (yukseklik = +Z) -> kamera dogal, yatiklik olmaz.
#   Godot oyun ekseni  : X=genislik, Y=yukseklik, Z=derinlik
#   Blender Z-up esleme : X=genislik, Z=yukseklik, Y=derinlik
# Kullanim: blender -b -P tools/kapi_uretici/dogrula_render_renkli.py
# Cikti: /tmp/kapi_renkli_on.png (cephe) + _0/_40/_80.png (3/4 acilis dizisi)

import bpy, json, os, math
from mathutils import Vector, Matrix

PROJE="/home/user/Backrooms"
J=json.load(open(os.path.join(PROJE,"models","kapi_birlestir.json")))
FRAME=os.path.join(PROJE,"models","kapi_cerceve_tripo.glb")
PANEL=os.path.join(PROJE,"models","kapi_kanat_tripo.glb")
BOY=J["TARGET_BOY"]; s_c=J["cerceve"]["olcek"]
sX,sY,sZ=J["panel"]["olcek_xyz"]            # sX=derinlik sY=yukseklik sZ=genislik (Tripo eksen)
plo=J["panel"]["local_origin"]              # game (en/2, boy/2, 0)
mente=J["mente"]                            # game (ic_sol+clr, ic_alt+clr, 0)

bpy.ops.wm.read_factory_settings(use_empty=True)

def imp(path):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)   # importer -> Blender Z-up (yukseklik local +Z)
    return [o for o in bpy.data.objects if o not in before and o.type=='MESH']

def Rz(d): return Matrix.Rotation(math.radians(d),4,'Z')
def T(v):  return Matrix.Translation(Vector(v))
def Sc(a,b,c): return Matrix.Diagonal(Vector((a,b,c))).to_4x4()

# Importer local eksenleri: X=derinlik, Y=genislik, Z=yukseklik.
# Rz(90): local Y(genislik)->Blender X ; local X(derinlik)->Blender Y ; Z=yukseklik sabit.
# --- CERCEVE: uniform s_c, taban z=0 (merkezli mesh -> +BOY/2) ---
M_frame = T((0,0,BOY/2)) @ Rz(90) @ Sc(s_c,s_c,s_c)
for o in imp(FRAME):
    o.parent=None; o.matrix_world=M_frame

# --- PANEL: non-uniform (local X=derinlik->sX, Y=genislik->sZ, Z=yukseklik->sY) ---
panel_objs=imp(PANEL)
hinge_bl=(mente[0], 0.0, mente[1])          # game(x,y,0)->Blender(x,0,y) ; vertical=+Z
plo_bl  =(plo[0],   0.0, plo[1])
def panel_matrix(angle):
    return T(hinge_bl) @ Rz(angle) @ T(plo_bl) @ Rz(90) @ Sc(sX,sZ,sY)
def place_panel(angle):
    M=panel_matrix(angle)
    for o in panel_objs: o.parent=None; o.matrix_world=M

# ---------------- zemin / dunya / kamera ----------------
bpy.ops.mesh.primitive_plane_add(size=14, location=(0,0,0))
zob=bpy.context.active_object
zmat=bpy.data.materials.new("zmat"); zmat.use_nodes=True
zmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(0.16,0.16,0.18,1)
zob.data.materials.append(zmat)

w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.07,0.07,0.08,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.6
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=40; sc.cycles.use_denoising=False
sc.render.resolution_x=760; sc.render.resolution_y=950
sc.view_settings.view_transform='AgX'

def setup_cam(kind):
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA','LIGHT'): bpy.data.objects.remove(o,do_unlink=True)
    hed=Vector((0,0,BOY/2))                     # door merkezi (yukseklik +Z)
    if kind=="on": loc=Vector((0.0,-5.0,BOY/2)) # tam cepheden (kapi +Y'ye/-Y? bakar)
    else:          loc=Vector((3.2,-3.8,1.45))  # 3/4 on-sag, goz hizasi
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam); cam.location=loc; cam.data.lens=50
    cam.rotation_euler=(hed-loc).to_track_quat('-Z','Y').to_euler()
    bpy.context.scene.camera=cam
    for e,l in [(900,(4,-5,5)),(300,(-4,-3,3)),(250,(0,4,4))]:
        L=bpy.data.objects.new("L",bpy.data.lights.new("L",'AREA'))
        bpy.context.collection.objects.link(L); L.data.energy=e; L.data.size=6
        L.location=Vector(l); L.rotation_euler=(hed-Vector(l)).to_track_quat('-Z','Y').to_euler()

def render(tag,cam):
    setup_cam(cam); sc.render.filepath=tag; bpy.ops.render.render(write_still=True); print(">>>",tag)

place_panel(0);  render("/tmp/kapi_renkli_on.png","on")
place_panel(0);  render("/tmp/kapi_renkli_0.png","34")
place_panel(40); render("/tmp/kapi_renkli_40.png","34")
place_panel(80); render("/tmp/kapi_renkli_80.png","34")
print(">>> BITTI")
