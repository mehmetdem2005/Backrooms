import bpy, math, os
T="/home/user/Backrooms/game_src/textures/"
KIT="/home/user/Backrooms/kit/"
os.makedirs(KIT, exist_ok=True)
def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)
def img(p): return bpy.data.images.load(p)
def pbr(name, alb, nrm, rgh, uv=(1,1), rough_val=None, normstr=0.4):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial"); b=nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(b.outputs[0],out.inputs[0])
    tc=nt.nodes.new("ShaderNodeTexCoord"); mp=nt.nodes.new("ShaderNodeMapping"); mp.inputs[3].default_value=(uv[0],uv[1],1)
    nt.links.new(tc.outputs["UV"],mp.inputs[0])
    ta=nt.nodes.new("ShaderNodeTexImage"); ta.image=img(alb); nt.links.new(mp.outputs[0],ta.inputs[0]); nt.links.new(ta.outputs[0],b.inputs["Base Color"])
    if rough_val is not None: b.inputs["Roughness"].default_value=rough_val
    elif rgh:
        tr=nt.nodes.new("ShaderNodeTexImage"); tr.image=img(rgh); tr.image.colorspace_settings.name="Non-Color"
        nt.links.new(mp.outputs[0],tr.inputs[0]); nt.links.new(tr.outputs[0],b.inputs["Roughness"])
    if nrm:
        tn=nt.nodes.new("ShaderNodeTexImage"); tn.image=img(nrm); tn.image.colorspace_settings.name="Non-Color"
        nb=nt.nodes.new("ShaderNodeNormalMap"); nb.inputs[0].default_value=normstr
        nt.links.new(mp.outputs[0],tn.inputs[0]); nt.links.new(tn.outputs[0],nb.inputs[1]); nt.links.new(nb.outputs[0],b.inputs["Normal"])
    return m
def emit(name,s=10,c=(1,0.99,0.96)):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); e=nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value=(*c,1); e.inputs[1].default_value=s; nt.links.new(e.outputs[0],o.inputs[0]); return m
def water_mat():
    m=bpy.data.materials.new("Water"); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(0.3,0.62,0.7,1); b.inputs["Roughness"].default_value=0.04
    b.inputs["Transmission Weight"].default_value=0.85; b.inputs["Alpha"].default_value=0.6; return m
def solid(name,col,rough=0.55):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1); b.inputs["Roughness"].default_value=rough; return m
def box(loc,sc,mat):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.scale=sc
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o
def combine(parts,name):
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]
    bpy.ops.object.join(); o=bpy.context.object; o.name=name; return o
def export_glb(obj,name):
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.gltf(filepath=KIT+name+".glb", use_selection=True, export_format='GLB')

reset()
tile   = pbr("Tile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,2), rough_val=0.08)
wains  = pbr("Wain", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,1.2), rough_val=0.1)
plaster= pbr("Wall", T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(2,1.5))
col_m  = pbr("Col", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1,2), rough_val=0.1)
trim_m = solid("Trim",(0.18,0.19,0.2),0.4)
base_m = solid("Base",(0.62,0.63,0.62),0.4)
ceil_m = solid("Ceil",(0.93,0.92,0.9),0.6)
frame_m= solid("Frame",(0.8,0.8,0.78),0.35)
emit_m = emit("Light",12)
water  = water_mat()
C=4.0; HT=3.0; WAIN=1.15  # hücre 4x4, yükseklik 3
mods={}

