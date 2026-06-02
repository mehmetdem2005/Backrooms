extends SceneTree
func _init() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load("res://textures/gray_tile_wall_clean_albedo.png")
    mat.roughness_texture = load("res://textures/gray_tile_wall_clean_roughness.png")
    mat.normal_enabled = true
    mat.normal_texture = load("res://textures/gray_tile_wall_clean_normal.png")
    mat.ao_enabled = true
    mat.ao_texture = load("res://textures/gray_tile_wall_clean_ao.png")
    mat.roughness = 1.0
    mat.uv1_scale = Vector3(2, 1.5, 1)  # ~1m karelere yakın
    ResourceSaver.save(mat, "res://gray_tile_wall_clean_material.tres")
    # Duvar: kök "Duvar" (Node3D), içinde "Yuzey" (dikey kutu, taban y=0)
    var kok := Node3D.new(); kok.name = "Duvar"
    var yuzey := MeshInstance3D.new(); yuzey.name = "Yuzey"
    var bm := BoxMesh.new(); bm.size = Vector3(4, 3, 0.2)
    yuzey.mesh = bm
    yuzey.position = Vector3(0, 1.5, 0)   # taban yere otursun
    yuzey.set_surface_override_material(0, mat)
    kok.add_child(yuzey); yuzey.owner = kok
    var ps := PackedScene.new(); ps.pack(kok)
    ResourceSaver.save(ps, "res://parts/Duvar.tscn")
    print("WALL_BUILT ok")
    quit()
