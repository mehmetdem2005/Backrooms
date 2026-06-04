# -*- coding: utf-8 -*-
"""
GENEL deterministik 3B kurucu (kapiya ozel DEGIL — hangi gorsel verilirse onun
analiz+derinlik ciktisindan kurar).

Yontem: YOGUN grid (binlerce nokta) -> monokuler derinlik (Depth Pro) ile displace
-> gercek kabartili geometri + gercek foto doku. Silhouette dis hatta kirpilir,
kalinlik verilir.

Girdi <dir>: analiz.py + derinlik.py ciktilari
  rectified_temiz.png, mask_rectified.png, outline.json, harita.json, depth16.png

Kullanim:
  blender -b -P insa.py -- <dir> <cikti.glb> [--boy 2.0] [--kabarti 0.05]
                                            [--kalinlik 0.10] [--grid 500]
"""
import bpy, json, os, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
DIR = argv[0]
OUT = argv[1] if len(argv) > 1 and not argv[1].startswith("--") else os.path.join(DIR, "model.glb")
def opt(f, d):
    return float(argv[argv.index(f)+1]) if f in argv else d
BOY    = opt("--boy", 2.0)        # yukseklik (m) - tek serbest olcek
KABART = opt("--kabarti", 0.05)   # kabarti genligi (m): derinlik 1->0 araligi
KALIN  = opt("--kalinlik", 0.10)  # govde kalinligi (m)
GRID_L = int(opt("--grid", 500))  # uzun kenar bolunmesi (yogunluk)

harita = json.load(open(os.path.join(DIR, "harita.json")))
oran = harita.get("en_boy_orani") or 0.5
outline = json.load(open(os.path.join(DIR, "outline.json")))["outline_normalize"]
ALB = os.path.join(DIR, "rectified_temiz.png")
HGT = os.path.join(DIR, "depth16.png")
EN = BOY * oran
NZ = GRID_L
NX = max(2, int(round(GRID_L * oran)))

bpy.ops.wm.read_factory_settings(use_empty=True)

# --- yogun grid (on yuz duzlemi XZ) ---
bpy.ops.mesh.primitive_grid_add(x_subdivisions=NX, y_subdivisions=NZ, size=1.0)
g = bpy.context.active_object; g.name = "GorselModel"
g.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.transform_apply(rotation=True)
g.scale = (EN/2, 1.0, BOY/2); g.location = (0, 0, BOY/2)
bpy.ops.object.transform_apply(location=True, scale=True)

# UV planar (x,z)->(nx,ny)
me = g.data; uvl = me.uv_layers.new(name="UV")
for poly in me.polygons:
    for li in poly.loop_indices:
        co = me.vertices[me.loops[li].vertex_index].co
        uvl.data[li].uv = ((co.x + EN/2)/EN, co.z/BOY)

# --- displace: Depth Pro derinligi (Non-Color), kabarik(-Y) ---
himg = bpy.data.images.load(HGT); himg.colorspace_settings.name = 'Non-Color'
tex = bpy.data.textures.new("h", 'IMAGE'); tex.image = himg; tex.extension = 'EXTEND'
md = g.modifiers.new("disp", 'DISPLACE')
md.texture = tex; md.texture_coords = 'UV'
md.direction = 'Y'; md.strength = -KABART; md.mid_level = 0.0
bpy.context.view_layer.objects.active = g
bpy.ops.object.modifier_apply(modifier="disp")

# --- silhouette dis hatta kirp (nokta-poligon testi, gorselden gelen outline) ---
def pip(x, y, poly):
    inside = False; n = len(poly); j = n-1
    for i in range(n):
        xi, yi = poly[i]; xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj-xi)*(y-yi)/(yj-yi+1e-12)+xi):
            inside = not inside
        j = i
    return inside

import bmesh
bm = bmesh.new(); bm.from_mesh(me)
sil = []
for f in bm.faces:
    cx = sum(v.co.x for v in f.verts)/len(f.verts)
    cz = sum(v.co.z for v in f.verts)/len(f.verts)
    nx = (cx + EN/2)/EN; ny = 1.0 - cz/BOY
    if not pip(nx, ny, outline):
        sil.append(f)
bmesh.ops.delete(bm, geom=sil, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(me); bm.free()

# --- kalinlik (arka kabuk) ---
sol = g.modifiers.new("sol", 'SOLIDIFY'); sol.thickness = KALIN; sol.offset = 1.0
bpy.ops.object.modifier_apply(modifier="sol")
bpy.ops.object.shade_smooth()
me.use_auto_smooth = True if hasattr(me, "use_auto_smooth") else False

tri = sum(len(p.vertices)-2 for p in me.polygons)
print(">>> ucgen:", tri, "grid=%dx%d EN=%.3f BOY=%.3f kabarti=%.3f" % (NX, NZ, EN, BOY, KABART))

# --- materyal (gercek rectified foto) ---
mat = bpy.data.materials.new("albedo"); mat.use_nodes = True
b = mat.node_tree.nodes["Principled BSDF"]
ti = mat.node_tree.nodes.new("ShaderNodeTexImage"); ti.image = bpy.data.images.load(ALB)
mat.node_tree.links.new(ti.outputs["Color"], b.inputs["Base Color"])
b.inputs["Roughness"].default_value = 0.7
me.materials.append(mat)

# --- export ---
os.makedirs(os.path.dirname(OUT) or ".", exist_ok=True)
bpy.ops.object.select_all(action='DESELECT'); g.select_set(True)
bpy.context.view_layer.objects.active = g
bpy.ops.export_scene.gltf(filepath=OUT, use_selection=True, export_format='GLB',
                          export_yup=True, export_apply=True)
print(">>> export:", OUT)
