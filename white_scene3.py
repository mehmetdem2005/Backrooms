import bpy, math
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

def emit(name,s=12,c=(1,0.99,0.96)):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); e=nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value=(*c,1); e.inputs[1].default_value=s; nt.links.new(e.outputs[0],o.inputs[0]); return m

def water_mat():
    m=bpy.data.materials.new("Water"); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); b=nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value=(0.5,0.76,0.8,1); b.inputs["Roughness"].default_value=0.02
    b.inputs["Transmission Weight"].default_value=1.0; b.inputs["IOR"].default_value=1.33
    nt.links.new(b.outputs[0],o.inputs[0])
    tc=nt.nodes.new("ShaderNodeTexCoord"); nz=nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value=18
    bp=nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value=0.05
    nt.links.new(tc.outputs["Object"],nz.inputs["Vector"]); nt.links.new(nz.outputs["Fac"],bp.inputs["Height"]); nt.links.new(bp.outputs["Normal"],b.inputs["Normal"])
    return m

def solid(name,col,rough=0.6):
    m=bpy.data.materials.new(name); m.use_nodes=True; b=m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value=(*col,1); b.inputs["Roughness"].default_value=rough; return m

def box(name,loc,scale,mat,uvcube=True):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(scale=True)
    if uvcube:
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o

reset()
floor_m  = pbr("Floor", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,2), rough_val=0.06, normstr=0.2)
plaster  = pbr("Wall",  T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(2.2,2.2), normstr=0.5)
wains    = pbr("Wainscot", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1.5,1.5), rough_val=0.12, normstr=0.3)
ceil_m   = solid("Ceil",(0.93,0.92,0.9),0.6)
emit_m   = emit("Light",14)
emit_off = solid("Off",(0.2,0.21,0.22),0.5)
frame_m  = solid("Frame",(0.82,0.82,0.8),0.35)
trim_m   = solid("Trim",(0.7,0.7,0.68),0.4)
col_m    = pbr("Column", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(1,2), rough_val=0.1)
water    = water_mat()

L=28; Wd=4.2; Ht=3.0; WAIN=1.15
box("Floor",(0,-3,0),(Wd/2,(L/2-3),0.05), floor_m)
box("PoolFloor",(0,L/2-4,-0.4),(Wd/2,4,0.05), wains)
box("PoolLipL",(-Wd/2+0.15,L/2-4,-0.18),(0.12,4,0.22), trim_m)
box("PoolLipR",( Wd/2-0.15,L/2-4,-0.18),(0.12,4,0.22), trim_m)
box("PoolBack",(0,L/2-0.2,-0.18),(Wd/2,0.12,0.22), trim_m)
box("WaterSurf",(0,L/2-4,-0.10),(Wd/2-0.16,4,0.004), water, uvcube=False)
box("Ceil",(0,0,Ht),(Wd/2,L/2,0.05), ceil_m)
for sx,nm in [(-1,"L"),(1,"R")]:
    box("WainLow"+nm,(sx*Wd/2,0,WAIN/2),(0.05,L/2,WAIN/2), wains)
    box("WallUp"+nm,(sx*Wd/2,0,WAIN+(Ht-WAIN)/2),(0.05,L/2,(Ht-WAIN)/2), plaster)
    box("Trim"+nm,(sx*(Wd/2-0.02),0,WAIN),(0.03,L/2,0.04), trim_m)
    box("Base"+nm,(sx*(Wd/2-0.05),0,0.07),(0.035,L/2,0.07), trim_m)
for i in range(5):
    yy=-L/2+5+i*4.6
    for sx in (-1,1):
        box("Col%d%d"%(i,sx),(sx*(Wd/2-0.22),yy,Ht/2),(0.22,0.22,Ht/2), col_m)
box("EndWallT",(0,L/2,Ht-0.35),(Wd/2,0.05,0.35), plaster)
box("EndGlow",(0,L/2-0.05,1.15),(0.95,0.02,1.15), emit("EndGlow",8,(1,1,0.98)))
for i in range(6):
    yy=-L/2+3+i*4.6
    box("Frame%d"%i,(0,yy,Ht-0.02),(1.05,1.25,0.045), frame_m)
    box("Light%d"%i,(0,yy,Ht-0.10),(0.85,1.05,0.03), emit_off if i==3 else emit_m)

cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cd); bpy.context.collection.objects.link(cam)
cam.location=(0.5,-L/2+1.0,1.5); cam.rotation_euler=(math.radians(87),0,math.radians(1.5)); cd.lens=22
cd.dof.use_dof=True; cd.dof.focus_distance=13.0; cd.dof.aperture_fstop=4.5
bpy.context.scene.camera=cam

w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True
w.node_tree.nodes["Background"].inputs[1].default_value=0.03

sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'
sc.cycles.use_adaptive_sampling=True; sc.cycles.adaptive_threshold=0.015; sc.cycles.samples=200
sc.cycles.use_denoising=True; sc.cycles.denoiser='OPENIMAGEDENOISE'
sc.cycles.max_bounces=6; sc.cycles.transmission_bounces=6
sc.render.resolution_x=1600; sc.render.resolution_y=900
sc.render.filepath="/home/user/Backrooms/white_render_hq.png"
sc.view_settings.view_transform='AgX'
try: sc.view_settings.look='AgX - Medium High Contrast'
except: pass
sc.use_nodes=True; c=sc.node_tree
rl=c.nodes["Render Layers"]; comp=c.nodes["Composite"]
cb=c.nodes.new("CompositorNodeColorBalance"); cb.correction_method='LIFT_GAMMA_GAIN'
cb.gamma=(0.97,1.0,1.04); cb.gain=(0.98,1.0,1.03)
gl=c.nodes.new("CompositorNodeGlare"); gl.glare_type='FOG_GLOW'; gl.quality='MEDIUM'; gl.threshold=0.85; gl.mix=-0.25
c.links.new(rl.outputs[0],cb.inputs[1]); c.links.new(cb.outputs[0],gl.inputs[0]); c.links.new(gl.outputs[0],comp.inputs[0])
bpy.ops.render.render(write_still=True)
print("HQ3_RENDER_DONE")
