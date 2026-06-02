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
    return m,b

def emit(name,s=12,c=(1,0.99,0.96)):
    m=bpy.data.materials.new(name); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); e=nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value=(*c,1); e.inputs[1].default_value=s; nt.links.new(e.outputs[0],o.inputs[0]); return m

def water_mat():
    m=bpy.data.materials.new("Water"); m.use_nodes=True; nt=m.node_tree; nt.nodes.clear()
    o=nt.nodes.new("ShaderNodeOutputMaterial"); b=nt.nodes.new("ShaderNodeBsdfPrincipled")
    b.inputs["Base Color"].default_value=(0.55,0.78,0.82,1)
    b.inputs["Roughness"].default_value=0.02
    b.inputs["Transmission Weight"].default_value=1.0
    b.inputs["IOR"].default_value=1.33
    nt.links.new(b.outputs[0],o.inputs[0]); return m

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
floor_m,_   = pbr("Floor", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(2,2), rough_val=0.07, normstr=0.25)  # ıslak/yansıtıcı
wall_m,_    = pbr("Wall",  T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uv=(2.2,2.2), normstr=0.5)
ceil_m      = solid("Ceil",(0.92,0.91,0.88),0.6)
emit_m      = emit("Light",13)
frame_m     = solid("Frame",(0.85,0.85,0.83),0.4)
base_m      = solid("Base",(0.78,0.78,0.76),0.4)
water       = water_mat()
pooltile,_  = pbr("PoolTile", T+"tile_albedo.png", T+"tile_normal.png", None, uv=(3,3), rough_val=0.2)

L=28; Wd=4; Ht=3
# Zemin: koridor önü kuru fayans, son üçte bir SU (sığ havuz)
box("Floor",(0,-3,0),(Wd/2,(L/2-3),0.05), floor_m)
# havuz çukuru (son kısım): tabanı 0.35 alçak
box("PoolFloor",(0,L/2-4,-0.35),(Wd/2,4,0.05), pooltile)
box("PoolLipL",(-Wd/2+0.15,L/2-4,-0.15),(0.12,4,0.2), base_m)
box("PoolLipR",( Wd/2-0.15,L/2-4,-0.15),(0.12,4,0.2), base_m)
# su yüzeyi
wp=box("WaterSurf",(0,L/2-4,-0.08),(Wd/2-0.18,4,0.005), water, uvcube=False)
# Tavan + duvarlar
box("Ceil",(0,0,Ht),(Wd/2,L/2,0.05), ceil_m)
box("WallL",(-Wd/2,0,Ht/2),(0.05,L/2,Ht/2), wall_m)
box("WallR",(Wd/2,0,Ht/2),(0.05,L/2,Ht/2), wall_m)
# Süpürgelik
box("BaseL",(-Wd/2+0.06,0,0.08),(0.04,L/2,0.08), base_m)
box("BaseR",( Wd/2-0.06,0,0.08),(0.04,L/2,0.08), base_m)
# Uçta aydınlık kapı boşluğu (gizemli çıkış parıltısı)
box("EndWallTop",(0,L/2,Ht-0.4),(Wd/2,0.05,0.4), wall_m)
box("EndGlow",(0,L/2-0.06,1.1),(0.9,0.02,1.1), emit("EndGlow",6,(1,1,0.97)))
# Gömme aydınlatma armatürleri (çerçeve + içte emissive)
for i in range(6):
    yy=-L/2+3+i*4.6
    box("Frame%d"%i,(0,yy,Ht-0.02),(1.05,1.25,0.04), frame_m)
    box("Light%d"%i,(0,yy,Ht-0.10),(0.85,1.05,0.03), emit_m)

# Kamera
cd=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cd); bpy.context.collection.objects.link(cam)
cam.location=(0.4,-L/2+1.0,1.55); cam.rotation_euler=(math.radians(87),0,math.radians(2)); cd.lens=22
bpy.context.scene.camera=cam

# Dünya + hafif hacimsel sis (god-ray)
w=bpy.data.worlds.new("W"); bpy.context.scene.world=w; w.use_nodes=True; nt=w.node_tree
w.node_tree.nodes["Background"].inputs[1].default_value=0.03
vol=nt.nodes.new("ShaderNodeVolumeScatter"); vol.inputs[1].default_value=0.012
nt.links.new(vol.outputs[0], nt.nodes["World Output"].inputs[1])

sc=bpy.context.scene
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=220; sc.cycles.use_denoising=True
sc.cycles.max_bounces=8; sc.cycles.transmission_bounces=8; sc.cycles.volume_bounces=2
sc.render.resolution_x=1920; sc.render.resolution_y=1080
sc.render.filepath="/home/user/Backrooms/white_render_hq.png"
try: sc.view_settings.view_transform='AgX'
except: sc.view_settings.view_transform='Filmic'
sc.view_settings.look='AgX - Medium High Contrast' if sc.view_settings.view_transform=='AgX' else 'None'
# Glare (bloom)
sc.use_nodes=True; ntc=sc.node_tree
rl=ntc.nodes["Render Layers"]; comp=ntc.nodes["Composite"]
gl=ntc.nodes.new("CompositorNodeGlare"); gl.glare_type='FOG_GLOW'; gl.quality='MEDIUM'; gl.threshold=0.8; gl.mix=-0.2
ntc.links.new(rl.outputs[0],gl.inputs[0]); ntc.links.new(gl.outputs[0],comp.inputs[0])
bpy.ops.render.render(write_still=True)
print("HQ_RENDER_DONE")
