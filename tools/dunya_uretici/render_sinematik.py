# -*- coding: utf-8 -*-
# Backrooms - SINEMATIK RENDER (dunya_plan.json -> Cycles render).
# Godot dunyasiyla AYNI yerlesimi (tek JSON) Blender'da gercek dokularla kurar ve
# birkac sinematik kare alir. Godot headless gercek kare uretemedigi icin render burada.
# Kullanim: blender -b -P tools/dunya_uretici/render_sinematik.py

import bpy, json, os, math
from mathutils import Vector, Matrix

PROJE="/home/user/Backrooms"
J=json.load(open(os.path.join(PROJE,"tools","dunya_uretici","dunya_plan.json")))
TEX=os.path.join(PROJE,"textures")
PM=J["parts_meta"]; WALL_H=J["wall_h"]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene

# ---------------- koordinat: Godot(x,y,z) -> Blender(x,-z,y) ; rotY -> rotZ
def g2b(p): return Vector((p[0], -p[2], p[1]))
def rotZ(deg): return Matrix.Rotation(math.radians(deg),4,'Z')

# ---------------- malzeme onbellegi (albedo+normal+rough)
_mat={}
def doku_mat(tex):
    if tex in _mat: return _mat[tex]
    m=bpy.data.materials.new(tex); m.use_nodes=True
    nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled"); bsdf.location=(-300,0)
    nt.links.new(bsdf.outputs[0],out.inputs[0])
    def img(suf,noncolor=False):
        for ext in ("_%s.png"%suf,):
            pass
        # dosya adlari: <tex>_albedo/_normal/_roughness|_rough
        cand=[]
        if suf=="albedo": cand=["%s_albedo.png"%tex]
        elif suf=="normal": cand=["%s_normal.png"%tex]
        elif suf=="rough": cand=["%s_roughness.png"%tex,"%s_rough.png"%tex]
        for c in cand:
            fp=os.path.join(TEX,c)
            if os.path.exists(fp):
                im=nt.nodes.new("ShaderNodeTexImage"); im.image=bpy.data.images.load(fp)
                if noncolor: im.image.colorspace_settings.name='Non-Color'
                return im
        return None
    a=img("albedo")
    if a: a.location=(-700,200); nt.links.new(a.outputs[0],bsdf.inputs["Base Color"])
    r=img("rough",True)
    if r: r.location=(-700,-100); nt.links.new(r.outputs[0],bsdf.inputs["Roughness"])
    n=img("normal",True)
    if n:
        n.location=(-900,-350); nm=nt.nodes.new("ShaderNodeNormalMap"); nm.location=(-500,-350)
        nt.links.new(n.outputs[0],nm.inputs["Color"]); nt.links.new(nm.outputs[0],bsdf.inputs["Normal"])
    _mat[tex]=m; return m

# ---------------- kutu (zemin/duvar/tavan)
def kutu(part,pos,rot,scale):
    meta=PM[part]; sx,sy,sz=meta["size"]
    sx*=scale[0]; sy*=scale[1]; sz*=scale[2]
    cy = pos[1] + (sy/2.0 if meta["kind"]=="wall" else 0.0)
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.active_object
    o.dimensions=(sx, sz, sy)     # Godot(x,y,z)->Blender(x,z,y)
    bpy.context.view_layer.update()
    o.rotation_euler=(0,0,math.radians(rot))
    o.location=g2b((pos[0],cy,pos[2]))
    o.data.materials.append(doku_mat(meta["tex"]))
    return o

# ---------------- GLB onbellegi (prop + kapi paneli) -> linked duplicate
_glb={}
def glb_yukle(path):
    if path in _glb: return _glb[path]
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(PROJE,path))
    objs=[o for o in bpy.data.objects if o not in before]
    meshes=[o for o in objs if o.type=='MESH']
    # tek parent altinda topla
    for o in objs: o.hide_render=True; o.hide_viewport=True
    _glb[path]=meshes
    return meshes

def glb_yerlestir(path,pos,rot,yoff,extra_scale=1.0):
    src=glb_yukle(path)
    M=Matrix.Translation(g2b((pos[0],pos[1]+yoff,pos[2]))) @ rotZ(rot)
    # Godot prop wrapper: model +yoff (taban y=0). Blender'da raw merkezli glb'yi yoff kaldir.
    # g2b zaten y->z; yoff godot-y oldugu icin pos[1]+yoff dogru.
    out=[]
    for s in src:
        d=s.copy(); d.data=s.data    # linked mesh (paylasimli)
        d.hide_render=False; d.hide_viewport=False
        # kaynak local transformu koru, sonra dunya matrisini uygula
        d.matrix_world = M @ s.matrix_basis if extra_scale==1.0 else M @ Matrix.Scale(extra_scale,4) @ s.matrix_basis
        bpy.context.collection.objects.link(d); out.append(d)
    return out

