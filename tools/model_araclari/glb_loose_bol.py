# -*- coding: utf-8 -*-
# Tek GLB icindeki BIRDEN COK objeyi (loose parts) ayri ayri GLB'lere boler.
# Tripo gibi araclarin tek dosyada verdigi N objeyi ( or. 3 sutun) bagimsiz
# yerlestirilebilir parcalara cevirmek icin. Her cikti: X/Y merkez, TABAN y=0.
#
# Kullanim:
#   blender -b -P tools/model_araclari/glb_loose_bol.py -- <giris.glb> <cikis_onek> <adet>
#   ornek: ... -- model.glb /home/user/Backrooms/models/sutun 3
#   -> sutun1.glb, sutun2.glb, sutun3.glb (en genis yatay eksende 'adet' kumeye boler)

import bpy, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
SRC   = argv[0]
ONEK  = argv[1] if len(argv)>1 else os.path.splitext(SRC)[0]
ADET  = int(argv[2]) if len(argv)>2 else 3

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
if len(meshes)>1: bpy.ops.object.join()

# loose parts'a ayir
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='LOOSE')
bpy.ops.object.mode_set(mode='OBJECT')
parts=[o for o in bpy.data.objects if o.type=='MESH']
print(">>> loose parça:", len(parts))

# her parcanin dunya-merkezi
cen=[(o, o.matrix_world @ (0.125*sum((Vector(c) for c in o.bound_box), Vector()))) for o in parts]
xs=[c[1].x for c in cen]; ys=[c[1].y for c in cen]
ax = 0 if (max(xs)-min(xs)) >= (max(ys)-min(ys)) else 1
vals=[c[1][ax] for c in cen]; lo,hi=min(vals),max(vals); span=(hi-lo) or 1.0
gruplar={k:[] for k in range(ADET)}
for (o,c) in cen:
    k=min(ADET-1, int((c[ax]-lo)/span*ADET + 1e-6)); gruplar[k].append(o)
print(">>> eksen:", "XY"[ax], "grup:", {k:len(v) for k,v in gruplar.items()})

def disa(objs, yol):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    if len(objs)>1: bpy.ops.object.join()
    g=bpy.context.view_layer.objects.active
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    g.location=Vector((0,0,g.dimensions.z/2.0))     # X/Y merkez, taban z=0
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    bpy.ops.object.select_all(action='DESELECT'); g.select_set(True)
    bpy.context.view_layer.objects.active=g
    bpy.ops.export_scene.gltf(filepath=yol, use_selection=True, export_format='GLB',
        export_yup=True, export_apply=True, export_image_format='AUTO')
    print(">>> yazildi:", yol, "(boy=%.2f)"%g.dimensions.z)

i=1
for k in range(ADET):
    if gruplar[k]:
        disa(gruplar[k], "%s%d.glb"%(ONEK,i)); i+=1
print(">>> BITTI")
