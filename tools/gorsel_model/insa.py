# -*- coding: utf-8 -*-
"""
GENEL deterministik model kurucu (sadece kapiya ozel DEGIL).
gorsel-haritalama ciktisindan (rectified on yuz + dis hat + oran) bir 3B model
uretir: GERCEK dis hat -> kati govdeye extrude + GERCEK foto doku. Varsayim yok,
oge elle girilmez; hangi resim verilirse onun analiz ciktisindan kurar.

Kullanim:
  1) python3 .../analiz.py <resim> <dir>
  2) blender -b -P insa.py -- <dir> <cikti.glb> [--boy 2.0] [--kalinlik 0.12]
"""
import bpy, json, os, sys
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
DIR = argv[0]
OUT = argv[1] if len(argv) > 1 else os.path.join(DIR, "model.glb")
def opt(flag, d):
    return float(argv[argv.index(flag)+1]) if flag in argv else d
BOY = opt("--boy", 2.0)          # yukseklik (m) - tek serbest olcek
KALIN = opt("--kalinlik", 0.12)  # govde kalinligi (m)

harita = json.load(open(os.path.join(DIR, "harita.json")))
oran = harita.get("en_boy_orani") or 0.5      # en/boy
outline = json.load(open(os.path.join(DIR, "outline.json")))["outline_normalize"]
ALB = os.path.join(DIR, "rectified_temiz.png")
EN = BOY * oran

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- on yuz: dis hat poligonu (XZ duzlemi) ---
# nx,ny [0..1] -> x=(nx-0.5)*EN ,  z=(1-ny)*BOY ; on yuz -Y'ye bakar
verts = [(round((nx-0.5)*EN, 5), 0.0, round((1.0-ny)*BOY, 5)) for nx, ny in outline]
uvs = [(nx, 1.0-ny) for nx, ny in outline]   # foto ile birebir
poly2d = [Vector((x, z, 0.0)) for (x, _, z) in verts]
tris = tessellate_polygon([poly2d])          # deterministik ucgenleme

me = bpy.data.meshes.new("gorsel")
me.from_pydata(verts, [], [list(t) for t in tris])
me.update()
# UV
uvl = me.uv_layers.new(name="UV")
for poly in me.polygons:
    for li in poly.loop_indices:
        uvl.data[li].uv = uvs[me.loops[li].vertex_index]
obj = bpy.data.objects.new("GorselModel", me)
bpy.context.collection.objects.link(obj)

# normalleri tutarli (on yuz -Y) + kalinlik
bpy.context.view_layer.objects.active = obj; obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
# on yuz kameraya (-Y) baksin
if me.polygons and me.polygons[0].normal.y > 0:
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.flip_normals(); bpy.ops.object.mode_set(mode='OBJECT')
sol = obj.modifiers.new("k", 'SOLIDIFY'); sol.thickness = KALIN; sol.offset = 1.0
bpy.ops.object.modifier_apply(modifier="k")

# --- materyal: gercek rectified foto ---
mat = bpy.data.materials.new("gorsel_albedo"); mat.use_nodes = True
b = mat.node_tree.nodes["Principled BSDF"]
ti = mat.node_tree.nodes.new("ShaderNodeTexImage"); ti.image = bpy.data.images.load(ALB)
mat.node_tree.links.new(ti.outputs["Color"], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.7
me.materials.append(mat)

print(">>> ucgen:", sum(len(p.vertices)-2 for p in me.polygons),
      "EN=%.3f BOY=%.3f oran=%.3f" % (EN, BOY, oran))

# --- export ---
os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB',
                          export_yup=True, export_apply=True)
print(">>> export:", OUT)
