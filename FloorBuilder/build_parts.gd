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
    ResourceSaver.save(mat, "res://floor_material.tres")

    # --- FloorTile.tscn : tek zemin parçası (PlaneMesh 4x4) ---
    var tile := MeshInstance3D.new()
    tile.name = "FloorTile"
    var pm := PlaneMesh.new()
    pm.size = Vector2(4, 4)
    tile.mesh = pm
    tile.set_surface_override_material(0, mat)
    var ts := PackedScene.new()
    ts.pack(tile)
    ResourceSaver.save(ts, "res://FloorTile.tscn")

    # --- Level.tscn : haritayı dizeceğin sahne (demo 4x4 + kamera + ışık) ---
    var root := Node3D.new(); root.name = "Level"
    var holder := Node3D.new(); holder.name = "Floors"
    root.add_child(holder); holder.owner = root
    for x in range(4):
        for z in range(4):
            var inst := ts.instantiate()
            inst.position = Vector3(x * 4, 0, z * 4)
            holder.add_child(inst); inst.owner = root
    var cam := Camera3D.new(); cam.name = "Camera3D"
    cam.transform = Transform3D(Basis(), Vector3(6, 17, 28)).looking_at(Vector3(6, 0, 6), Vector3.UP)
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
    var ls := PackedScene.new()
    ls.pack(root)
    ResourceSaver.save(ls, "res://Level.tscn")
    print("PARTS_BUILT ok")
    quit()
