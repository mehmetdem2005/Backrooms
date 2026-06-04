# -*- coding: utf-8 -*-
# Backrooms - Sci-fi kapi modeli ureticisi (Blender 4.x, headless)
# Kullanim:  blender -b -P tools/kapi_uretici/kapi_olustur.py
#
# Olculer .claude/skills/gorsel-haritalama ile referans gorselden CIKARILDI
# (perspektif duzeltilmis on yuz, 0..1 normalize). Donusum:
#   x = -0.55 + nx*1.10        (sol->sag, toplam en 1.10 m)
#   z =  2.10 - ny*2.10        (ust ny=0 -> z=2.10, toplam boy 2.10 m)
#
# Uretir:
#   models/kapi_cerceve.glb  -> sabit cerceve (pahli ust + egimli ic kenar)
#   models/kapi_kanat.glb    -> acilan kanat (oktagonal pencere, izgarali vent,
#                               hap-yuva), origin sol menteseye tasinmis
#   /tmp/kapi_preview.png

import bpy, bmesh, os
from mathutils import Vector

PROJE = "/home/user/Backrooms"
bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- materyaller
def mat(name, color, metallic=0.7, rough=0.6, alpha=1.0, transmission=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    def s(k, v):
        if k in b.inputs: b.inputs[k].default_value = v
    s("Base Color", (*color, 1.0)); s("Metallic", metallic); s("Roughness", rough)
    if alpha < 1.0: s("Alpha", alpha); m.blend_method = 'BLEND'
    if transmission > 0.0: s("Transmission Weight", transmission)
    return m

mat_cerceve = mat("kapi_cerceve", (0.30, 0.28, 0.26), 0.85, 0.55)
mat_kanat   = mat("kapi_kanat",   (0.46, 0.44, 0.41), 0.70, 0.60)
mat_cam     = mat("kapi_cam",     (0.03, 0.04, 0.05), 0.10, 0.10, alpha=0.6, transmission=0.5)
mat_koyu    = mat("kapi_koyu",    (0.09, 0.09, 0.10), 0.55, 0.45)

# ---------------------------------------------------------------- yardimcilar
# Blender Z-up: x=genislik, z=yukseklik, y=derinlik (on yuz dusuk y, -Y'ye bakar)
def add_box(name, x0, x1, h0, h1, d0, d1):
    bpy.ops.mesh.primitive_cube_add()
    o = bpy.context.active_object; o.name = name
    o.scale = ((x1-x0)/2, (d1-d0)/2, (h1-h0)/2)
    o.location = ((x0+x1)/2, (d0+d1)/2, (h0+h1)/2)
    bpy.ops.object.transform_apply(location=True, scale=True, rotation=True)
    return o

def cham_rect(x0, x1, z0, z1, c):
    """Pahli koseli dikdortgen (oktagon) - (x,z) nokta listesi."""
    return [(x0+c, z0), (x1-c, z0), (x1, z0+c), (x1, z1-c),
            (x1-c, z1), (x0+c, z1), (x0, z1-c), (x0, z0+c)]

def add_prism(name, pts_xz, y0, y1):
    """(x,z) profilini y0..y1 derinlige extrude eden prizma."""
    me = bpy.data.meshes.new(name); o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bm = bmesh.new()
    vs = [bm.verts.new((x, y0, z)) for (x, z) in pts_xz]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    ev = [g for g in r['geom'] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, y1-y0, 0), verts=ev)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    return o

def boolean(target, cutter, op='DIFFERENCE'):
    m = target.modifiers.new("b", 'BOOLEAN'); m.operation = op
    m.solver = 'EXACT'; m.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

