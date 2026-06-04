# -*- coding: utf-8 -*-
# GENEL haritadan-model insa araci (Blender 4.x, headless).
# analiz.py'nin urettigi harita.json + outline.json'u OKUR ve modeli
# OTOMATIK kurar. Hicbir objeye-ozel sabit YOK; her referans icin calisir.
#
# Kullanim:
#   blender -b -P insa.py -- <analiz_cikti_dizini> [--boy 2.05] [--out models]
#
# Tur-surumlu (type-driven) insa:
#   - siluet outline -> COK-KADEMELI cerceve (pervaz -> oluk kanali -> panel)
#   - panel (leaf) -> aciklik icini doldurur
#   - her ic_oge etiket/oran/alt_ogeler'e gore:
#       dikey_pencere  -> oct CIFT cerceve girinti + cam + cevre PERCIN
#       vent           -> oct sig girinti + N yatay izgara (izgara_sayisi)
#       kol (kabarik dikey_cubuk alt-oge) -> DERIN cep + KAPSUL pull-bar
#       buyuk+cocuklu  -> KABARIK plaka (cocuk ogeler uzerine girinti olur)
#       diger          -> girintili cep
#   - civatalar/percinler -> kubbeli silindirler
# KENAR: her parca temizle()+genel_pah() -> render'da kirik/testere kenar yok.

import bpy, bmesh, os, sys, json, math
from mathutils import Vector

# ----------------------------------------------------------------- argumanlar
argv = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
if not argv:
    raise SystemExit("Kullanim: blender -b -P insa.py -- <analiz_dizini> [--boy 2.05]")
ANALIZ = argv[0]
def _arg(ad, vars):
    return argv[argv.index(ad)+1] if ad in argv else vars
BOY = float(_arg("--boy", "2.05"))
OUTDIR = _arg("--out", "models")

with open(os.path.join(ANALIZ, "harita.json")) as f:
    H = json.load(f)
OUTLINE = None
op = os.path.join(ANALIZ, "outline.json")
if os.path.exists(op):
    with open(op) as f:
        OUTLINE = json.load(f).get("outline_normalize")

ORAN = H.get("en_boy_orani") or (H["gercek_en_boy"][0]/H["gercek_en_boy"][1])
EN = round(BOY * ORAN, 4)
def X(nx): return round(-EN/2 + nx*EN, 4)
def Z(ny): return round(BOY*(1.0-ny), 4)
S = (EN+BOY)/2.0                       # olcek referansi (yedek derinlikler icin)

# ---- DERINLIK ALGISI: haritadan olculen kalinlik + oge-basi derinlik ----
DRN = H.get("derinlik", {}) or {}
HBOY = (H.get("gercek_en_boy") or [ORAN, 1.0])[1] or 1.0
DSCALE = BOY / HBOY                    # harita-boy -> hedef-boy olcek
KAL_ORAN = DRN.get("kalinlik_orani")  # kalinlik / boy (olculemezse None)
if KAL_ORAN and KAL_ORAN > 0.012:
    KALINLIK = KAL_ORAN * BOY          # gercek kalinlik (m), olculen
    DERIN_KAYNAK = "olculen(kalinlik_orani=%.3f)" % KAL_ORAN
else:
    KALINLIK = 0.052 * S               # yedek varsayim (yan yuz gorunmuyorsa)
    DERIN_KAYNAK = "varsayim(yan yuz olculemedi)"

def oge_derinlik(o, yedek):
    """Ogenin olculen derinligi (m, hedef olcekte); yoksa yedek."""
    dm = o.get("derinlik_m")
    if dm and dm > 0:
        return max(0.004, dm * DSCALE)
    return yedek

bpy.ops.wm.read_factory_settings(use_empty=True)

