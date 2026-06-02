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
    b.inputs["Base Color"].default_value=(0.16,0.55,0.62,1); b.inputs["Roughness"].default_value=0.015
    b.inputs["Transmission Weight"].default_value=1.0; b.inputs["IOR"].default_value=1.333
    nt.links.new(b.outputs[0],o.inputs[0])
    tc=nt.nodes.new("ShaderNodeTexCoord"); nz=nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value=8; nz.inputs["Detail"].default_value=4
    bp=nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value=0.06
    nt.links.new(tc.outputs["Generated"],nz.inputs["Vector"]); nt.links.new(nz.outputs["Fac"],bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"],b.inputs["Normal"])
    return m
def solid(name,col,rough=0.6):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1); b.inputs["Roughness"].default_value=rough; return m
def box(name,loc,sc,mat,uvcube=True):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=sc
    bpy.ops.object.transform_apply(scale=True)
    if uvcube:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=2.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o
reset()
tile   = pbr("Tile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(3,3), rough_val=0.07)
pooltl = pbr("PoolTile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(4,4), rough_val=0.1, normstr=0.2)
plaster= pbr("Wall", T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(4,4))
wains  = pbr("Wain", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2.5,2.5), rough_val=0.1)
col_m  = pbr("Col", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1.5,4), rough_val=0.1)
trim_m = solid("Trim",(0.55,0.57,0.58),0.4)
lane_m = solid("Lane",(0.06,0.12,0.3),0.3)
ceil_m = solid("Ceil",(0.93,0.92,0.9),0.6)
emit_m = emit("Light",10); sky_m=emit("Sky",7,(0.9,0.95,1.0))
water  = water_mat()
# OLİMPİK havuz: 50 x 25 m, derinlik 2 m
PX,PY,PD=25.0,12.5,2.0
RX,RY,H=32.0,18.0,9.0   # hol
# Güverte (havuz etrafı)
box("DeckS",(0,-(PY+(RY-PY)/2),-0.05),(RX,(RY-PY)/2,0.05), tile)
box("DeckN",(0, (PY+(RY-PY)/2),-0.05),(RX,(RY-PY)/2,0.05), tile)
box("DeckW",(-(PX+(RX-PX)/2),0,-0.05),((RX-PX)/2,PY,0.05), tile)
box("DeckE",( (PX+(RX-PX)/2),0,-0.05),((RX-PX)/2,PY,0.05), tile)
# Havuz iç duvar + taban
box("PwW",(-PX,0,-PD/2),(0.1,PY,PD/2), pooltl)
box("PwE",( PX,0,-PD/2),(0.1,PY,PD/2), pooltl)
box("PwS",(0,-PY,-PD/2),(PX,0.1,PD/2), pooltl)
box("PwN",(0, PY,-PD/2),(PX,0.1,PD/2), pooltl)
box("PFloor",(0,0,-PD),(PX,PY,0.05), pooltl)
# Kulvar çizgileri (taban boyunca, uzunlamasına) — 8 kulvar
for i in range(9):
    yy=-10.0+i*2.5
    box("Lane%d"%i,(0,yy,-PD+0.06),(PX-0.5,0.06,0.02), lane_m)
# Su yüzeyi (devasa tek düzlem)
box("Water",(0,0,-0.12),(PX-0.05,PY-0.05,0.004), water, uvcube=False)
# Kenar profili (taşma oluğu)
for (lx,ly,sx,sy) in [(0,-PY,PX,0.12),(0,PY,PX,0.12),(-PX,0,0.12,PY),(PX,0,0.12,PY)]:
    box("Lip",(lx,ly,0.02),(sx,sy,0.04), trim_m)
# Hol duvarları: lambri + üst sıva + üstte clerestory pencere şeridi (parlak)
WAIN=2.0
for (cx,cy,sx,sy) in [(0,-RY,RX,0.12),(0,RY,RX,0.12),(-RX,0,0.12,RY),(RX,0,0.12,RY)]:
    box("WnLow",(cx,cy,WAIN/2),(sx,sy,WAIN/2), wains)
    box("WnUp",(cx,cy,WAIN+(H-WAIN-1.2)/2),(sx,sy,(H-WAIN-1.2)/2), plaster)
    box("Cler",(cx,cy,H-0.6),(sx if sx>1 else 0.10, sy if sy>1 else 0.10, 0.55), sky_m)  # clerestory
# Sütunlar (hol boyunca)
for gx in (-1,1):
    for j in range(5):
        yy=-13+j*6.5
        box("Col%d%d"%(gx,j),(gx*(PX+(RX-PX)/2),yy,H/2),(0.35,0.35,H/2), col_m)
# Tavan + büyük skylight ızgarası
box("Ceil",(0,0,H),(RX,RY,0.05), ceil_m)
for ix in range(-2,3):
    for iy in (-1,1):
        box("Sky%d%d"%(ix,iy),(ix*11,iy*7.5,H-0.06),(4.5,2.6,0.04), sky_m)
for ix in range(-3,4):
    box("Lt%d"%ix,(ix*8,0,H-0.06),(3.0,0.6,0.04), emit_m)
# Dünya ortam (hafif)
w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[1].default_value=0.10
w.node_tree.nodes["Background"].inputs[0].default_value=(0.8,0.86,0.92,1)
sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.use_adaptive_sampling=True; sc.cycles.adaptive_threshold=0.025; sc.cycles.samples=140
sc.cycles.use_denoising=True; sc.cycles.denoiser='OPENIMAGEDENOISE'
sc.cycles.max_bounces=6; sc.cycles.transmission_bounces=10
sc.render.resolution_x=1366; sc.render.resolution_y=768
sc.view_settings.view_transform='AgX'
try: sc.view_settings.look='AgX - Medium High Contrast'
except: pass
sc.use_nodes=True; c=sc.node_tree
rl=c.nodes["Render Layers"]; comp=c.nodes["Composite"]
gl=c.nodes.new("CompositorNodeGlare"); gl.glare_type='FOG_GLOW'; gl.quality='MEDIUM'; gl.threshold=0.9; gl.mix=-0.3
c.links.new(rl.outputs[0],gl.inputs[0]); c.links.new(gl.outputs[0],comp.inputs[0])
cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cd); bpy.context.collection.objects.link(cam)
cam.location=(-29,-15.5,1.75); cd.lens=17
d=mathutils.Vector((12,6,-1.0))-cam.location
cam.rotation_euler=d.to_track_quat('-Z','Y').to_euler()
sc.camera=cam
sc.render.filepath="/home/user/Backrooms/white_olympic.png"
bpy.ops.render.render(write_still=True)
print("OLYMPIC_DONE")
