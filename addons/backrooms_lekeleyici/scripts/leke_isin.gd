@tool
class_name LekeIsin
extends RefCounted
## Editör ışını: kameradan ekran noktasına ışın atar, sahnedeki MeshInstance3D
## parçalarına (duvar/zemin/tavan) üçgen bazlı çarpıştırır. Collision/StaticBody
## gerektirmez — yerleştirici parçaları sadece BoxMesh olduğundan çalışır.
## Lekelerin kendisi (meta "leke") atlanır.

## Sonuç: {"carpti":bool, "nokta":Vector3, "normal":Vector3, "dugum":Node}
static func sahne_isin(kok: Node, kamera: Camera3D, ekran: Vector2) -> Dictionary:
	var sonuc := {"carpti": false, "nokta": Vector3.ZERO, "normal": Vector3.UP, "dugum": null}
	if kok == null or kamera == null:
		return sonuc
	var o := kamera.project_ray_origin(ekran)
	var d := kamera.project_ray_normal(ekran)
	var en_yakin := INF
	var meshler: Array[MeshInstance3D] = []
	_topla(kok, meshler)
	for mi in meshler:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var gt := mi.global_transform
		var gt_inv := gt.affine_inverse()
		# Işını mesh yerel uzayına taşı (AABB ön eleme için).
		var yerel_o := gt_inv * o
		var yerel_d := (gt_inv.basis * d)  # yön: sadece basis
		if not _aabb_isin(mi.mesh.get_aabb(), yerel_o, yerel_d):
			continue
		var t := _mesh_ucgen_isin(mi.mesh, yerel_o, yerel_d)
		if t.x >= 0.0:
			# Yerel çarpma noktası ve normalini dünyaya çevir.
			var yerel_nokta := yerel_o + yerel_d * t.x
			var dunya_nokta := gt * yerel_nokta
			# Dünya mesafesi tüm mesh'ler arasında karşılaştırılabilir (yerel t birimleri değil).
			var dunya_mesafe := o.distance_to(dunya_nokta)
			if dunya_mesafe < en_yakin:
				# t.yzw = yerel üçgen normali
				var yerel_n := Vector3(t.y, t.z, t.w)
				var dunya_n := (gt.basis.inverse().transposed() * yerel_n).normalized()
				# İzleyiciye doğru bakacak şekilde normali düzelt.
				if dunya_n.dot(d) > 0.0:
					dunya_n = -dunya_n
				en_yakin = dunya_mesafe
				sonuc.carpti = true
				sonuc.nokta = dunya_nokta
				sonuc.normal = dunya_n
				sonuc.dugum = mi
	return sonuc

static func _topla(n: Node, dizi: Array[MeshInstance3D]) -> void:
	if n.has_meta("leke"):
		return  # leke sticker'larını ışına dahil etme
	if n is MeshInstance3D:
		dizi.append(n)
	for c in n.get_children():
		_topla(c, dizi)

## AABB - ışın kesişimi (slab yöntemi). Sadece var/yok döner.
static func _aabb_isin(aabb: AABB, o: Vector3, d: Vector3) -> bool:
	var tmin := -INF
	var tmax := INF
	var mn := aabb.position
	var mx := aabb.position + aabb.size
	for i in 3:
		var oi := o[i]
		var di := d[i]
		if absf(di) < 1e-9:
			if oi < mn[i] or oi > mx[i]:
				return false
		else:
			var t1 := (mn[i] - oi) / di
			var t2 := (mx[i] - oi) / di
			if t1 > t2:
				var tmp := t1; t1 = t2; t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return false
	return tmax >= 0.0

## Mesh'in tüm yüzeylerini gezip en yakın üçgen kesişimini bulur.
## Döner: Vector4(t, nx, ny, nz). t < 0 ise kesişim yok.
static func _mesh_ucgen_isin(mesh: Mesh, o: Vector3, d: Vector3) -> Vector4:
	var en := INF
	var sonuc := Vector4(-1.0, 0.0, 1.0, 0.0)
	for s in mesh.get_surface_count():
		# NOT: surface_get_primitive_type yalnızca ArrayMesh'te var. BoxMesh gibi
		# PrimitiveMesh'ler her zaman üçgendir, o yüzden sadece ArrayMesh'te kontrol et.
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(s)
		if arr.is_empty():
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			# indekssiz: ardışık üçgenler
			var i := 0
			while i + 2 < verts.size():
				var t := _ucgen(o, d, verts[i], verts[i + 1], verts[i + 2])
				if t >= 0.0 and t < en:
					en = t
					var nrm := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i]).normalized()
					sonuc = Vector4(t, nrm.x, nrm.y, nrm.z)
				i += 3
		else:
			var i := 0
			while i + 2 < idx.size():
				var a := verts[idx[i]]
				var b := verts[idx[i + 1]]
				var c := verts[idx[i + 2]]
				var t := _ucgen(o, d, a, b, c)
				if t >= 0.0 and t < en:
					en = t
					var nrm := (b - a).cross(c - a).normalized()
					sonuc = Vector4(t, nrm.x, nrm.y, nrm.z)
				i += 3
	return sonuc

## Möller–Trumbore ışın-üçgen kesişimi. Çarpışma mesafesi t, yoksa -1.
static func _ucgen(o: Vector3, d: Vector3, v0: Vector3, v1: Vector3, v2: Vector3) -> float:
	var e1 := v1 - v0
	var e2 := v2 - v0
	var p := d.cross(e2)
	var det := e1.dot(p)
	if absf(det) < 1e-8:
		return -1.0
	var inv := 1.0 / det
	var tv := o - v0
	var u := tv.dot(p) * inv
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := tv.cross(e1)
	var v := d.dot(q) * inv
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := e2.dot(q) * inv
	if t < 1e-5:
		return -1.0
	return t