# ----------------------------------------------------------------- materyaller
def mat(name, color, metallic=0.7, rough=0.6, alpha=1.0, transmission=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    def s(k, v):
        if k in b.inputs: b.inputs[k].default_value = v
    s("Base Color", (*color, 1.0)); s("Metallic", metallic); s("Roughness", rough)
    if alpha < 1.0: s("Alpha", alpha); m.blend_method = 'BLEND'
    if transmission > 0.0: s("Transmission Weight", transmission)
    return m
mat_cerceve = mat("cerceve", (0.30, 0.28, 0.26), 0.85, 0.55)
mat_govde   = mat("govde",   (0.46, 0.44, 0.41), 0.70, 0.60)
mat_cam     = mat("cam",     (0.03, 0.04, 0.05), 0.10, 0.10, alpha=0.6, transmission=0.5)
mat_metal   = mat("metal",   (0.22, 0.21, 0.20), 0.90, 0.45)

# ----------------------------------------------------------------- yardimcilar
def add_box(name, x0, x1, h0, h1, d0, d1):
    bpy.ops.mesh.primitive_cube_add()
    o = bpy.context.active_object; o.name = name
    o.scale = ((x1-x0)/2, (d1-d0)/2, (h1-h0)/2)
    o.location = ((x0+x1)/2, (d0+d1)/2, (h0+h1)/2)
    bpy.ops.object.transform_apply(location=True, scale=True, rotation=True)
    return o

def cham_rect(x0, x1, z0, z1, c):
    c = max(0.0, min(c, (x1-x0)/2*0.9, (z1-z0)/2*0.9))
    return [(x0+c, z0), (x1-c, z0), (x1, z0+c), (x1, z1-c),
            (x1-c, z1), (x0+c, z1), (x0, z1-c), (x0, z0+c)]

def rounded_rect(x0, x1, z0, z1, r, seg=8):
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

def add_cyl(name, cx, cz, r, y0, y1, dome=0.0, verts=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=(y1-y0))
    o = bpy.context.active_object; o.name = name
    o.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    o.location = (cx, (y0+y1)/2, cz)
    bpy.ops.object.transform_apply(location=True)
    if dome > 0.0:
        me = o.data; bm = bmesh.new(); bm.from_mesh(me)
        ymin = min(v.co.y for v in bm.verts)
        for v in bm.verts:
            if abs(v.co.y - ymin) < 1e-4:
                d = math.hypot(v.co.x-cx, v.co.z-cz)
                v.co.y -= dome*max(0.0, 1.0-(d/r)**2)
        bm.normal_update(); bm.to_mesh(me); bm.free()
    return o

def boolean(target, cutter, op='DIFFERENCE'):
    m = target.modifiers.new("b", 'BOOLEAN'); m.operation = op
    m.solver = 'EXACT'; m.object = cutter
    bpy.context.view_layer.objects.active = target
    try:
        bpy.ops.object.modifier_apply(modifier=m.name)
    except Exception:
        target.modifiers.remove(m)
    bpy.data.objects.remove(cutter, do_unlink=True)

def temizle(obj, da=math.radians(1.5)):
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=5e-4)
    bmesh.ops.dissolve_limit(bm, angle_limit=da, verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False

def genel_pah(obj, offset, segments=2):
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if e.is_manifold
            and e.calc_face_angle(0) > math.radians(25)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=0.7, affect='EDGES', clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False

def bevel_edges(obj, predicate, offset, segments=2):
    me = obj.data; bm = bmesh.new(); bm.from_mesh(me)
    geom = [e for e in bm.edges if predicate(e.verts[0].co, e.verts[1].co)]
    if geom:
        bmesh.ops.bevel(bm, geom=geom, offset=offset, segments=segments,
                        profile=0.5, affect='EDGES', clamp_overlap=True)
    bm.normal_update(); bm.to_mesh(me); bm.free()

def unwrap(o):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

def join(hedef, digerleri):
    digerleri = [d for d in digerleri if d is not None]
    if not digerleri: return
    bpy.ops.object.select_all(action='DESELECT')
    for o in [hedef]+digerleri: o.select_set(True)
    bpy.context.view_layer.objects.active = hedef
    bpy.ops.object.join()

# ----------------------------------------------- derinlik parametreleri (OLCULEN)
Y_FRAME = 0.0
FRAME_DEPTH = max(0.04*S, KALINLIK)         # gercek kalinlik = cerceve derinligi
LEAF_TH = FRAME_DEPTH*0.55                  # panel kalinligi (kalinligin parcasi)
Y_LEAF = FRAME_DEPTH*0.22                   # panel on yuzu (cerceveden geride)
CHAN_DIP = FRAME_DEPTH*0.42                 # cerceve oluk kanali derinligi
PLATE_UP = max(0.008*S, KALINLIK*0.22)      # kabarik plaka yuksekligi (yedek)
RECESS = max(0.010*S, KALINLIK*0.30)        # genel girinti derinligi (yedek)
print(">>> DERINLIK:", DERIN_KAYNAK, "kalinlik=%.3fm frame_depth=%.3f" %
      (KALINLIK, FRAME_DEPTH))

# ============================================================ CERCEVE (outline)
# outline yoksa basit oct dikdortgen kullan
if not OUTLINE:
    OUTLINE = cham_rect(0.0, 1.0, 0.0, 1.0, 0.08)
    OUTLINE = [[x, z] for x, z in
               [(0.0, 0.09), (0.13, 0.0), (0.87, 0.0), (1.0, 0.09),
                (1.0, 1.0), (0.0, 1.0)]]
# outline (nx,ny) -> model (x,z)
out_xz = [(X(nx), Z(ny)) for nx, ny in OUTLINE]
# centroid
cxg = sum(p[0] for p in out_xz)/len(out_xz)
czg = sum(p[1] for p in out_xz)/len(out_xz)
def inset_poly(poly, d):
    """Centroid'e dogru d kadar buzup ic poligon (aciklik) uret."""
    res = []
    for x, z in poly:
        vx, vz = x-cxg, z-czg
        L = math.hypot(vx, vz) or 1.0
        res.append((x - vx/L*d, z - vz/L*d))
    return res

FRAME_W = 0.075*EN          # cerceve genisligi (oran tabanli, genel)
opening = inset_poly(out_xz, FRAME_W)

obj_c = add_prism("Cerceve", out_xz, Y_FRAME, FRAME_DEPTH)
# aciklik (panel deligi) - inset poligon ile kes
cut_op = add_prism("cut_op", opening, -0.04, FRAME_DEPTH+0.04)
boolean(obj_c, cut_op)
# oluk kanali: aciklik agzi cevresinde girinti
kanal_dis = inset_poly(out_xz, FRAME_W*0.45)
kanal_ic  = inset_poly(out_xz, FRAME_W*1.10)
# kanal = dis halka prizmasi - ic halka prizmasi (on yuzde)
kn = add_prism("kn", kanal_dis, -0.01, CHAN_DIP)
kn_ic = add_prism("kn_ic", kanal_ic, -0.02, CHAN_DIP+0.02)
boolean(kn, kn_ic)
boolean(obj_c, kn)
temizle(obj_c); genel_pah(obj_c, 0.003*S, 2)
obj_c.data.materials.append(mat_cerceve)
try: unwrap(obj_c)
except Exception: pass

# ============================================================ PANEL (leaf)
leaf_poly = inset_poly(out_xz, FRAME_W+0.004*S)
obj_k = add_prism("Govde", leaf_poly, Y_LEAF, Y_LEAF+LEAF_TH)
obj_k.data.materials.append(mat_govde)
ekler = []

# ---------------------------------------------------------- oge yardimcilari
def oge_abs(o):
    return X(o["x"]), X(o["x1"]), Z(o["y1"]), Z(o["y"])   # x0,x1,z0,z1
def alan(o): return o["w"]*o["h"]
def icinde(a, b):     # a, b'yi icerir mi
    return (a["x"] <= b["x"]+1e-4 and a["y"] <= b["y"]+1e-4 and
            a["x1"] >= b["x1"]-1e-4 and a["y1"] >= b["y1"]-1e-4 and alan(a) > alan(b)*1.05)

def kabarik_cubuk(o):
    for al in o.get("alt_ogeler", []):
        if al["tur"] == "kabarik" and al["sekil"] in ("dikey_cubuk", "yatay_cubuk"):
            return al
    return None

def oge_turu(o):
    w, h = o["w"], o["h"]; ar = w/max(h, 1e-6)
    if o.get("izgara_sayisi", 0) >= 2 or o["etiket"] == "vent":
        return "vent"
    if o["etiket"] == "dikey_pencere" or (ar < 0.62 and h > 0.25):
        return "pencere"
    if kabarik_cubuk(o):
        return "kol"
    return "cep"

def civatalar_koy(liste, y_on, r_olcek=1.0):
    for b in liste or []:
        nx, ny = b[0], b[1]
        r = max(0.006*S, b[2]*EN*r_olcek) if len(b) > 2 else 0.008*S
        c = add_cyl("Civata", X(nx), Z(ny), r, y_on-0.006*S, y_on+0.003*S,
                    dome=0.004*S, verts=16)
        temizle(c); c.data.materials.append(mat_metal); ekler.append(c)

# ---------------------------------------------------------- tek bir ogeyi kur
def kur_oge(o, taban_y):
    """taban_y: ust yuzey (recess buradan icine girer)."""
    t = oge_turu(o)
    x0, x1, z0, z1 = oge_abs(o)
    ck = min(x1-x0, z1-z0)
    # OLCULEN derinlik (m); yoksa tip-bazli yedek
    dep = oge_derinlik(o, {"pencere": 0.022*S, "vent": 0.012*S,
                           "kol": 0.030*S}.get(t, RECESS))
    if t == "pencere":
        # cift oct cerceve + cam + cevre percin (ledge derinligin yarisinda)
        ledge = taban_y + dep*0.55
        boolean(obj_k, add_prism("cW1", cham_rect(x0, x1, z0, z1, ck*0.16),
                                 taban_y-0.001, ledge))
        ix0, ix1, iz0, iz1 = x0+ck*0.10, x1-ck*0.10, z0+ck*0.06, z1-ck*0.06
        boolean(obj_k, add_prism("cW2", cham_rect(ix0, ix1, iz0, iz1, ck*0.12),
                                 ledge-0.004*S, Y_LEAF+LEAF_TH+0.02))
        gv = add_prism("Cam", cham_rect(ix0+0.004*S, ix1-0.004*S,
                       iz0+0.004*S, iz1-0.004*S, ck*0.10),
                       taban_y+dep*0.9, taban_y+dep*0.9+0.010*S)
        temizle(gv); gv.data.materials.append(mat_cam); ekler.append(gv)
        # cevre percinleri varsa (oge civatalari) yoksa otomatik dizilim
        if o.get("civatalar"):
            civatalar_koy(o["civatalar"], taban_y, 0.8)
        else:
            ad = 0.06
            yy = z0+ck*0.12
            while yy < z1-ck*0.12:
                for xx in (x0-ck*0.02, x1+ck*0.02):
                    rc = add_cyl("Rivet", xx, yy, 0.006*S, taban_y-0.004*S,
                                 taban_y+0.0015*S, dome=0.003*S, verts=12)
                    temizle(rc); rc.data.materials.append(mat_govde); ekler.append(rc)
                yy += (z1-z0)*ad/0.2
    elif t == "vent":
        n = max(2, int(o.get("izgara_sayisi", 5)))
        dip = taban_y+dep
        boolean(obj_k, add_prism("cV", cham_rect(x0, x1, z0, z1, ck*0.16),
                                 taban_y-0.001, dip))
        ivx0, ivx1 = x0+(x1-x0)*0.12, x1-(x1-x0)*0.12
        ivz0, ivz1 = z0+(z1-z0)*0.10, z1-(z1-z0)*0.10
        step = (ivz1-ivz0)/n
        for i in range(n):
            zc = ivz0+step*(i+0.5)
            boolean(obj_k, add_box("ol%d" % i, ivx0, ivx1, zc-step*0.30, zc+step*0.30,
                                   dip-0.002*S, dip+0.010*S))
        if o.get("civatalar"): civatalar_koy(o["civatalar"], taban_y, 0.8)
    elif t == "kol":
        al = kabarik_cubuk(o)
        boolean(obj_k, add_prism("cS", rounded_rect(x0, x1, z0, z1, ck*0.16, 8),
                                 taban_y-0.001, taban_y+dep))
        bx0, bx1 = X(al["x"]), X(al["x1"]); bz0, bz1 = Z(al["y1"]), Z(al["y"])
        bw = bx1-bx0
        # kapsul yuksekligi: olculen alt-oge derinligi varsa onu kullan
        kol_on = taban_y - oge_derinlik(al, 0.004*S)
        kap = add_prism("Kol", rounded_rect(bx0, bx1, bz0, bz1, bw/2, 10),
                        kol_on, Y_LEAF+0.004*S)
        temizle(kap); genel_pah(kap, 0.0018*S, 2)
        kap.data.materials.append(mat_govde); ekler.append(kap)
        if o.get("civatalar"): civatalar_koy(o["civatalar"], taban_y, 0.8)
    else:   # cep / kabarik dugme
        if o.get("kabartma") == "kabarik":
            blok = add_prism("Kbrk", rounded_rect(x0, x1, z0, z1, ck*0.14, 6),
                             taban_y-dep, taban_y+0.003*S)
            temizle(blok); genel_pah(blok, 0.0018*S, 2)
            blok.data.materials.append(mat_govde); ekler.append(blok)
        else:
            boolean(obj_k, add_prism("cP", rounded_rect(x0, x1, z0, z1, ck*0.12, 6),
                                     taban_y-0.001, taban_y+dep))
        if o.get("civatalar"): civatalar_koy(o["civatalar"], taban_y, 0.8)

# ---------------------------------------------------------- hiyerarsi + insa
ogeler = H.get("ic_ogeler", [])
# her ogenin ebeveynini bul (en kucuk iceren)
ebeveyn = [None]*len(ogeler)
for i, a in enumerate(ogeler):
    best = None
    for j, b in enumerate(ogeler):
        if i != j and icinde(b, a):
            if best is None or alan(ogeler[best]) > alan(b):
                best = j
    ebeveyn[i] = best
cocuklar = {i: [j for j in range(len(ogeler)) if ebeveyn[j] == i] for i in range(len(ogeler))}
kokler = [i for i in range(len(ogeler)) if ebeveyn[i] is None]

for i in kokler:
    o = ogeler[i]
    if cocuklar[i]:
        # KABARIK plaka: yuksekligi OLCULEN (parent derinlik_m) ya da yedek
        x0, x1, z0, z1 = oge_abs(o)
        ck = min(x1-x0, z1-z0)
        up = oge_derinlik(o, PLATE_UP) if o.get("kabartma") != "girinti" else PLATE_UP
        Y_PL = Y_LEAF-up
        plaka = add_prism("Plaka", rounded_rect(x0, x1, z0, z1, ck*0.10, 6),
                          Y_PL, Y_LEAF+0.004*S)
        plaka.data.materials.append(mat_govde)
        ekler.append(plaka)
        # cocuk ogeleri plaka on yuzunden (Y_PL) icine kur
        for j in cocuklar[i]:
            try: kur_oge(ogeler[j], Y_PL)
            except Exception as e: print("oge atlandi:", ogeler[j]["etiket"], e)
        # plaka civatalari
        if o.get("civatalar"): civatalar_koy(o["civatalar"], Y_PL, 0.8)
    else:
        try: kur_oge(o, Y_LEAF)
        except Exception as e: print("oge atlandi:", o["etiket"], e)

# global civatalar (henuz konmadiysa, leaf yuzunde)
# (oge bazli konanlarla cakismamasi icin sadece hicbir ogenin yakininda olmayanlar)
def yakin_oge(b):
    for o in ogeler:
        if o["x"]-0.02 <= b[0] <= o["x1"]+0.02 and o["y"]-0.02 <= b[1] <= o["y1"]+0.02:
            return True
    return False
civatalar_koy([b for b in H.get("civatalar_global", []) if not yakin_oge(b)], Y_LEAF)

temizle(obj_k); genel_pah(obj_k, 0.0022*S, 2)
join(obj_k, ekler)
try: unwrap(obj_k)
except Exception: pass

# ============================================================ RENDER + EXPORT
def kamera_isik(hedef):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.collection.objects.link(cam)
    cam.location = Vector((-EN*1.2, -BOY*1.3, BOY*0.62)); cam.data.lens = 50
    cam.rotation_euler = (hedef-cam.location).to_track_quat('-Z', 'Y').to_euler()
    for e, sz, loc in [(400, 3.0, (EN*2, -BOY*1.2, BOY*1.5)),
                       (120, 4.0, (-EN*2, -BOY, BOY*0.7))]:
        L = bpy.data.objects.new("L", bpy.data.lights.new("L", 'AREA'))
        bpy.context.collection.objects.link(L); L.data.energy = e; L.data.size = sz
        L.location = Vector(loc)
        L.rotation_euler = (hedef-L.location).to_track_quat('-Z', 'Y').to_euler()
    return cam

hed = Vector((0.0, 0.0, BOY*0.5))
cam = kamera_isik(hed)
w = bpy.data.worlds.new("W"); bpy.context.scene.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[1].default_value = 0.4
sc = bpy.context.scene; sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'
sc.cycles.samples = 48; sc.cycles.use_denoising = False
sc.view_settings.view_transform = 'AgX'
sc.render.resolution_x = int(900*EN/BOY); sc.render.resolution_y = 900
sc.render.filepath = "/tmp/insa_preview.png"
bpy.ops.render.render(write_still=True)
print(">>> ONIZLEME: /tmp/insa_preview.png")

camo = bpy.data.objects.new("CamO", bpy.data.cameras.new("CamO"))
bpy.context.collection.objects.link(camo)
camo.data.type = 'ORTHO'; camo.data.ortho_scale = BOY
camo.location = Vector((0.0, -BOY*1.5, BOY/2)); camo.rotation_euler = (math.radians(90), 0, 0)
sc.camera = camo; sc.render.film_transparent = True
sc.render.resolution_x = int(1000*EN/BOY); sc.render.resolution_y = 1000
sc.render.filepath = "/tmp/insa_front.png"
bpy.ops.render.render(write_still=True)
sc.render.film_transparent = False
print(">>> ON ORTO: /tmp/insa_front.png")

os.makedirs(OUTDIR, exist_ok=True)
def export(obj, path):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True,
                              export_format='GLB', export_yup=True, export_apply=True)
    print(">>> export:", path)
export(obj_c, os.path.join(OUTDIR, "model_cerceve.glb"))
export(obj_k, os.path.join(OUTDIR, "model_govde.glb"))
print(">>> GENEL INSA BITTI  EN=%.3f BOY=%.3f oge=%d kok=%d"
      % (EN, BOY, len(ogeler), len(kokler)))
