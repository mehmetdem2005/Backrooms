extends SceneTree
func _init() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load("res://textures/floor_albedo.png")
    mat.roughness_texture = load("res://textures/floor_rough.png")
    mat.ao_enabled = true
    mat.ao_texture = load("res://textures/floor_ao.png")
    mat.normal_enabled = true
    mat.normal_texture = load("res://textures/floor_normal.png")
    mat.roughness = 1.0
    var bm := BoxMesh.new()
    bm.size = Vector3(4, 0.12, 4)
    bm.material = mat
    var ml := MeshLibrary.new()
    ml.create_item(0)
    ml.set_item_name(0, "Floor")
    ml.set_item_mesh(0, bm)
    ml.set_item_mesh_transform(0, Transform3D(Basis(), Vector3(0, -0.06, 0)))
    var shp := BoxShape3D.new()
    shp.size = Vector3(4, 0.12, 4)
    ml.set_item_shapes(0, [shp, Transform3D(Basis(), Vector3(0, -0.06, 0))])
    ResourceSaver.save(ml, "res://floor.meshlib.tres")

    var root := Node3D.new(); root.name = "Map"
    var gm := GridMap.new(); gm.name = "GridMap"
    gm.mesh_library = ml
    gm.cell_size = Vector3(4, 2, 4)
    gm.cell_center_y = false
    root.add_child(gm); gm.owner = root
    for x in range(0, 8):
        for z in range(0, 8):
            gm.set_cell_item(Vector3i(x, 0, z), 0)
    var cam := Camera3D.new(); cam.name = "Camera3D"
    cam.transform = Transform3D(Basis(), Vector3(16, 22, 36)).looking_at(Vector3(16, 0, 14), Vector3.UP)
    root.add_child(cam); cam.owner = root
    var sun := DirectionalLight3D.new(); sun.name = "Sun"
    sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
    sun.light_energy = 0.8
    root.add_child(sun); sun.owner = root
    var we := WorldEnvironment.new(); we.name = "WorldEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.10, 0.11, 0.13)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.92, 0.93, 0.95)
    env.ambient_light_energy = 1.0
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    we.environment = env
    root.add_child(we); we.owner = root
    var ps := PackedScene.new()
    ps.pack(root)
    ResourceSaver.save(ps, "res://Map.tscn")
    print("KIT_BUILT meshlib+map ok")
    quit()
