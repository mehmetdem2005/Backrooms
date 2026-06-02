import bpy, math, mathutils
T="/home/user/Backrooms/game_src/textures/"
def reset(): bpy.ops.wm.read_factory_settings(use_empty=True)
def img(p): return bpy.data.images.load(p)
def pbr(name, alb, nrm, rgh, uv=(2,2), rough_val=None, normstr=0.4):
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
def emit(name,s=12,c=(1,0.99,0.96)):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); e=nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value=(*c,1); e.inputs[1].default_value=s; nt.links.new(e.outputs[0],o.inputs[0]); return m
def water_mat():
    m=bpy.data.materials.new("Water"); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); b=nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value=(0.42,0.72,0.78,1); b.inputs["Roughness"].default_value=0.02
    b.inputs["Transmission Weight"].default_value=1.0; b.inputs["IOR"].default_value=1.33
    nt.links.new(b.outputs[0],o.inputs[0])
    tc=nt.nodes.new("ShaderNodeTexCoord"); nz=nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value=30
    bp=nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value=0.03
    nt.links.new(tc.outputs["Object"],nz.inputs["Vector"]); nt.links.new(nz.outputs["Fac"],bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"],b.inputs["Normal"])
    return m
def solid(name,col,rough=0.6):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1); b.inputs["Roughness"].default_value=rough; return m
def box(name,loc,sc,mat,uvcube=True):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=sc
    bpy.ops.object.transform_apply(scale=True)
    if uvcube:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o
reset()
tile   = pbr("Tile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,2), rough_val=0.07)
pooltl = pbr("PoolTile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2.5,2.5), rough_val=0.12)
plaster= pbr("Wall", T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(2.5,2.5))
wains  = pbr("Wain", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1.6,1.6), rough_val=0.1)
col_m  = pbr("Col", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1,2.2), rough_val=0.1)
trim_m = solid("Trim",(0.62,0.63,0.62),0.4)
ceil_m = solid("Ceil",(0.93,0.92,0.9),0.6)
emit_m = emit("Light",13); sky_m=emit("Sky",6,(0.95,0.97,1.0))
water  = water_mat()
RX,RY,H=8.0,6.0,3.6
PX,PY,PD=5.0,3.5,1.35   # havuz açıklığı yarı-boyut + derinlik
# Çevre güverte (havuz deliği etrafında 4 şerit)
box("DeckS",(0,-(PY+ (RY-PY)/2),-0.05),(RX,(RY-PY)/2,0.05), tile)
box("DeckN",(0, (PY+ (RY-PY)/2),-0.05),(RX,(RY-PY)/2,0.05), tile)
box("DeckW",(-(PX+(RX-PX)/2),0,-0.05),((RX-PX)/2,PY,0.05), tile)
box("DeckE",( (PX+(RX-PX)/2),0,-0.05),((RX-PX)/2,PY,0.05), tile)
# Havuz iç duvarları + taban + su
box("PwW",(-PX,0,-PD/2),(0.05,PY,PD/2), pooltl)
box("PwE",( PX,0,-PD/2),(0.05,PY,PD/2), pooltl)
box("PwS",(0,-PY,-PD/2),(PX,0.05,PD/2), pooltl)
box("PwN",(0, PY,-PD/2),(PX,0.05,PD/2), pooltl)
box("PFloor",(0,0,-PD),(PX,PY,0.05), pooltl)
box("Water",(0,0,-0.22),(PX-0.06,PY-0.06,0.005), water, uvcube=False)
# Havuz kenar profili (göz alıcı koyu şerit)
for (lx,ly,sx,sy) in [(0,-PY,PX,0.07),(0,PY,PX,0.07),(-PX,0,0.07,PY),(PX,0,0.07,PY)]:
    box("Lip%0.0f%0.0f"%(lx,ly),(lx,ly,0.02),(sx,sy,0.03), trim_m)
# Basamaklar (doğu uçtan suya iniş)
for k in range(3):
    box("Step%d"%k,(PX-0.35-0.5*k,0,-0.35-0.4*k),(0.24,1.6,0.04), pooltl)
# Oda duvarları (lambri + üst sıva)
WAIN=1.2
for (cx,cy,sx,sy) in [(0,-RY,RX,0.08),(0,RY,RX,0.08),(-RX,0,0.08,RY),(RX,0,0.08,RY)]:
    box("WnLow",(cx,cy,WAIN/2),(sx,sy,WAIN/2), wains)
    box("WnUp",(cx,cy,WAIN+(H-WAIN)/2),(sx,sy,(H-WAIN)/2), plaster)
# Sütunlar (güverte köşeleri)
for sx in (-1,1):
    for sy in (-1,1):
        box("Col%d%d"%(sx,sy),(sx*(PX+ (RX-PX)/2),sy*(PY+0.2),H/2),(0.26,0.26,H/2), col_m)
# Tavan + ışık ızgarası + büyük skylight
box("Ceil",(0,0,H),(RX,RY,0.05), ceil_m)
for ix in (-1,0,1):
    for iy in (-1,1):
        box("L%d%d"%(ix,iy),(ix*4.2,iy*4.0,H-0.06),(1.2,0.9,0.04), emit_m)
box("Skylight",(0,0,H-0.04),(3.2,2.2,0.03), sky_m)
# Dünya ortam
w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[1].default_value=0.06
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.use_adaptive_sampling=True; sc.cycles.adaptive_threshold=0.02; sc.cycles.samples=160
sc.cycles.use_denoising=True; sc.cycles.denoiser='OPENIMAGEDENOISE'
sc.cycles.max_bounces=6; sc.cycles.transmission_bounces=8
sc.render.resolution_x=1280; sc.render.resolution_y=720
sc.view_settings.view_transform='AgX'
try: sc.view_settings.look='AgX - Medium High Contrast'
except: pass
sc.use_nodes=True; c=sc.node_tree
rl=c.nodes["Render Layers"]; comp=c.nodes["Composite"]
gl=c.nodes.new("CompositorNodeGlare"); gl.glare_type='FOG_GLOW'; gl.quality='MEDIUM'; gl.threshold=0.85; gl.mix=-0.3
c.links.new(rl.outputs[0],gl.inputs[0]); c.links.new(gl.outputs[0],comp.inputs[0])
cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cd); bpy.context.collection.objects.link(cam)
cam.location=(6.6,-5.4,1.65); cd.lens=20
d=mathutils.Vector((-2.0,2.0,-0.3))-cam.location
cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
cd.dof.use_dof=True; cd.dof.focus_distance=8.0; cd.dof.aperture_fstop=5.0
sc.camera=cam
sc.render.filepath="/home/user/Backrooms/white_poolroom.png"
bpy.ops.render.render(write_still=True)
print("POOLROOM_DONE")