# ================================================================ DUNYAYI KUR
for it in J["instances"]:
    part=it["part"]; meta=PM[part]; k=meta["kind"]
    if k in ("floor","wall","ceil"):
        kutu(part,it["pos"],it["rot"],it["scale"])
    elif k=="glb":
        glb_yerlestir(meta["glb"],it["pos"],it["rot"],meta.get("yoff",0.0))
    elif k=="door":
        # kapi panelini opening'e kapali koy (cerceveyi yan dolgular saglar)
        glb_yerlestir("models/kapi_kanat_tripo.glb",[it["pos"][0],it["pos"][1]+1.0,it["pos"][2]],
                      it["rot"],0.0, extra_scale=1.0)

# leke (alpha plane) - hafif kir hissi
def leke_mat(tex):
    key="L_"+tex
    if key in _mat: return _mat[key]
    fp=os.path.join(PROJE,"textures",tex+".png")
    m=bpy.data.materials.new(key); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial"); bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value=(0.05,0.04,0.03,1); bsdf.inputs["Roughness"].default_value=0.95
    nt.links.new(bsdf.outputs[0],out.inputs[0])
    if os.path.exists(fp):
        im=nt.nodes.new("ShaderNodeTexImage"); im.image=bpy.data.images.load(fp)
        nt.links.new(im.outputs["Alpha"],bsdf.inputs["Alpha"])
    m.blend_method='BLEND'
    _mat[key]=m; return m
for st in J["stains"][:120]:
    bpy.ops.mesh.primitive_plane_add(size=st["size"])
    o=bpy.context.active_object
    o.location=g2b((st["pos"][0],st["pos"][1],st["pos"][2]))
    o.rotation_euler=(0,0,math.radians(st.get("rot",0)))
    o.data.materials.append(leke_mat(st["tex"]))

# ---------------- isiklar (Godot omni -> Blender point)
for lt in J["lights"]:
    L=bpy.data.lights.new("om",'POINT'); L.energy=lt["energy"]*60.0
    L.color=tuple(lt["color"]); L.shadow_soft_size=0.5
    ob=bpy.data.objects.new("om",L); ob.location=g2b(lt["pos"])
    bpy.context.collection.objects.link(ob)

# ---------------- dunya/ortam (loş, atmosfer)
w=bpy.data.worlds.new("W"); sc.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[0].default_value=(0.02,0.02,0.025,1)
w.node_tree.nodes["Background"].inputs[1].default_value=0.25

sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=80; sc.cycles.use_denoising=False
sc.render.resolution_x=1280; sc.render.resolution_y=720
sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Medium High Contrast'

def kamera(loc,hedef,lens=35):
    for o in list(bpy.data.objects):
        if o.type=='CAMERA': bpy.data.objects.remove(o,do_unlink=True)
    cam=bpy.data.objects.new("Cam",bpy.data.cameras.new("Cam")); cam.data.lens=lens
    bpy.context.collection.objects.link(cam); cam.location=Vector(loc)
    d=(Vector(hedef)-Vector(loc)); cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
    sc.camera=cam

def render(tag): sc.render.filepath=tag; bpy.ops.render.render(write_still=True); print(">>>",tag)

# kat merkezi (godot): x ~ 14, z ~ 10 -> blender (14,-10, y)
# 1) Lobiden koridora bakis (goz hizasi)
kamera(g2b((14,1.6,-2)), g2b((14,1.4,12)), 30); render("/tmp/dunya_lobi.png")
# 2) Ana koridor boyunca (uzun bakis)
kamera(g2b((1,1.6,8)), g2b((28,1.5,8)), 24); render("/tmp/dunya_koridor.png")
# 3) Salon detay (objeler)
kamera(g2b((9,1.6,11)), g2b((16,1.2,15)), 35); render("/tmp/dunya_salon.png")
# 4) Izometrik kus bakisi (tum kat)
kamera(g2b((30,26,-8)), g2b((13,0,11)), 30); render("/tmp/dunya_izometrik.png")
print(">>> BITTI")
