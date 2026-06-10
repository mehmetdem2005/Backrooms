extends SceneTree
## Backrooms DUNYA insacisi: dunya_plan.json -> Dunya.tscn (oynanabilir).
## Kullanim: godot --headless --script res://tools/dunya_uretici/insa_dunya.gd
## Parcalari (res://parts/*.tscn) ORNEKLER (kapi animasyonu/dokular korunur),
## carpisma + isik + leke ekler, FPS oyuncu + ortam kurar, Dunya.tscn olarak kaydeder.

const PLAN := "res://tools/dunya_uretici/dunya_plan.json"

var kok: Node3D
var grup_yapi: Node3D
var grup_obje: Node3D
var grup_isik: Node3D
var grup_leke: Node3D
var _leke_mat := {}     # tex yolu -> StandardMaterial3D (paylasimli)

func _init() -> void:
	var f := FileAccess.open(PLAN, FileAccess.READ)
	if f == null:
		push_error("plan bulunamadi: " + PLAN); quit(1); return
	var plan: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()

	kok = Node3D.new(); kok.name = "Dunya"
	_ortam()
	grup_yapi = _grup("Yapi"); grup_obje = _grup("Objeler")
	grup_isik = _grup("Isiklar"); grup_leke = _grup("Lekeler")

	for it in plan["instances"]:
		_instance(it)
	for lt in plan["lights"]:
		_isik(lt)
	for st in plan["stains"]:
		_leke(st)
	_oyuncu(plan["spawn"])
	_chunk_yonetici()

	var ps := PackedScene.new()
	var hata := ps.pack(kok)
	if hata != OK:
		push_error("pack hatasi: %d" % hata); quit(1); return
	var ok := ResourceSaver.save(ps, "res://Dunya.tscn")
	print("DUNYA_KAYDEDILDI hata=%d  yapi=%d obje=%d isik=%d leke=%d" % [
		ok, grup_yapi.get_child_count(), grup_obje.get_child_count(),
		grup_isik.get_child_count(), grup_leke.get_child_count()])
	quit()

func _grup(ad: String) -> Node3D:
	var g := Node3D.new(); g.name = ad
	kok.add_child(g); g.owner = kok
	return g

func _xform(pos: Array, rot: float, scale: Array) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(rot)).scaled(Vector3(scale[0], scale[1], scale[2]))
	return Transform3D(b, Vector3(pos[0], pos[1], pos[2]))

func _instance(it: Dictionary) -> void:
	var part: String = it["part"]
	var yol := "res://parts/%s.tscn" % part
	var ps := load(yol) as PackedScene
	if ps == null:
		push_warning("parca yok: " + yol); return
	var n := ps.instantiate() as Node3D
	if n == null: return
	var sc: Array = it.get("scale", [1, 1, 1])
	n.transform = _xform(it["pos"], it["rot"], sc)
	var ust := grup_obje if part in ["Mazgal","GuvenlikKamerasi","EndustriyelLamba","CopKutusu","ElektrikPanosu","Kapi"] else grup_yapi
	ust.add_child(n); n.owner = kok

	# carpisma kutusu (col = [sx,sy,sz, offy]); olcek baked.
	if it.get("col") != null:
		var c: Array = it["col"]
		var sb := StaticBody3D.new()
		var b := Basis(Vector3.UP, deg_to_rad(it["rot"]))
		var cy: float = float(it["pos"][1]) + float(c[3]) * float(sc[1])
		sb.transform = Transform3D(b, Vector3(it["pos"][0], cy, it["pos"][2]))
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(float(c[0]) * float(sc[0]), float(c[1]) * float(sc[1]), float(c[2]) * float(sc[2]))
		cs.shape = box
		sb.add_child(cs)
		grup_yapi.add_child(sb); sb.owner = kok; cs.owner = kok

func _isik(lt: Dictionary) -> void:
	var o := OmniLight3D.new()
	var p: Array = lt["pos"]; o.position = Vector3(p[0], p[1], p[2])
	var c: Array = lt["color"]; o.light_color = Color(c[0], c[1], c[2])
	o.light_energy = lt["energy"]; o.omni_range = lt["range"]
	o.shadow_enabled = false
	o.distance_fade_enabled = true
	o.distance_fade_begin = 22.0
	o.distance_fade_length = 8.0
	grup_isik.add_child(o); o.owner = kok

func _leke(st: Dictionary) -> void:
	var tex_yol := "res://textures/%s.png" % st["tex"]
	if not _leke_mat.has(tex_yol):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(tex_yol)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.25, 0.22, 0.18, 0.85)
		_leke_mat[tex_yol] = m
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(st["size"], st["size"])
	mi.mesh = pm
	mi.material_override = _leke_mat[tex_yol]
	var p: Array = st["pos"]
	mi.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(st.get("rot", 0.0))), Vector3(p[0], p[1], p[2]))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grup_leke.add_child(mi); mi.owner = kok

func _ortam() -> void:
	var we := WorldEnvironment.new(); we.name = "Ortam"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.15, 0.13)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.09, 0.07)
	env.fog_density = 0.025
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.ssao_enabled = false   # mobil perf (Faz2)
	we.environment = env
	kok.add_child(we); we.owner = kok

func _oyuncu(spawn: Array) -> void:
	var p := CharacterBody3D.new(); p.name = "Oyuncu"
	p.position = Vector3(spawn[0], spawn[1], spawn[2])
	p.set_script(load("res://oyuncu.gd"))
	kok.add_child(p); p.owner = kok          # once agaca ekle ki owner=kok gecerli olsun
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.height = 1.7; cap.radius = 0.35
	cs.shape = cap; cs.position = Vector3(0, 0.85, 0)
	p.add_child(cs); cs.owner = kok
	var cam := Camera3D.new(); cam.name = "Kamera"
	cam.position = Vector3(0, 1.6, 0); cam.current = true
	p.add_child(cam); cam.owner = kok
	# el feneri hissi
	var sp := SpotLight3D.new(); sp.name = "Fener"
	sp.position = Vector3(0, 1.6, 0)
	sp.light_energy = 2.0; sp.spot_range = 14.0; sp.spot_angle = 35.0
	cam.add_child(sp); sp.owner = kok

func _chunk_yonetici() -> void:
	var cy := Node.new(); cy.name = "ChunkYonetici"
	cy.set_script(load("res://addons/chunk/ChunkYonetici.gd"))
	kok.add_child(cy); cy.owner = kok
	cy.set("oyuncu_yolu", NodePath("../Oyuncu"))
	cy.set("chunk", 14.0); cy.set("yaricap", 3)
