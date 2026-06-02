extends SceneTree
func _init() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load("res://textures/gray_tile_wall_01_albedo.png")
    mat.roughness_texture = load("res://textures/gray_tile_wall_01_roughness.png")
    mat.normal_enabled = true
    mat.normal_texture = load("res://textures/gray_tile_wall_01_normal.png")
    mat.ao_enabled = true
    mat.ao_texture = load("res://textures/gray_tile_wall_01_ao.png")
    mat.roughness = 1.0
    ResourceSaver.save(mat, "res://gray_tile_wall_01_material.tres")
    var n := MeshInstance3D.new()
    n.name = "Gri Zemin"
    var pm := PlaneMesh.new()
    pm.size = Vector2(4, 4)
    n.mesh = pm
    n.set_surface_override_material(0, mat)
    var ps := PackedScene.new()
    ps.pack(n)
    ResourceSaver.save(ps, "res://parts/GriZemin.tscn")
    print("GRAY_BUILT ok")
    quit()
