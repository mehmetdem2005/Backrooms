extends Node
## NAV IZGARA - AStar2D graf navigasyonu (Faz 4 canavar AI #14).
## dunya_plan.json'dan grid + nav_kapi okur; oda-ici komsuluk + KAPI baglantilariyla graf kurar.
## Boylece yol bulma DUVARDAN GECMEZ, sadece odanin icinden ve kapilardan gecer.
## OyunDurumu.nav olarak kayit olur.

const CELL := 4.0
var astar := AStar2D.new()
var H := 0
var W := 0
var grid: Array = []

func _ready() -> void:
	var f := FileAccess.open("res://tools/dunya_uretici/dunya_plan.json", FileAccess.READ)
	if f == null:
		push_error("NavIzgara: plan yok"); return
	var plan: Dictionary = JSON.parse_string(f.get_as_text()); f.close()
	grid = plan["grid"]
	H = grid.size(); W = (grid[0] as String).length()
	_kur(plan.get("nav_kapi", []))
	var od := get_node_or_null("/root/OyunDurumu")
	if od: od.nav = self

func _pid(i: int, j: int) -> int: return i * W + j
func _yuru(i: int, j: int) -> bool:
	return i >= 0 and i < H and j >= 0 and j < W and (grid[i] as String)[j] != '.'

func _kur(nav_kapi: Array) -> void:
	for i in H:
		for j in W:
			if _yuru(i, j): astar.add_point(_pid(i, j), Vector2(j, i))   # x=j, y=i
	for i in H:
		for j in W:
			if not _yuru(i, j): continue
			var a: String = (grid[i] as String)[j]
			if _yuru(i, j + 1) and (grid[i] as String)[j + 1] == a:
				astar.connect_points(_pid(i, j), _pid(i, j + 1))
			if _yuru(i + 1, j) and (grid[i + 1] as String)[j] == a:
				astar.connect_points(_pid(i, j), _pid(i + 1, j))
	for e in nav_kapi:
		var ia: int = e[0]; var ja: int = e[1]; var ib: int = e[2]; var jb: int = e[3]
		if _yuru(ia, ja) and _yuru(ib, jb):
			astar.connect_points(_pid(ia, ja), _pid(ib, jb))

func hucre(p: Vector3) -> Vector2i:    # (i, j)
	return Vector2i(int(round(p.z / CELL)), int(round(p.x / CELL)))

func _en_yakin(i: int, j: int) -> Vector2i:
	if _yuru(i, j): return Vector2i(i, j)
	for r in range(1, 8):
		for di in range(-r, r + 1):
			for dj in range(-r, r + 1):
				if _yuru(i + di, j + dj): return Vector2i(i + di, j + dj)
	return Vector2i(i, j)

func yol(a: Vector3, b: Vector3) -> PackedVector3Array:
	var ha := hucre(a); var hb := hucre(b)
	var ca := _en_yakin(ha.x, ha.y); var cb := _en_yakin(hb.x, hb.y)
	var ida := _pid(ca.x, ca.y); var idb := _pid(cb.x, cb.y)
	var bos := PackedVector3Array()
	if not astar.has_point(ida) or not astar.has_point(idb): return bos
	var p2 := astar.get_point_path(ida, idb)   # Vector2(x=j, y=i)
	var out := PackedVector3Array()
	for v in p2:
		out.append(Vector3(v.x * CELL, a.y, v.y * CELL))
	return out

func dunya(c: Vector2i) -> Vector3:
	return Vector3(c.y * CELL, 1.0, c.x * CELL)

func rastgele_yuru(merkez: Vector3, yaricap: int = 6) -> Vector3:
	var hc := hucre(merkez)
	for _t in range(20):
		var i := hc.x + randi_range(-yaricap, yaricap)
		var j := hc.y + randi_range(-yaricap, yaricap)
		if _yuru(i, j): return Vector3(j * CELL, merkez.y, i * CELL)
	return merkez
