# -*- coding: utf-8 -*-
# Backrooms - Sci-fi kapi modeli ureticisi (Blender 4.x, headless)
# Kullanim:  blender -b -P tools/kapi_uretici/kapi_olustur.py
#
# Tum olculer .claude/skills/gorsel-haritalama ile referans gorselden CIKARILDI:
#   - rembg temiz siluet, FastSAM oge maskeleri, alt-piksel kenar
#   - EN/BOY orani PERSPEKTIFTEN hesaplandi (varsayim yok): 0.639
# Oge konumlari nx,ny (on yuz [0..1]) olarak verilir; X()/Z() ile metreye cevrilir.

import bpy, bmesh, os, math
from mathutils import Vector

PROJE = "/home/user/Backrooms"
bpy.ops.wm.read_factory_settings(use_empty=True)

# ===== GERCEK OLCEK (perspektiften oran 0.639) =====
EN, BOY = 1.31, 2.05            # m ; EN/BOY = 0.6390
def X(nx): return round(-EN/2 + nx*EN, 4)   # sol(0)->sag(1)
def Z(ny): return round(BOY*(1.0-ny), 4)    # ust(ny=0)->z=BOY

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
    return [(x0+c, z0), (x1-c, z0), (x1, z0+c), (x1, z1-c),
            (x1-c, z1), (x0+c, z1), (x0, z1-c), (x0, z0+c)]

def add_prism(name, pts_xz, y0, y1):
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

# ===== OLCULEN nx,ny FRAKSIYONLARI (skill ciktisi) =====
# pah: duz ust nx[0.12,0.88], inis ny 0.095
PAH_X0, PAH_X1, PAH_NY = 0.12, 0.88, 0.095
# aciklik(panel): nx[0.141,0.862] ny[0.091,0.901]
AC = (0.141, 0.862, 0.091, 0.901)
# pencere: nx[0.237,0.401] ny[0.135,0.572]
PEN = (0.237, 0.401, 0.135, 0.572)
# plaka: nx[0.650,0.832] ny[0.391,0.663]
PLK = (0.650, 0.832, 0.391, 0.663)
# vent: nx[0.682,0.802] ny[0.413,0.477] (5 izgara)
VNT = (0.682, 0.802, 0.413, 0.477)
# slot: nx[0.724,0.817] ny[0.530,0.651]
SLT = (0.724, 0.817, 0.530, 0.651)

# ================================================================ CERCEVE
mesh = bpy.data.meshes.new("cerceve_mesh")
obj_c = bpy.data.objects.new("Cerceve", mesh)
bpy.context.collection.objects.link(obj_c)
bm = bmesh.new()
zv = Z(PAH_NY)   # dusey kenar ust z
pts = [(X(0.0), 0.0), (X(0.0), zv), (X(PAH_X0), BOY),
       (X(PAH_X1), BOY), (X(1.0), zv), (X(1.0), 0.0)]
vs = [bm.verts.new((x, 0.0, z)) for x, z in pts]
f = bm.faces.new(vs)
r = bmesh.ops.extrude_face_region(bm, geom=[f])
ev = [g for g in r['geom'] if isinstance(g, bmesh.types.BMVert)]
bmesh.ops.translate(bm, vec=(0, 0.16, 0), verts=ev)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(mesh); bm.free()

ax0, ax1, az0, az1 = X(AC[0]), X(AC[1]), Z(AC[3]), Z(AC[2])   # aciklik abs
boolean(obj_c, add_box("cut_op", ax0, ax1, az0, az1, -0.10, 0.30))
recalc(obj_c)

def _on(c): return c.y <= EPS
def _aci(c):
    if (yakin(c.x, ax0) or yakin(c.x, ax1)) and (az0-0.01 <= c.z <= az1+0.01): return True
    if (yakin(c.z, az0) or yakin(c.z, az1)) and (ax0-0.01 <= c.x <= ax1+0.01): return True
    return False
bevel_edges(obj_c, lambda a, b: _on(a) and _on(b) and _aci(a) and _aci(b),
            offset=0.06, segments=1)
recalc(obj_c)
obj_c.data.materials.append(mat_cerceve)
unwrap(obj_c)

# ================================================================ KANAT
# panel: aciklik icine kucuk bosluk
px0, px1, pz0, pz1 = ax0+0.01, ax1-0.01, az0+0.012, az1-0.012
obj_k = add_box("Kanat", px0, px1, pz0, pz1, 0.030, 0.115)

# pencere (oktagonal, derin)
wx0, wx1, wz0, wz1 = X(PEN[0]), X(PEN[1]), Z(PEN[3]), Z(PEN[2])
boolean(obj_k, add_prism("cutV", cham_rect(wx0, wx1, wz0, wz1, 0.027), -0.05, 0.085))
recalc(obj_k)
obj_k.data.materials.append(mat_kanat)

def _onk(c): return c.y <= 0.030 + EPS
def _rk(c, x0, x1, z0, z1):
    onx = (yakin(c.x, x0) or yakin(c.x, x1)) and (z0-0.04 <= c.z <= z1+0.04)
    onz = (yakin(c.z, z0) or yakin(c.z, z1)) and (x0-0.04 <= c.x <= x1+0.04)
    return onx or onz