def recalc(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')

def unwrap(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

def bevel_edges(obj, predicate, offset, segments=1, profile=0.5):
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if predicate(e.verts[0].co, e.verts[1].co)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=profile, affect='EDGES', clamp_overlap=True)
    bm.normal_update(); bm.to_mesh(me); bm.free()

EPS = 1.5e-3
def yakin(a, b): return abs(a-b) < EPS
def join(hedef, digerleri):
    bpy.ops.object.select_all(action='DESELECT')
    for o in [hedef]+digerleri: o.select_set(True)
    bpy.context.view_layer.objects.active = hedef
    bpy.ops.object.join()

# ================================================================ CERCEVE
# Olculen ust pah: duz ust nx[0.18,0.82]-> x[-0.352,0.352]; inis ny=0.12-> z=1.848
mesh = bpy.data.meshes.new("cerceve_mesh")
obj_c = bpy.data.objects.new("Cerceve", mesh)
bpy.context.collection.objects.link(obj_c)
bm = bmesh.new()
pts = [(-0.55, 0.00), (-0.55, 1.848), (-0.352, 2.10),
       ( 0.352, 2.10), ( 0.55, 1.848), ( 0.55, 0.00)]
vs = [bm.verts.new((x, 0.0, z)) for x, z in pts]
f = bm.faces.new(vs)
r = bmesh.ops.extrude_face_region(bm, geom=[f])
ev = [g for g in r['geom'] if isinstance(g, bmesh.types.BMVert)]
bmesh.ops.translate(bm, vec=(0, 0.16, 0), verts=ev)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh); bm.free()

# Ic aciklik (olculen panel sinirina gore): x[-0.425,0.425], z[0.135,1.90]
boolean(obj_c, add_box("cut_op", -0.425, 0.425, 0.135, 1.90, -0.10, 0.30))
recalc(obj_c)

# EGIM: ic on kenari genis pahla
def _on(c): return c.y <= EPS
def _aci(c):
    if yakin(abs(c.x), 0.425) and (0.13 <= c.z <= 1.905): return True
    if (yakin(c.z, 0.135) or yakin(c.z, 1.90)) and (abs(c.x) <= 0.43): return True
    return False
bevel_edges(obj_c, lambda a, b: _on(a) and _on(b) and _aci(a) and _aci(b),
            offset=0.06, segments=1)
recalc(obj_c)
obj_c.data.materials.append(mat_cerceve)
unwrap(obj_c)

# ================================================================ KANAT
# Panel: olculen x[0.12,0.86]->[-0.418,0.396], z ny[0.10,0.93]->[1.89,0.147]
obj_k = add_box("Kanat", -0.41, 0.41, 0.15, 1.89, 0.030, 0.115)

# --- Dikey oktagonal pencere: nx[0.255,0.43] ny[0.135,0.57] ---
PV = cham_rect(-0.27, -0.077, 0.90, 1.82, 0.028)
boolean(obj_k, add_prism("cutV", PV, -0.05, 0.085))   # on yuzden oy
recalc(obj_k)
obj_k.data.materials.append(mat_kanat)

# pencere on kenarini egimle
def _onk(c): return c.y <= 0.030 + EPS
def _pen(c):
    return any(yakin(c.x, px) or yakin(c.z, pz) for px, pz in
               [(-0.27, 0), (-0.077, 0)]) and (-0.28 <= c.x <= -0.06) and (0.89 <= c.z <= 1.83) \
        or ((yakin(c.z, 0.90) or yakin(c.z, 1.82)) and (-0.28 <= c.x <= -0.06))
bevel_edges(obj_k, lambda a, b: _onk(a) and _onk(b) and _pen(a) and _pen(b),
            offset=0.018, segments=1)

# panel dis cevre on kenarini hafifce pahla
def _cevre(c):
    onx = (yakin(c.x, -0.41) or yakin(c.x, 0.41)) and (0.14 <= c.z <= 1.90)
    onz = (yakin(c.z, 0.15) or yakin(c.z, 1.89)) and (abs(c.x) <= 0.415)
    return onx or onz
bevel_edges(obj_k, lambda a, b: _onk(a) and _onk(b) and _cevre(a) and _cevre(b),
            offset=0.012, segments=1)
