# -*- coding: utf-8 -*-
# Backrooms - Sci-fi kapi modeli ureticisi (Blender 4.x, headless) - DETAYLI
# Kullanim:  blender -b -P tools/kapi_uretici/kapi_olustur.py
#
# Tum olculer .claude/skills/gorsel-haritalama (analiz.py DETAYLI surum) ile
# referans gorselden CIKARILDI:
#   - rembg temiz siluet, FastSAM oge maskeleri, alt-piksel kenar
#   - EN/BOY orani PERSPEKTIFTEN hesaplandi (varsayim yok): 0.639
#   - ic-ice alt-ogeler (vent oct cerceve+izgara, slot cep+kabarik cubuk)
#   - civatalar zoom-grid'den birebir okundu (2 sutun x 3 satir)
# Oge konumlari nx,ny (on yuz [0..1]) olarak verilir; X()/Z() ile metreye cevrilir.
#
# KENAR KALITESI: her parca temizle() -> merge-doubles + limited-dissolve +
# recalc-normals + SHADE FLAT; ardindan genel kucuk pah ile keskin kenarlar
# isigi yakalar (render'da "kirik/testere" kenar olmaz).

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
mat_civata  = mat("kapi_civata",  (0.22, 0.21, 0.20), 0.90, 0.45)

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
    """Oktagonal (8 koseli pahli dikdortgen) on yuz noktalari."""
    return [(x0+c, z0), (x1-c, z0), (x1, z0+c), (x1, z1-c),
            (x1-c, z1), (x0+c, z1), (x0, z1-c), (x0, z0+c)]

def rounded_rect(x0, x1, z0, z1, r, seg=8):
    """Yuvarlatilmis dikdortgen / KAPSUL (r=yari-en) on yuz noktalari (CCW)."""
    r = min(r, (x1-x0)/2, (z1-z0)/2)
    merkez = [(x1-r, z0+r), (x1-r, z1-r), (x0+r, z1-r), (x0+r, z0+r)]
    bas = [-math.pi/2, 0.0, math.pi/2, math.pi]
    pts = []
    for (cx, cz), a0 in zip(merkez, bas):
        for k in range(seg+1):
            a = a0 + (math.pi/2)*k/seg
            pts.append((cx + r*math.cos(a), cz + r*math.sin(a)))
    return pts

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

def add_cyl(name, cx, cz, r, y0, y1, dome=0.0, verts=20):
    """Civata/rivet: silindir + (istege bagli) hafif kubbe on yuzu."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=(y1-y0))
    o = bpy.context.active_object; o.name = name
    o.rotation_euler = (math.radians(90), 0, 0)   # ekseni Y'ye cevir
    bpy.ops.object.transform_apply(rotation=True)
    o.location = (cx, (y0+y1)/2, cz)
    bpy.ops.object.transform_apply(location=True)
    if dome > 0.0:                                  # on yuze hafif sisme
        me = o.data; bm = bmesh.new(); bm.from_mesh(me)
        ymin = min(v.co.y for v in bm.verts)
        for v in bm.verts:
            if abs(v.co.y - ymin) < 1e-4:
                d = math.hypot(v.co.x - cx, v.co.z - cz)
                v.co.y -= dome * max(0.0, 1.0 - (d/r)**2)
        bm.normal_update(); bm.to_mesh(me); bm.free()
    return o

def boolean(target, cutter, op='DIFFERENCE'):
    m = target.modifiers.new("b", 'BOOLEAN'); m.operation = op
    m.solver = 'EXACT'; m.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter, do_unlink=True)

def bevel_edges(obj, predicate, offset, segments=1, profile=0.5):
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if predicate(e.verts[0].co, e.verts[1].co)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=profile, affect='EDGES', clamp_overlap=True)
    bm.normal_update(); bm.to_mesh(me); bm.free()

def temizle(obj, dissolve_aci=math.radians(1.5)):
    """KENAR TEMIZLIGI: boolean artiklarini sil, normalleri duzelt, FLAT golge.
    - merge by distance: cakisik vertexleri birlestir
    - limited dissolve: coplanar bool kesim cizgilerini temizle
    - recalc normals: disa donuk
    - shade flat: hard-surface (smooth golgeleme artefakti olmaz)"""
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=5e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=dissolve_aci,
                             verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False

def genel_pah(obj, offset=0.0025, segments=2):
    """Tum keskin (acili) kenarlara kucuk tek-tip pah: razor kenar kalmaz,
    isigi yakalar -> render'da temiz, 'kirik' gorunmeyen kenar."""
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(25)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=0.7, affect='EDGES', clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False