bevel_edges(obj_k, lambda a, b: _onk(a) and _onk(b)
            and _rk(a, wx0, wx1, wz0, wz1) and _rk(b, wx0, wx1, wz0, wz1),
            offset=0.016, segments=1)
bevel_edges(obj_k, lambda a, b: _onk(a) and _onk(b)
            and _rk(a, px0, px1, pz0, pz1) and _rk(b, px0, px1, pz0, pz1),
            offset=0.012, segments=1)
recalc(obj_k)

ekler = []
# cam
gv = add_prism("camV", cham_rect(wx0+0.008, wx1-0.008, wz0+0.01, wz1-0.01, 0.024), 0.066, 0.078)
gv.data.materials.append(mat_cam); ekler.append(gv)

# kabarik plaka
plx0, plx1, plz0, plz1 = X(PLK[0]), X(PLK[1]), Z(PLK[3]), Z(PLK[2])
plaka = add_box("Plaka", plx0, plx1, plz0, plz1, -0.006, 0.04)
bevel_edges(plaka, lambda a, b: (a.y <= -0.006+EPS) and (b.y <= -0.006+EPS),
            offset=0.006, segments=1)
recalc(plaka); plaka.data.materials.append(mat_kanat); ekler.append(plaka)

# vent + 5 izgara
vx0, vx1, vz0, vz1 = X(VNT[0]), X(VNT[1]), Z(VNT[3]), Z(VNT[2])
vent = add_box("Vent", vx0, vx1, vz0, vz1, -0.020, 0.04)
for z in [vz0 + (vz1-vz0)*(i+0.5)/5 for i in range(5)]:
    boolean(vent, add_box("ol", vx0+0.012, vx1-0.012, z-0.007, z+0.007, -0.05, 0.004))
bevel_edges(vent, lambda a, b: (a.y <= -0.020+EPS) and (b.y <= -0.020+EPS),
            offset=0.005, segments=1)
recalc(vent); vent.data.materials.append(mat_kanat); ekler.append(vent)

# slot (oktagonal pill, girintili)
sx0, sx1, sz0, sz1 = X(SLT[0]), X(SLT[1]), Z(SLT[3]), Z(SLT[2])
slot = add_prism("Slot", cham_rect(sx0, sx1, sz0, sz1, 0.042), -0.014, 0.04)
boolean(slot, add_prism("cutS", cham_rect(sx0+0.022, sx1-0.022, sz0+0.025, sz1-0.025, 0.03), -0.05, 0.020))
bevel_edges(slot, lambda a, b: (a.y <= -0.014+EPS) and (b.y <= -0.014+EPS),
            offset=0.005, segments=1)
recalc(slot); slot.data.materials.append(mat_kanat); ekler.append(slot)

join(obj_k, ekler)
unwrap(obj_k)
HINGE_X = px0   # menteseden donus icin sol kenar

# ================================================================ ONIZLEME (perspektif)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
bpy.context.collection.objects.link(cam)
cam.location = Vector((-1.6, -2.6, 1.30)); cam.data.lens = 50
hed = Vector((0.0, 0.0, 1.0))
cam.rotation_euler = (hed - cam.location).to_track_quat('-Z', 'Y').to_euler()

def isik(e, sz, loc):
    L = bpy.data.objects.new("L", bpy.data.lights.new("L", 'AREA'))
    bpy.context.collection.objects.link(L); L.data.energy = e; L.data.size = sz
    L.location = Vector(loc)
    L.rotation_euler = (hed - L.location).to_track_quat('-Z', 'Y').to_euler()
isik(400, 3.0, (2.5, -2.5, 3.0)); isik(120, 4.0, (-2.5, -2.0, 1.5))

w = bpy.data.worlds.new("W"); bpy.context.scene.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.4

sc = bpy.context.scene; sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 48; sc.cycles.use_denoising = False
sc.render.resolution_x = int(900*EN/BOY); sc.render.resolution_y = 900
sc.view_settings.view_transform = 'AgX'
sc.render.filepath = "/tmp/kapi_preview.png"
bpy.ops.render.render(write_still=True)
print(">>> ONIZLEME: /tmp/kapi_preview.png")

# ortografik ON (dogrulama icin)
camo = bpy.data.objects.new("CamO", bpy.data.cameras.new("CamO"))
bpy.context.collection.objects.link(camo)
camo.data.type = 'ORTHO'; camo.data.ortho_scale = BOY
camo.location = Vector((0.0, -3.0, BOY/2)); camo.rotation_euler = (math.radians(90), 0, 0)
sc.camera = camo
sc.render.film_transparent = True
sc.render.resolution_x = int(1000*EN/BOY); sc.render.resolution_y = 1000
sc.render.filepath = "/tmp/kapi_front.png"
bpy.ops.render.render(write_still=True)
sc.render.film_transparent = False
print(">>> ON ORTO: /tmp/kapi_front.png")

# ================================================================ EXPORT
os.makedirs(os.path.join(PROJE, "models"), exist_ok=True)
bpy.context.scene.cursor.location = Vector((HINGE_X, 0.0725, 0.0))
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
print(">>> HINGE_X=%.4f  EN=%.3f BOY=%.3f" % (HINGE_X, EN, BOY))
print(">>> BITTI")
