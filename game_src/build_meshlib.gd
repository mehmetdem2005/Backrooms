extends SceneTree

func _init() -> void:
    var names := ["floor", "wall", "wall_door", "ceiling_light", "column", "stairs", "pool_water", "pool_edge"]
    var ml := MeshLibrary.new()
    var ok := 0
    for i in names.size():
        var nm: String = names[i]
        var path := "res://assets/kit/%s.glb" % nm
        var ps := load(path) as PackedScene
        if ps == null:
            printerr("YOK: ", path)
            continue
        var inst := ps.instantiate()
        var mi := _find_mi(inst)
        if mi == null:
            printerr("MESH YOK: ", nm)
            inst.free()
            continue
        ml.create_item(i)
        ml.set_item_name(i, nm)
        ml.set_item_mesh(i, mi.mesh)
        ml.set_item_mesh_transform(i, mi.transform)
        var shp := mi.mesh.create_trimesh_shape()
        if shp != null:
            ml.set_item_shapes(i, [shp, Transform3D.IDENTITY])
        ok += 1
        inst.free()
    var err := ResourceSaver.save(ml, "res://kit.meshlib.tres")
    print("MESHLIB_DONE items=", ok, " save_err=", err)
    quit()

func _find_mi(n: Node) -> MeshInstance3D:
    if n is MeshInstance3D:
        return n
    for c in n.get_children():
        var r := _find_mi(c)
        if r != null:
            return r
    return null
