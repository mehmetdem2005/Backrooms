extends SceneTree
func _mat(alb, rgh, nrm, ao, uv := Vector3(1,1,1)) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = load(alb)
    m.roughness_texture = load(rgh)
    m.normal_enabled = true
    m.normal_texture = load(nrm)
    m.ao_enabled = true
    m.ao_texture = load(ao)
    m.roughness = 1.0
    m.uv1_scale = uv
    return m
func _floor_part(ad: String, mat: StandardMaterial3D) -> void:
    var n := MeshInstance3D.new(); n.name = ad
    var bm := BoxMesh.new(); bm.size = Vector3(4, 0.12, 4)
    n.mesh = bm
    n.set_surface_override_material(0, mat)
    var ps := PackedScene.new(); ps.pack(n)
    ResourceSaver.save(ps, "res://parts/%s.tscn" % ad)
func _init() -> void:
    var T := "res://textures/"
    var floor_mat := _mat(T+"floor_albedo.png", T+"floor_rough.png", T+"floor_normal.png", T+"floor_ao.png")
    var gray_mat := _mat(T+"gray_tile_wall_01_albedo.png", T+"gray_tile_wall_01_roughness.png", T+"gray_tile_wall_01_normal.png", T+"gray_tile_wall_01_ao.png")
    var wall_mat := _mat(T+"gray_tile_wall_clean_albedo.png", T+"gray_tile_wall_clean_roughness.png", T+"gray_tile_wall_clean_normal.png", T+"gray_tile_wall_clean_ao.png", Vector3(1,1,1))
    ResourceSaver.save(floor_mat, "res://floor_material.tres")
    ResourceSaver.save(gray_mat, "res://gray_tile_wall_01_material.tres")
    ResourceSaver.save(wall_mat, "res://gray_tile_wall_clean_material.tres")
    _floor_part("Zemin", floor_mat)
    _floor_part("GriZemin", gray_mat)
    # Duvar: kök "Duvar" > "Yuzey" (dikey kutu, taban y=0)
    var kok := Node3D.new(); kok.name = "Duvar"
    var yuzey := MeshInstance3D.new(); yuzey.name = "Yuzey"
    var bm := BoxMesh.new(); bm.size = Vector3(4, 3, 0.2)
    yuzey.mesh = bm
    yuzey.position = Vector3(0, 1.5, 0)
    yuzey.set_surface_override_material(0, wall_mat)
    kok.add_child(yuzey); yuzey.owner = kok
    var ps := PackedScene.new(); ps.pack(kok)
    ResourceSaver.save(ps, "res://parts/Duvar.tscn")
    print("ALL_BUILT ok")
    quit()
