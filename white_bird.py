import bpy, math, mathutils
T="/home/user/Backrooms/game_src/textures/"
def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)
def img(p): return bpy.data.images.load(p)
def pbr(name, alb, nrm, rgh, uv=(2,2), rough_val=None, normstr=0.5):
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
def water_mat():
    m=bpy.data.materials.new("Water"); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); b=nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value=(0.45,0.74,0.8,1); b.inputs["Roughness"].default_value=0.04
    b.inputs["Transmission Weight"].default_value=1.0; b.inputs["IOR"].default_value=1.33
    nt.links.new(b.outputs[0],o.inputs[0]); return m
def solid(name,col,rough=0.6,metal=0.0):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1); b.inputs["Roughness"].default_value=rough; b.inputs["Metallic"].default_value=metal; return m
def box(name,loc,scale,mat,uvcube=True):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(scale=True)
    if uvcube:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o
reset()
floor_m  = pbr("Floor", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,2), rough_val=0.08)
plaster  = pbr("Wall",  T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(2.2,2.2))
wains    = pbr("Wainscot", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1.5,1.5), rough_val=0.12)
trim_m   = solid("Trim",(0.65,0.65,0.63),0.4)
col_m    = pbr("Column", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1,2), rough_val=0.12)
water    = water_mat()
L=28; Wd=4.2; Ht=3.0; WAIN=1.15
box("Floor",(0,-3,0),(Wd/2,(L/2-3),0.05), floor_m)
box("PoolFloor",(0,L/2-4,-0.4),(Wd/2,4,0.05), wains)
box("PoolLipL",(-Wd/2+0.15,L/2-4,-0.18),(0.12,4,0.22), trim_m)
box("PoolLipR",( Wd/2-0.15,L/2-4,-0.18),(0.12,4,0.22), trim_m)
box("WaterSurf",(0,L/2-4,-0.10),(Wd/2-0.16,4,0.004), water, uvcube=False)
for sx,nm in [(-1,"L"),(1,"R")]:
    box("WainLow"+nm,(sx*Wd/2,0,WAIN/2),(0.05,L/2,WAIN/2), wains)
    box("WallUp"+nm,(sx*Wd/2,0,WAIN+(Ht-WAIN)/2),(0.05,L/2,(Ht-WAIN)/2), plaster)
    box("Trim"+nm,(sx*(Wd/2-0.02),0,WAIN),(0.03,L/2,0.04), trim_m)
for i in range(5):
    yy=-L/2+5+i*4.6
    for sx in (-1,1):
        box("Col%d%d"%(i,sx),(sx*(Wd/2-0.22),yy,Ht/2),(0.22,0.22,Ht/2), col_m)
box("EndWall",(0,L/2,Ht/2),(Wd/2,0.05,Ht/2), plaster)
# Aydınlatma: üstten geniş alan ışığı (bake benzeri yumuşak) — render için, oyunda değil
bpy.ops.object.light_add(type='AREA', location=(0,-2,9)); ar=bpy.context.object; ar.data.energy=2600; ar.data.size=8; ar.data.size_y=26
# Dünya gök ortamı
w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[1].default_value=0.6
w.node_tree.nodes["Background"].inputs[0].default_value=(0.7,0.78,0.85,1)
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.use_adaptive_sampling=True; sc.cycles.adaptive_threshold=0.02; sc.cycles.samples=120
sc.cycles.use_denoising=True; sc.cycles.denoiser='OPENIMAGEDENOISE'; sc.cycles.max_bounces=4
sc.render.resolution_x=1280; sc.render.resolution_y=900
sc.view_settings.view_transform='AgX'
sc.render.filepath="/home/user/Backrooms/white_bird.png"
# Açılı kuşbakışı kamera
cd=bpy.data.cameras.new("Bird"); cam=bpy.data.objects.new("Bird",cd); bpy.context.collection.objects.link(cam)
cam.location=(9,-13,12); cd.lens=30
d=mathutils.Vector((0,1.0,0.5))-cam.location
cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
sc.camera=cam
bpy.ops.render.render(write_still=True)
print("BIRD2_DONE")
