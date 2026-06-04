# -*- coding: utf-8 -*-
# Backrooms - SINEMATIK RENDER (dunya_plan.json -> Cycles render).
# Godot dunyasiyla AYNI yerlesimi (tek JSON) Blender'da gercek dokularla kurar ve
# birkac sinematik kare alir. Godot headless gercek kare uretemedigi icin render burada.
# HIZ: bpy.ops yok; tek UV'li temel kup/duzlem paylasilir, nesne-bazli materyal+olcek.
# Kullanim: blender -b -P tools/dunya_uretici/render_sinematik.py

import bpy, json, os, math
from mathutils import Vector, Matrix

PROJE="/home/user/Backrooms"
J=json.load(open(os.path.join(PROJE,"tools","dunya_uretici","dunya_plan.json")))
TEX=os.path.join(PROJE,"textures")
PM=J["parts_meta"]; WALL_H=J["wall_h"]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
coll=bpy.context.collection

# ---------------- koordinat: Godot(x,y,z) -> Blender(x,-z,y) ; rotY -> rotZ
def g2b(p): return Vector((p[0], -p[2], p[1]))
def rotZ(d): return Matrix.Rotation(math.radians(d),4,'Z')

# ---------------- temel UV'li mesh'ler (bir kez bpy.ops, sonra paylasim)
bpy.ops.mesh.primitive_cube_add(size=1.0)
_co=bpy.context.active_object; CUBE=_co.data; CUBE.materials.append(bpy.data.materials.new("ph"))
bpy.data.objects.remove(_co,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=1.0)
_po=bpy.context.active_object; PLANE=_po.data; PLANE.materials.append(bpy.data.materials.new("ph2"))
bpy.data.objects.remove(_po,do_unlink=True)

# ---------------- malzeme onbellegi (albedo+normal+rough)
_mat={}
def doku_mat(tex):
    if tex in _mat: return _mat[tex]
    m=bpy.data.materials.new(tex); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled"); bsdf.location=(-300,0)
    nt.links.new(bsdf.outputs[0],out.inputs[0])
    def img(cands,noncolor=False):
        for c in cands:
            fp=os.path.join(TEX,c)
            if os.path.exists(fp):
                im=nt.nodes.new("ShaderNodeTexImage"); im.image=bpy.data.images.load(fp)
                if noncolor: im.image.colorspace_settings.name='Non-Color'
                return im
        return None
    a=img(["%s_albedo.png"%tex])
    if a: a.location=(-700,200); nt.links.new(a.outputs[0],bsdf.inputs["Base Color"])
    r=img(["%s_roughness.png"%tex,"%s_rough.png"%tex],True)
    if r: r.location=(-700,-100); nt.links.new(r.outputs[0],bsdf.inputs["Roughness"])
    n=img(["%s_normal.png"%tex],True)
    if n:
        n.location=(-900,-350); nm=nt.nodes.new("ShaderNodeNormalMap"); nm.location=(-500,-350)
        nt.links.new(n.outputs[0],nm.inputs["Color"]); nt.links.new(nm.outputs[0],bsdf.inputs["Normal"])
    _mat[tex]=m; return m

def leke_mat(tex):
    key="L_"+tex
    if key in _mat: return _mat[key]
    fp=os.path.join(TEX,tex+".png")
    m=bpy.data.materials.new(key); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial"); bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value=(0.05,0.04,0.03,1); bsdf.inputs["Roughness"].default_value=0.95
    nt.links.new(bsdf.outputs[0],out.inputs[0])
    if os.path.exists(fp):
        im=nt.nodes.new("ShaderNodeTexImage"); im.image=bpy.data.images.load(fp)
        nt.links.new(im.outputs["Alpha"],bsdf.inputs["Alpha"])
    m.blend_method='BLEND'; _mat[key]=m; return m

def nesne(mesh,mat,loc,rot,scale):
    o=bpy.data.objects.new("n",mesh)
    o.material_slots[0].link='OBJECT'; o.material_slots[0].material=mat
    o.scale=scale; o.rotation_euler=(0,0,math.radians(rot)); o.location=loc
    coll.objects.link(o); return o

