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
    # Parça: "Zemin" (kök düğüm adı Türkçe, "Mesh" yok)
    var zemin := MeshInstance3D.new()
    zemin.name = "Zemin"
    var pm := PlaneMesh.new()
    pm.size = Vector2(4, 4)
    zemin.mesh = pm
    zemin.set_surface_override_material(0, mat)
    var zs := PackedScene.new()
    zs.pack(zemin)
    ResourceSaver.save(zs, "res://parts/Zemin.tscn")
    # Sahne: Harita (kamera + ışık + ortam; boş, sen dizeceksin)
    var root := Node3D.new(); root.name = "Harita"
    var cam := Camera3D.new(); cam.name = "Kamera"
    cam.transform = Transform3D(Basis(), Vector3(10, 16, 26)).looking_at(Vector3(8, 0, 8), Vector3.UP)
    root.add_child(cam); cam.owner = root
    var sun := DirectionalLight3D.new(); sun.name = "Isik"
    sun.rotation = Vector3(deg_to_rad(-55), deg_to_rad(35), 0)
    sun.light_energy = 0.8
    root.add_child(sun); sun.owner = root
    var we := WorldEnvironment.new(); we.name = "Ortam"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.10, 0.11, 0.13)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.92, 0.93, 0.95)
    env.ambient_light_energy = 1.0
    env.tonemap_mode = Environment.TONE_MAPPER_AGX
    we.environment = env
    root.add_child(we); we.owner = root
    var ls := PackedScene.new(); ls.pack(root)
    ResourceSaver.save(ls, "res://Harita.tscn")
    print("PARTS_BUILT ok")
    quit()