# 1) FLOOR 4x4
mods["floor"]=combine([box((0,-0.05,0),(C/2,0.05,C/2), tile)],"floor")
# 2) CEILING + ışık (gömme emissive)
c1=box((0,HT+0.05,0),(C/2,0.05,C/2), ceil_m)
c2=box((0,HT-0.02,0),(1.3,0.04,1.0), frame_m)
c3=box((0,HT-0.10,0),(1.1,0.03,0.8), emit_m)
mods["ceiling_light"]=combine([c1,c2,c3],"ceiling_light")
# 3) WALL (-Z kenarda; lambri+sıva+süpürgelik+profil)
w1=box((0,WAIN/2,-C/2),(C/2,WAIN/2,0.1), wains)
w2=box((0,WAIN+(HT-WAIN)/2,-C/2),(C/2,(HT-WAIN)/2,0.1), plaster)
w3=box((0,WAIN,-C/2+0.02),(C/2,0.03,0.02), trim_m)
w4=box((0,0.07,-C/2+0.04),(C/2,0.07,0.04), base_m)
mods["wall"]=combine([w1,w2,w3,w4],"wall")
# 4) WALL_DOOR (geçiş boşluğu)
d_top=box((0,HT-0.35,-C/2),(C/2,0.35,0.1), plaster)
d_l1=box((-1.4,WAIN/2,-C/2),(0.6,WAIN/2,0.1), wains)
d_l2=box((-1.4,WAIN+(HT-0.7-WAIN)/2,-C/2),(0.6,(HT-0.7-WAIN)/2,0.1), plaster)
d_r1=box((1.4,WAIN/2,-C/2),(0.6,WAIN/2,0.1), wains)
d_r2=box((1.4,WAIN+(HT-0.7-WAIN)/2,-C/2),(0.6,(HT-0.7-WAIN)/2,0.1), plaster)
mods["wall_door"]=combine([d_top,d_l1,d_l2,d_r1,d_r2],"wall_door")
# 5) COLUMN (köşe pilastr)
mods["column"]=combine([box((0,HT/2,0),(0.25,HT/2,0.25), col_m)],"column")
# 6) STAIRS (4m'de 3m iner, basamaklı) -Z(y=0) -> +Z(y=-3)
steps=[]
N=8
for k in range(N):
    zc=-C/2+ (C/N)*(k+0.5)
    top=-(HT/N)*k
    steps.append(box((0,top-0.22,zc),(C/2,0.22,(C/N)/2+0.02), tile))
mods["stairs"]=combine(steps,"stairs")
# 7) POOL_WATER (çukur hücre: taban -2, su -0.2)
PD=2.0
p1=box((0,-PD,0),(C/2,0.05,C/2), tile)                 # taban
p2=box((-C/2,-PD/2,0),(0.06,PD/2,C/2), tile)            # iç duvarlar
p3=box(( C/2,-PD/2,0),(0.06,PD/2,C/2), tile)
p4=box((0,-PD/2,-C/2),(C/2,PD/2,0.06), tile)
p5=box((0,-PD/2, C/2),(C/2,PD/2,0.06), tile)
p6=box((0,-0.2,0),(C/2-0.07,0.01,C/2-0.07), water)     # su yüzeyi
mods["pool_water"]=combine([p1,p2,p3,p4,p5,p6],"pool_water")
# 8) POOL_EDGE (güverte + kenar profili + bir tarafta iç duvar inişi + su)
e1=box((0,-0.05,C/4),(C/2,0.05,C/4), tile)             # güverte yarısı (+Z)
e2=box((0,0.02,0),(C/2,0.03,0.12), trim_m)             # kenar profili
e3=box((0,-PD/2,-C/4),(C/2,PD/2,C/4-0.06), tile)       # havuz tarafı iç duvar+taban basit
e4=box((0,-0.2,-C/4),(C/2-0.07,0.01,C/4-0.07), water)
mods["pool_edge"]=combine([e1,e2,e3,e4],"pool_edge")

# --- glb dışa aktar (her modül origin'de) ---
for nm,ob in mods.items():
    export_glb(ob,nm)

# --- ÖNİZLEME: modülleri ızgaraya yay, üstten açılı render ---
import mathutils
layout=list(mods.values())
gx=[-7,-2.5,2,6.5]; positions=[]
order=["floor","wall","wall_door","ceiling_light","column","stairs","pool_water","pool_edge"]
labels={}
for i,nm in enumerate(order):
    ob=mods[nm]; col=i%4; row=i//4
    ob.location=(gx[col], 0, -row*6.0)
# zemin düzlemi (sahne için)
ground=box((0,-2.6,-3),(16,0.05,10), solid("G",(0.5,0.52,0.55),0.6))
# ışık (sadece önizleme render'ı için)
bpy.ops.object.light_add(type='AREA',location=(0,12,-1)); ar=bpy.context.object; ar.data.energy=4000; ar.data.size=22
w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[1].default_value=0.5
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.use_adaptive_sampling=True; sc.cycles.adaptive_threshold=0.03; sc.cycles.samples=80
sc.cycles.use_denoising=True; sc.cycles.denoiser='OPENIMAGEDENOISE'; sc.cycles.max_bounces=4
sc.render.resolution_x=1366; sc.render.resolution_y=768
sc.view_settings.view_transform='AgX'
cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cd); bpy.context.collection.objects.link(cam)
cam.location=(0,11,12); cd.lens=26
d=mathutils.Vector((0,0.5,-3))-cam.location
cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
sc.camera=cam
sc.render.filepath="/home/user/Backrooms/white_kit_preview.png"
bpy.ops.render.render(write_still=True)
print("KIT_DONE files=%d"%len(mods))
