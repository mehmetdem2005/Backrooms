import bpy, math
from mathutils import Vector

T="/home/user/Backrooms/game_src/textures/"
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def img(path):
    return bpy.data.images.load(path)

def pbr_mat(name, albedo, normal, rough, uvscale=(4,4), rough_val=0.6, tint=(1,1,1)):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf=nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    tc=nt.nodes.new("ShaderNodeTexCoord"); mp=nt.nodes.new("ShaderNodeMapping")
    mp.inputs[3].default_value=(uvscale[0],uvscale[1],1)
    nt.links.new(tc.outputs["UV"], mp.inputs[0])
    ta=nt.nodes.new("ShaderNodeTexImage"); ta.image=img(albedo)
    nt.links.new(mp.outputs[0], ta.inputs[0]); nt.links.new(ta.outputs[0], bsdf.inputs["Base Color"])
    if rough:
        tr=nt.nodes.new("ShaderNodeTexImage"); tr.image=img(rough); tr.image.colorspace_settings.name="Non-Color"
        nt.links.new(mp.outputs[0], tr.inputs[0]); nt.links.new(tr.outputs[0], bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Roughness"].default_value=rough_val
    if normal:
        tn=nt.nodes.new("ShaderNodeTexImage"); tn.image=img(normal); tn.image.colorspace_settings.name="Non-Color"
        nb=nt.nodes.new("ShaderNodeNormalMap"); nb.inputs[0].default_value=0.6
        nt.links.new(mp.outputs[0], tn.inputs[0]); nt.links.new(tn.outputs[0], nb.inputs[1]); nt.links.new(nb.outputs[0], bsdf.inputs["Normal"])
    return m

def emit_mat(name, strength=6.0, col=(1,0.98,0.95)):
    m=bpy.data.materials.new(name); m.use_nodes=True
    nt=m.node_tree; nt.nodes.clear()
    out=nt.nodes.new("ShaderNodeOutputMaterial"); e=nt.nodes.new("ShaderNodeEmission")
    e.inputs[0].default_value=(col[0],col[1],col[2],1); e.inputs[1].default_value=strength
    nt.links.new(e.outputs[0], out.inputs[0]); return m

def box(name, loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(location=loc); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(scale=True)
    # UV smart project for tiling
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.uv.cube_project(cube_size=1.0); bpy.ops.object.mode_set(mode='OBJECT')
    o.data.materials.append(mat); return o

reset()
white_tile = pbr_mat("WhiteTile", T+"tile_albedo.png", T+"tile_normal.png", T+"tile_roughness.png", uvscale=(2,2))
concrete   = pbr_mat("WhiteWall", T+"white_wall_albedo.png", T+"white_wall_normal.png", T+"white_wall_rough.png", uvscale=(2.5,2.5))
white_ceil = pbr_mat("WhiteCeil", T+"tile_albedo.png", None, None, uvscale=(3,3), rough_val=0.7)
emit = emit_mat("CeilLight", 9.0)

# Koridor: 4m geniş, 24m uzun, 3m yüksek
L=24; Wd=4; Ht=3
box("Floor",(0,0,0),(Wd/2,L/2,0.05), white_tile)
box("Ceil",(0,0,Ht),(Wd/2,L/2,0.05), white_ceil)
box("WallL",(-Wd/2,0,Ht/2),(0.05,L/2,Ht/2), concrete)
box("WallR",(Wd/2,0,Ht/2),(0.05,L/2,Ht/2), concrete)
box("WallEnd",(0,L/2,Ht/2),(Wd/2,0.05,Ht/2), concrete)
# Yan oda açıklığı (sağda)
box("SideFloor",(Wd/2+3,0,0),(3,3,0.05), white_tile)
box("SideCeil",(Wd/2+3,0,Ht),(3,3,0.05), white_ceil)
box("SideBack",(Wd/2+6,0,Ht/2),(0.05,3,Ht/2), concrete)
box("SideW1",(Wd/2+3,3,Ht/2),(3,0.05,Ht/2), concrete)
box("SideW2",(Wd/2+3,-3,Ht/2),(3,0.05,Ht/2), concrete)
# Emissive tavan panelleri (gerçek ışık yok)
for i in range(5):
    yy=-L/2+3+i*5
    box("Panel%d"%i,(0,yy,Ht-0.06),(0.9,1.1,0.02), emit)
box("SidePanel",(Wd/2+3,0,Ht-0.06),(1.4,1.4,0.02), emit)

# Kamera
cam_data=bpy.data.cameras.new("Cam"); cam=bpy.data.objects.new("Cam",cam_data)
bpy.context.collection.objects.link(cam)
cam.location=(0,-L/2+1.5,1.6); cam.rotation_euler=(math.radians(86),0,0)
cam_data.lens=24
bpy.context.scene.camera=cam

# Dünya: hafif ortam
world=bpy.data.worlds.new("W"); bpy.context.scene.world=world; world.use_nodes=True
world.node_tree.nodes["Background"].inputs[1].default_value=0.04

# Render Cycles CPU
sc=bpy.context.scene
sc.render.engine='CYCLES'
sc.cycles.device='CPU'
sc.cycles.samples=96
sc.cycles.use_denoising=True
sc.render.resolution_x=1280; sc.render.resolution_y=720
sc.render.filepath="/home/user/Backrooms/white_render.png"
sc.view_settings.view_transform='Filmic'
bpy.ops.render.render(write_still=True)
print("WHITE_RENDER_DONE")