# ---------------- kutu (zemin/duvar/tavan)
def kutu(part,pos,rot,scale):
    meta=PM[part]; sx,sy,sz=meta["size"]
    sx*=scale[0]; sy*=scale[1]; sz*=scale[2]
    cy=pos[1]+(sy/2.0 if meta["kind"]=="wall" else 0.0)
    nesne(CUBE,doku_mat(meta["tex"]),g2b((pos[0],cy,pos[2])),rot,(sx,sz,sy))

# ---------------- GLB onbellegi -> linked duplicate (matrix_world korunur)
_glb={}
def glb_yukle(path):
    if path in _glb: return _glb[path]
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(PROJE,path))
    objs=[o for o in bpy.data.objects if o not in before]
    rec=[(o, o.matrix_world.copy()) for o in objs if o.type=='MESH']
    for o in objs: o.hide_render=True; o.hide_viewport=True
    _glb[path]=rec; return rec

def glb_yerlestir(path,pos,rot,yoff,extra=1.0):
    rec=glb_yukle(path)
    M=Matrix.Translation(g2b((pos[0],pos[1]+yoff,pos[2]))) @ rotZ(rot)
    if extra!=1.0: M=M @ Matrix.Scale(extra,4)
    for s,mw in rec:
        d=s.copy(); d.data=s.data; d.hide_render=False; d.hide_viewport=False
        d.matrix_world = M @ mw
        coll.objects.link(d)

# ================================================================ DUNYAYI KUR
for it in J["instances"]:
    part=it["part"]; meta=PM[part]; k=meta["kind"]
    if k in ("floor","wall","ceil"): kutu(part,it["pos"],it["rot"],it["scale"])
    elif k=="glb": glb_yerlestir(meta["glb"],it["pos"],it["rot"],meta.get("yoff",0.0))
    elif k=="door":
        glb_yerlestir("models/kapi_kanat_tripo.glb",
                      [it["pos"][0],it["pos"][1]+0.9,it["pos"][2]],it["rot"],0.0)

for st in J["stains"][:130]:
    nesne(PLANE,leke_mat(st["tex"]),g2b((st["pos"][0],st["pos"][1],st["pos"][2])),
          st.get("rot",0),(st["size"],st["size"],1))

# ---------------- isiklar (Godot omni -> Blender point)
for lt in J["lights"]:
    L=bpy.data.lights.new("om",'POINT'); L.energy=lt["energy"]*55.0
    L.color=tuple(lt["color"]); L.shadow_soft_size=0.4
    ob=bpy.data.objects.new("om",L); ob.location=g2b(lt["pos"]); coll.objects.link(ob)

# ---------------- dunya/ortam (los atmosfer)
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.02,0.02,0.025,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.22

sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=64; sc.cycles.use_denoising=False
sc.render.resolution_x=1280; sc.render.resolution_y=720
sc.view_settings.view_transform='AgX'

def kamera(loc,hedef,lens=35):
    for o in list(bpy.data.objects):
        if o.type=='CAMERA': bpy.data.objects.remove(o,do_unlink=True)
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=lens
    coll.objects.link(cam); cam.location=Vector(loc)
    cam.rotation_euler=(Vector(hedef)-Vector(loc)).to_track_quat('-Z','Y').to_euler()
    sc.camera=cam

def render(tag): sc.render.filepath=tag; bpy.ops.render.render(write_still=True); print(">>>",tag)

import sys
secim = sys.argv[-1] if "--" in sys.argv else "hepsi"
def istendi(ad): return secim=="hepsi" or ad in secim

if istendi("lobi"):
    kamera(g2b((2.5,1.7,0)), g2b((26,1.45,0)), 26); render("/tmp/dunya_lobi.png")
if istendi("koridor"):
    kamera(g2b((1,1.6,8)),   g2b((28,1.5,8)), 24); render("/tmp/dunya_koridor.png")
if istendi("salon"):
    kamera(g2b((8.6,1.7,10.6)), g2b((14.5,1.3,15)), 30); render("/tmp/dunya_salon.png")
if istendi("izometrik"):
    kamera(g2b((32,24,-10)), g2b((13,0,10)), 34); render("/tmp/dunya_izometrik.png")
print(">>> BITTI")