recalc(obj_k)

ekler = []

# --- Cam (pencere arkasi) ---
gv = add_prism("camV", cham_rect(-0.262, -0.085, 0.91, 1.81, 0.026), 0.066, 0.078)
gv.data.materials.append(mat_cam); ekler.append(gv)

# --- VENT (izgarali, kabarik): nx[0.70,0.85] ny[0.37,0.495] -> x[0.22,0.385] z[1.06,1.323]
vent = add_box("Vent", 0.22, 0.385, 1.06, 1.323, -0.018, 0.04)
# yatay izgara oluklari (4 adet)
for zc in (1.095, 1.155, 1.215, 1.275):
    boolean(vent, add_box("ol", 0.236, 0.369, zc-0.013, zc+0.013, -0.05, 0.006))
# kenar pah
bevel_edges(vent, lambda a, b: (a.y <= -0.018+EPS) and (b.y <= -0.018+EPS),
            offset=0.006, segments=1)
recalc(vent); vent.data.materials.append(mat_kanat); ekler.append(vent)

# --- SLOT (hap, girintili): nx[0.70,0.83] ny[0.52,0.67] -> x[0.22,0.363] z[0.69,1.008]
# kabarik dis cerceve
slot = add_prism("Slot", cham_rect(0.22, 0.363, 0.69, 1.008, 0.045), -0.012, 0.04)
# ic girinti (oy)
boolean(slot, add_prism("cutS", cham_rect(0.246, 0.337, 0.716, 0.982, 0.035), -0.05, 0.022))
bevel_edges(slot, lambda a, b: (a.y <= -0.012+EPS) and (b.y <= -0.012+EPS),
            offset=0.006, segments=1)
recalc(slot); slot.data.materials.append(mat_kanat); ekler.append(slot)

# birlestir
join(obj_k, ekler)
unwrap(obj_k)

# ================================================================ ONIZLEME
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
bpy.context.collection.objects.link(cam)
cam.location = Vector((-1.55, -2.55, 1.35))
hedef = Vector((0.0, 0.0, 1.0))
cam.rotation_euler = (hedef - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 50

def isik(name, e, sz, loc):
    L = bpy.data.objects.new(name, bpy.data.lights.new(name, 'AREA'))
    bpy.context.collection.objects.link(L)
    L.data.energy = e; L.data.size = sz; L.location = Vector(loc)
    L.rotation_euler = (hedef - L.location).to_track_quat('-Z', 'Y').to_euler()
isik("Key", 400, 3.0, (2.5, -2.5, 3.0))
isik("Fill", 120, 4.0, (-2.5, -2.0, 1.5))

world = bpy.data.worlds.new("W"); bpy.context.scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.4

sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 48; sc.cycles.use_denoising = False
sc.render.resolution_x = 760; sc.render.resolution_y = 1000
sc.view_settings.view_transform = 'AgX'
sc.render.filepath = "/tmp/kapi_preview.png"
bpy.ops.render.render(write_still=True)
print(">>> ONIZLEME: /tmp/kapi_preview.png")

# ================================================================ EXPORT
os.makedirs(os.path.join(PROJE, "models"), exist_ok=True)
# kanat origin'ini menteseye (sol kenar, derinlik ortasi) tasi
bpy.context.scene.cursor.location = Vector((-0.41, 0.0725, 0.0))
bpy.ops.object.select_all(action='DESELECT'); obj_k.select_set(True)
bpy.context.view_layer.objects.active = obj_k
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
obj_k.location = (0.0, 0.0, 0.0)
bpy.ops.object.transform_apply(location=True)

def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True,
                              export_format='GLB', export_yup=True, export_apply=True)
    print(">>> export:", path)

export(obj_c, os.path.join(PROJE, "models", "kapi_cerceve.glb"))
export(obj_k, os.path.join(PROJE, "models", "kapi_kanat.glb"))
print(">>> BITTI")