def unwrap(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

EPS = 1.5e-3
def yakin(a, b): return abs(a-b) < EPS
def join(hedef, digerleri):
    bpy.ops.object.select_all(action='DESELECT')
    for o in [hedef]+digerleri: o.select_set(True)
    bpy.context.view_layer.objects.active = hedef
    bpy.ops.object.join()

# ===== OLCULEN nx,ny FRAKSIYONLARI (skill DETAYLI ciktisi + 50x zoom okuma) =====
# pah: duz ust nx[0.13,0.865], inis ny 0.094
PAH_X0, PAH_X1, PAH_NY = 0.13, 0.865, 0.094
# aciklik(panel recess): nx[0.14,0.86] ny[0.09,0.90]
AC = (0.14, 0.86, 0.09, 0.90)
# pencere recess (oct, cam+ic cerceve): nx[0.232,0.388] ny[0.150,0.560]
PEN  = (0.232, 0.388, 0.150, 0.560)
# pencere CAM (ic, oct): nx[0.250,0.372] ny[0.166,0.548]
PENC = (0.250, 0.372, 0.166, 0.548)
# pencere cevresi PERCIN'leri (50x zoom'dan): sol/sag dikey + ust/alt yatay
PEN_RV_SOL, PEN_RV_SAG = 0.221, 0.399
PEN_RV_UST, PEN_RV_ALT = 0.138, 0.572
PEN_RV_DY = [0.185, 0.272, 0.359, 0.446, 0.525]   # dikey siralarda ny
PEN_RV_DX = [0.272, 0.310, 0.348]                 # yatay siralarda nx
RIVET_R = 0.0052
# plaka (kabarik panel): nx[0.645,0.835] ny[0.388,0.665]
PLK = (0.645, 0.835, 0.388, 0.665)
# vent oct cerceve: nx[0.665,0.815] ny[0.398,0.495] ; ic izgara + 6 oluk (7 slat)
VNT  = (0.665, 0.815, 0.398, 0.495)
VNTI = (0.685, 0.795, 0.415, 0.485)
IZGARA = 6
# kapi kolu: girintili cep nx[0.665,0.815] ny[0.518,0.655] + ic KAPSUL pull-bar
SLT  = (0.665, 0.815, 0.518, 0.655)
SLTB = (0.757, 0.794, 0.535, 0.640)               # ince dikey kapsul (sagda)
# civatalar (zoom-grid'den): 2 sutun x 3 satir
CIV_NX = [0.675, 0.805]
CIV_NY = [0.405, 0.515, 0.648]
CIV_R  = 0.0085

# derinlik referanslari (m)
Y_FRAME_ON = 0.0       # cerceve on yuzu
Y_KANAT_ON = 0.030     # kanat on yuzu (cerceveden geride)
Y_KANAT_AR = 0.115     # kanat arka yuzu

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

# OLCULEN COK-KADEMELI PROFIL (50x kesit): duz dis pervaz -> pah ->
# DERIN oluk kanali -> pah -> ic panel. Iki kademe ile daha belirgin derinlik.
KANAL = 0.034    # kanal bandi genisligi (m)
ON1 = 0.020      # dis pervaz ile ic basamak arasi sig kademe
DIP = 0.060      # kanal (oluk) tabani derinligi -> belirgin golge
# 1) dis pervazdan ic basamaga sig inis
boolean(obj_c, add_box("kademe1", ax0-KANAL-0.018, ax1+KANAL+0.018,
                       az0-KANAL-0.018, az1+KANAL+0.018, -0.02, ON1))
# 2) derin oluk kanali
boolean(obj_c, add_box("kanal", ax0-KANAL, ax1+KANAL, az0-KANAL, az1+KANAL, ON1-0.005, DIP))

def _on(c): return c.y <= EPS                      # dis pervaz on yuzu (y=0)
def _kademe(c): return abs(c.y - ON1) < 0.012      # ic basamak yuzu
def _band(c, rx0, rx1, rz0, rz1):
    if (yakin(c.x, rx0) or yakin(c.x, rx1)) and (rz0-0.012 <= c.z <= rz1+0.012): return True
    if (yakin(c.z, rz0) or yakin(c.z, rz1)) and (rx0-0.012 <= c.x <= rx1+0.012): return True
    return False
rx0, rx1 = ax0-KANAL-0.018, ax1+KANAL+0.018
rz0, rz1 = az0-KANAL-0.018, az1+KANAL+0.018
# dis pervaz -> basamak gecisini pahla
bevel_edges(obj_c, lambda a, b: _on(a) and _on(b)
            and _band(a, rx0, rx1, rz0, rz1) and _band(b, rx0, rx1, rz0, rz1),
            offset=0.010, segments=2)
# basamak -> kanal gecisini pahla
k0, k1 = ax0-KANAL, ax1+KANAL
kz0, kz1 = az0-KANAL, az1+KANAL
bevel_edges(obj_c, lambda a, b: _kademe(a) and _kademe(b)
            and _band(a, k0, k1, kz0, kz1) and _band(b, k0, k1, kz0, kz1),
            offset=0.008, segments=2)
def _kanal_dip(c): return abs(c.y - DIP) < 0.012
def _ack(c): return _band(c, ax0, ax1, az0, az1)
# kanal tabani -> ic panel (aciklik) gecisini pahla
bevel_edges(obj_c, lambda a, b: _kanal_dip(a) and _kanal_dip(b) and _ack(a) and _ack(b),
            offset=0.018, segments=2)
temizle(obj_c); genel_pah(obj_c, 0.003, 2)
obj_c.data.materials.append(mat_cerceve)
unwrap(obj_c)

# ================================================================ KANAT
px0, px1, pz0, pz1 = ax0+0.01, ax1-0.01, az0+0.012, az1-0.012
obj_k = add_box("Kanat", px0, px1, pz0, pz1, Y_KANAT_ON, Y_KANAT_AR)
obj_k.data.materials.append(mat_kanat)
ekler = []

# ---------------------------------------------------------- PENCERE (cift cerceve + percin)
wx0, wx1, wz0, wz1 = X(PEN[0]), X(PEN[1]), Z(PEN[3]), Z(PEN[2])
cx0, cx1, cz0, cz1 = X(PENC[0]), X(PENC[1]), Z(PENC[3]), Z(PENC[2])
WIN_LEDGE = 0.050      # dis recess tabani (ic cerceve ledge yuzu)
# 1) dis oct girinti (sig well, ledge'e kadar) -> on chamfer rim + ic cerceve halkasi
boolean(obj_k, add_prism("cutW1", cham_rect(wx0, wx1, wz0, wz1, 0.024), Y_KANAT_ON-0.001, WIN_LEDGE))
# 2) ic oct girinti (cam boyu, ledge'den arkaya derin) -> ikinci kademe (cift cerceve)
boolean(obj_k, add_prism("cutW2", cham_rect(cx0, cx1, cz0, cz1, 0.018), WIN_LEDGE-0.004, Y_KANAT_AR+0.01))

def _onk(c): return c.y <= Y_KANAT_ON + EPS
def _ledge(c): return abs(c.y - WIN_LEDGE) < 0.012
def _rk(c, x0, x1, z0, z1):
    onx = (yakin(c.x, x0) or yakin(c.x, x1)) and (z0-0.05 <= c.z <= z1+0.05)
    onz = (yakin(c.z, z0) or yakin(c.z, z1)) and (x0-0.05 <= c.x <= x1+0.05)
    return onx or onz
# dis pencere agzini pahla (on chamfer)
bevel_edges(obj_k, lambda a, b: _onk(a) and _onk(b)
            and _rk(a, wx0, wx1, wz0, wz1) and _rk(b, wx0, wx1, wz0, wz1),
            offset=0.012, segments=2)
# ic cerceve (ledge) agzini pahla -> ikinci rim
bevel_edges(obj_k, lambda a, b: _ledge(a) and _ledge(b)
            and _rk(a, cx0, cx1, cz0, cz1) and _rk(b, cx0, cx1, cz0, cz1),
            offset=0.008, segments=2)

# --- pencere cevresi PERCIN'leri (panel yuzunde, recess disinda) ---
def rivet(nx, ny, tag):
    r = add_cyl("Rivet_%s" % tag, X(nx), Z(ny), RIVET_R,
                Y_KANAT_ON-0.004, Y_KANAT_ON+0.0015, dome=0.0028, verts=14)
    temizle(r); r.data.materials.append(mat_kanat); ekler.append(r)
for j, ny in enumerate(PEN_RV_DY):
    rivet(PEN_RV_SOL, ny, "L%d" % j); rivet(PEN_RV_SAG, ny, "R%d" % j)
for i, nx in enumerate(PEN_RV_DX):
    rivet(nx, PEN_RV_UST, "T%d" % i); rivet(nx, PEN_RV_ALT, "B%d" % i)

# ---------------------------------------------------------- PLAKA (kabarik panel)
plx0, plx1, plz0, plz1 = X(PLK[0]), X(PLK[1]), Z(PLK[3]), Z(PLK[2])
Y_PLK_ON = 0.012       # plaka on yuzu (kanattan ileri -> kabarik)
plaka = add_box("Plaka", plx0, plx1, plz0, plz1, Y_PLK_ON, Y_KANAT_ON+0.004)
plaka.data.materials.append(mat_kanat)

# --- vent: SIG oct girinti (tabani var) + 6 yatay oluk (delik degil) ---
vx0, vx1, vz0, vz1 = X(VNT[0]), X(VNT[1]), Z(VNT[3]), Z(VNT[2])
VENT_DIP = 0.024       # girinti tabani (plaka on=0.012, arka=0.034)
boolean(plaka, add_prism("cutV", cham_rect(vx0, vx1, vz0, vz1, 0.018), Y_PLK_ON-0.001, VENT_DIP))
# izgara olukları: vent tabanina KISMI derin yatay yivler -> aralarinda rib(slat) kalir
ivx0, ivx1, ivz0, ivz1 = X(VNTI[0]), X(VNTI[1]), Z(VNTI[3]), Z(VNTI[2])
step = (ivz1 - ivz0) / IZGARA
for i in range(IZGARA):
    zc = ivz0 + step*(i+0.5)
    boolean(plaka, add_box("oluk%d" % i, ivx0, ivx1, zc-step*0.30, zc+step*0.30,
                           VENT_DIP-0.002, 0.0325))

# --- KAPI KOLU: DERIN girintili cep (yuvarlatilmis) + ic KAPSUL pull-bar ---
sx0, sx1, sz0, sz1 = X(SLT[0]), X(SLT[1]), Z(SLT[3]), Z(SLT[2])
# cep tabani kanat yuzeyinde (Y_KANAT_ON=0.030) -> belirgin derinlik
boolean(plaka, add_prism("cutS", rounded_rect(sx0, sx1, sz0, sz1, 0.020, 8),
                         Y_PLK_ON-0.001, 0.060))
temizle(plaka)
# cebin agiz kenarini pahla
def _plon(c): return c.y <= Y_PLK_ON + EPS
bevel_edges(plaka, lambda a, b: _plon(a) and _plon(b), offset=0.005, segments=2)
genel_pah(plaka, 0.0022, 2)
ekler.append(plaka)

# pull-bar: ince DIKEY KAPSUL (yuvarlak uclu), cebin sag tarafinda, dibinden yukselir
bx0, bx1, bz0, bz1 = X(SLTB[0]), X(SLTB[1]), Z(SLTB[3]), Z(SLTB[2])
kapsul = add_prism("KapiKolu", rounded_rect(bx0, bx1, bz0, bz1, (bx1-bx0)/2, 10),
                   0.010, Y_KANAT_ON+0.004)
temizle(kapsul); genel_pah(kapsul, 0.0018, 2)
kapsul.data.materials.append(mat_kanat); ekler.append(kapsul)

# --- cam (ic kademenin arkasinda) ---
gv = add_prism("Cam", cham_rect(cx0+0.004, cx1-0.004, cz0+0.006, cz1-0.006, 0.016), 0.068, 0.080)
temizle(gv); gv.data.materials.append(mat_cam); ekler.append(gv)

# --- civatalar (6: 2 sutun x 3 satir) ---
for j, ny in enumerate(CIV_NY):
    for i, nx in enumerate(CIV_NX):
        b = add_cyl("Civata_%d_%d" % (j, i), X(nx), Z(ny), CIV_R,
                    Y_PLK_ON-0.006, Y_PLK_ON+0.004, dome=0.004, verts=18)
        temizle(b); b.data.materials.append(mat_civata); ekler.append(b)

# kanat govdesini temizle + birlestir
temizle(obj_k); genel_pah(obj_k, 0.0022, 2)
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
print(">>> HINGE_X=%.4f  EN=%.3f BOY=%.3f  izgara=%d civata=%d"
      % (HINGE_X, EN, BOY, IZGARA, len(CIV_NX)*len(CIV_NY)))
print(">>> BITTI")
