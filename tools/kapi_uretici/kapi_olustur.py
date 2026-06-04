# -*- coding: utf-8 -*-
# Backrooms - Sci-fi kapi modeli ureticisi (Blender 4.x, headless)
# Kullanim:  blender -b -P tools/kapi_uretici/kapi_olustur.py
#
# Uretir:
#   models/kapi_cerceve.glb  -> sabit cerceve (pahli ust koseler)
#   models/kapi_kanat.glb    -> acilan kanat, origin menteseye (sol kenar) tasinmis
#   /tmp/kapi_preview.png     -> onizleme render'i
#
# Tum olculer metre. Kapi +Z yonune bakar, taban y=0'da.

import bpy, bmesh, math, os
from mathutils import Vector

PROJE = "/home/user/Backrooms"

# ---------------------------------------------------------------- temizle
bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- yardimcilar
def mat(name, color, metallic=0.7, rough=0.6, alpha=1.0, transmission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    def setv(key, val):
        if key in b.inputs:
            b.inputs[key].default_value = val
    setv("Base Color", (*color, 1.0))
    setv("Metallic", metallic)
    setv("Roughness", rough)
    if alpha < 1.0:
        setv("Alpha", alpha)
        m.blend_method = 'BLEND'
    if transmission > 0.0:
        setv("Transmission Weight", transmission)
    return m

mat_cerceve = mat("kapi_cerceve", (0.30, 0.28, 0.26), 0.85, 0.55)
mat_kanat   = mat("kapi_kanat",   (0.46, 0.44, 0.41), 0.70, 0.60)
mat_cam     = mat("kapi_cam",     (0.04, 0.05, 0.06), 0.10, 0.12, alpha=0.55, transmission=0.6)
mat_panel   = mat("kapi_panel",   (0.10, 0.10, 0.12), 0.50, 0.45)

# Blender Z-up: x=genislik, z=yukseklik, y=derinlik.
# add_box parametreleri: (x0,x1, h0,h1, d0,d1) -> genislik, yukseklik, derinlik
def add_box(name, x0, x1, h0, h1, d0, d1):
    bpy.ops.mesh.primitive_cube_add()
    o = bpy.context.active_object
    o.name = name
    o.scale = ((x1 - x0) / 2, (d1 - d0) / 2, (h1 - h0) / 2)
    o.location = ((x0 + x1) / 2, (d0 + d1) / 2, (h0 + h1) / 2)
    bpy.ops.object.transform_apply(location=True, scale=True, rotation=True)
    return o

def boolean(target, cutter, op='DIFFERENCE'):
    m = target.modifiers.new("bool", 'BOOLEAN')
    m.operation = op
    m.solver = 'EXACT'
    m.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

def recalc(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

def unwrap(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

def bevel_edges(obj, predicate, offset, segments=1, profile=0.5):
    """predicate(co_a, co_b) True olan kenarlari pahla (egim olusturur)."""
    me = obj.data
    bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if predicate(e.verts[0].co, e.verts[1].co)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=profile, affect='EDGES',
                        offset_type='OFFSET', clamp_overlap=True)
    bm.normal_update()
    bm.to_mesh(me); bm.free()

EPS = 1.5e-3
def yakin(a, b):
    return abs(a - b) < EPS

# ================================================================ CERCEVE
# Dis siluet: pahli ust koseler (alt koseler dik)
c = 0.20
mesh = bpy.data.meshes.new("cerceve_mesh")
obj_c = bpy.data.objects.new("Cerceve", mesh)
bpy.context.collection.objects.link(obj_c)
bm = bmesh.new()
# (x, yukseklik) noktalari; XZ duzleminde, y=0 derinlikte kurulur
pts = [(-0.55, 0.00), (-0.55, 1.90), (-0.35, 2.10),
       ( 0.35, 2.10), ( 0.55, 1.90), ( 0.55, 0.00)]
vs = [bm.verts.new((x, 0.0, h)) for x, h in pts]
f = bm.faces.new(vs)
res = bmesh.ops.extrude_face_region(bm, geom=[f])
ext_verts = [g for g in res['geom'] if isinstance(g, bmesh.types.BMVert)]
bmesh.ops.translate(bm, vec=(0, 0.16, 0), verts=ext_verts)  # derinlik (+Y)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh); bm.free()

# Ic acikligi oy (dikdortgen delik)
boolean(obj_c, add_box("cut_op", -0.42, 0.42, 0.13, 1.78, -0.10, 0.30))
recalc(obj_c)

# --- EGIM: cercevenin ic on kenarini genis pahla (referanstaki egimli yuzey) ---
def _acik_kenar(c):
    # acikligin sinirinda mi?  x=+-0.42  veya  z=0.13 / 1.78
    if yakin(abs(c.x), 0.42) and (0.125 <= c.z <= 1.785):
        return True
    if (yakin(c.z, 0.13) or yakin(c.z, 1.78)) and (abs(c.x) <= 0.425):
        return True
    return False
def _on(c):
    return c.y <= EPS
bevel_edges(obj_c,
            lambda a, b: _on(a) and _on(b) and _acik_kenar(a) and _acik_kenar(b),
            offset=0.065, segments=1)
# Dis on kenari da hafifce pahla (yumusak sanayi kenari)
def _dis_kenar(c):
    return yakin(abs(c.x), 0.55) or yakin(c.z, 0.0) or yakin(c.z, 2.10) \
        or yakin(c.x + c.z, 0.55 + 1.90) or yakin(-c.x + c.z, 0.55 + 1.90)
bevel_edges(obj_c,
            lambda a, b: _on(a) and _on(b) and _dis_kenar(a) and _dis_kenar(b),
            offset=0.02, segments=1)
recalc(obj_c)
obj_c.data.materials.append(mat_cerceve)

# ================================================================ KANAT
# On yuz -Y'ye bakar => dusuk y on, yuksek y arka.  derinlik: 0.030 (on) .. 0.115 (arka)
obj_k = add_box("Kanat", -0.405, 0.405, 0.145, 1.765, 0.030, 0.115)
# Buyuk dikey pencere boslugu (on yuzden oyulur, arkada ince cidar kalir)
boolean(obj_k, add_box("cv", -0.32, -0.14, 0.62, 1.50, -0.05, 0.085))
# Kucuk yatay pencere (sag ust)
boolean(obj_k, add_box("cs", 0.10, 0.28, 1.02, 1.16, -0.05, 0.085))
recalc(obj_k)

# --- Pencere girintilerinin on kenarini egimle (pahli pencere cercevesi) ---
def _on_k(c):
    return c.y <= 0.030 + EPS
def _rect_kenar(c, x0, x1, z0, z1):
    onx = (yakin(c.x, x0) or yakin(c.x, x1)) and (z0 - EPS <= c.z <= z1 + EPS)
    onz = (yakin(c.z, z0) or yakin(c.z, z1)) and (x0 - EPS <= c.x <= x1 + EPS)
    return onx or onz
def _pencere(c):
    return _rect_kenar(c, -0.32, -0.14, 0.62, 1.50) or _rect_kenar(c, 0.10, 0.28, 1.02, 1.16)
bevel_edges(obj_k,
            lambda a, b: _on_k(a) and _on_k(b) and _pencere(a) and _pencere(b),
            offset=0.022, segments=1)
# Panel dis cevresinin on kenarini hafifce pahla
bevel_edges(obj_k,
            lambda a, b: _on_k(a) and _on_k(b)
            and _rect_kenar(a, -0.405, 0.405, 0.145, 1.765)
            and _rect_kenar(b, -0.405, 0.405, 0.145, 1.765),
            offset=0.012, segments=1)
recalc(obj_k)
obj_k.data.materials.append(mat_kanat)

# Camlar (ayri obje, cam materyali) - bosluk icine, on yuzun biraz gerisine
gv = add_box("camV", -0.31, -0.15, 0.63, 1.49, 0.065, 0.075); gv.data.materials.append(mat_cam)
gs = add_box("camS",  0.11,  0.27, 1.03, 1.15, 0.065, 0.075); gs.data.materials.append(mat_cam)
# Tus takimi (one dogru cikinti kutu, sag alt) - on kenari pahli
kp = add_box("Panel", 0.12, 0.27, 0.74, 0.92, -0.020, 0.040)
bevel_edges(kp, lambda a, b: (a.y <= -0.020 + EPS) and (b.y <= -0.020 + EPS),
            offset=0.008, segments=1)
kp.data.materials.append(mat_panel)

# Cam + panel -> kanat icine birlestir (kapi ile birlikte doner)
bpy.ops.object.select_all(action='DESELECT')
for o in (obj_k, gv, gs, kp):
    o.select_set(True)
bpy.context.view_layer.objects.active = obj_k
bpy.ops.object.join()

# UV
unwrap(obj_c)
unwrap(obj_k)

# ================================================================ ONIZLEME RENDER
# (kanat hala dogru dunya konumunda: x -0.405..0.405)
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
bpy.context.collection.objects.link(cam)
cam.location = Vector((-1.55, -2.55, 1.35))
target = Vector((0.0, 0.0, 1.0))
cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam_data.lens = 50

# isiklar
key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'AREA'))
bpy.context.collection.objects.link(key)
key.data.energy = 400; key.data.size = 3.0
key.location = Vector((2.5, -2.5, 3.0))
key.rotation_euler = (target - key.location).to_track_quat('-Z', 'Y').to_euler()

fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", 'AREA'))
bpy.context.collection.objects.link(fill)
fill.data.energy = 120; fill.data.size = 4.0
fill.location = Vector((-2.5, -2.0, 1.5))
fill.rotation_euler = (target - fill.location).to_track_quat('-Z', 'Y').to_euler()

world = bpy.data.worlds.new("W"); bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.4

sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 48
sc.cycles.use_denoising = False
sc.render.resolution_x = 900
sc.render.resolution_y = 900
sc.view_settings.view_transform = 'AgX'
sc.render.filepath = "/tmp/kapi_preview.png"
bpy.ops.render.render(write_still=True)
print(">>> ONIZLEME yazildi: /tmp/kapi_preview.png")

# ================================================================ EXPORT
os.makedirs(os.path.join(PROJE, "models"), exist_ok=True)

# Kanatin origin'ini menteseye (sol kenar, orta derinlik) tasi, sonra dunya 0'a goturup bake et
# mentese: sol kenar (x=-0.405), derinlik ortasi (y=0.0725), dusey eksen
bpy.context.scene.cursor.location = Vector((-0.405, 0.0725, 0.0))
bpy.ops.object.select_all(action='DESELECT')
obj_k.select_set(True)
bpy.context.view_layer.objects.active = obj_k
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
obj_k.location = (0.0, 0.0, 0.0)
bpy.ops.object.transform_apply(location=True)

def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path, use_selection=True,
        export_format='GLB', export_yup=True,
        export_apply=True,
    )
    print(">>> export:", path)

export(obj_c, os.path.join(PROJE, "models", "kapi_cerceve.glb"))
export(obj_k, os.path.join(PROJE, "models", "kapi_kanat.glb"))
print(">>> BITTI")
