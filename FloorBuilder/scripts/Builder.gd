extends Node3D
## Zemin yerleştirme aracı: dokunduğun yere zemin koyar/kaldırır.
## Sadece kullanıcının verdiği zemin dokusu kullanılır (placeholder yok).

const G: float = 4.0  # tek karo = 4x4 m (üzerinde 4x4 fayans deseni)

var cam: Camera3D
var floor_mat: StandardMaterial3D
var tile_mesh: BoxMesh
var placed: Dictionary = {}     # Vector2i -> MeshInstance3D
var cursor: MeshInstance3D

# kamera
var target: Vector3 = Vector3.ZERO
var cam_yaw: float = deg_to_rad(35.0)
var cam_pitch: float = deg_to_rad(-52.0)
var cam_dist: float = 26.0

# giriş takibi
var press_pos: Vector2 = Vector2.ZERO
var press_time: int = 0
var dragging: bool = false
var touch_points: Dictionary = {}
var last_pinch: float = 0.0

func _ready() -> void:
	_setup_env()
	_setup_material()
	_setup_ground()
	cam = Camera3D.new()
	add_child(cam)
	_update_cam()
	cursor = _make_cursor()
	add_child(cursor)
	_make_ui()
	# Demo: ortada 6x6 zemin (sen ekleyip çıkarabilirsin)
	for x in range(-3, 3):
		for z in range(-3, 3):
			_place(Vector2i(x, z))

func _setup_env() -> void:
	var we: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.93, 0.96)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	we.environment = env
	add_child(we)
	# tek hafif yön ışığı (ucuz; gerçek-zamanlı omni yığını YOK)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 0.5
	add_child(sun)

func _setup_material() -> void:
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_texture = load("res://textures/floor_albedo.png")
	floor_mat.roughness_texture = load("res://textures/floor_rough.png")
	floor_mat.ao_enabled = true
	floor_mat.ao_texture = load("res://textures/floor_ao.png")
	floor_mat.normal_enabled = true
	floor_mat.normal_texture = load("res://textures/floor_normal.png")
	floor_mat.normal_scale = 1.0
	floor_mat.roughness = 1.0
	tile_mesh = BoxMesh.new()
	tile_mesh.size = Vector3(G, 0.12, G)

func _setup_ground() -> void:
	var p: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(600, 600)
	p.mesh = pm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.10, 0.11, 0.13)
	gm.roughness = 0.9
	p.set_surface_override_material(0, gm)
	p.position.y = -0.08
	add_child(p)

func _make_cursor() -> MeshInstance3D:
	var c: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(G, 0.03, G)
	c.mesh = bm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.80, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	c.set_surface_override_material(0, m)
	return c

func _make_ui() -> void:
	var cl: CanvasLayer = CanvasLayer.new()
	add_child(cl)
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.45)
	panel.position = Vector2(10, 10)
	panel.size = Vector2(560, 40)
	cl.add_child(panel)
	var lbl: Label = Label.new()
	lbl.text = "Dokun/Tıkla = zemin koy/kaldır   •   Sürükle = kaydır   •   Tekerlek / çift parmak = yakınlaştır"
	lbl.position = Vector2(20, 18)
	cl.add_child(lbl)

func _cell_from_screen(sp: Vector2) -> Vector2i:
	var from: Vector3 = cam.project_ray_origin(sp)
	var dir: Vector3 = cam.project_ray_normal(sp)
	if absf(dir.y) < 1e-5:
		return Vector2i(2147483, 2147483)
	var t: float = -from.y / dir.y
	var hit: Vector3 = from + dir * t
	return Vector2i(floori(hit.x / G), floori(hit.z / G))

func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(float(c.x) * G + G * 0.5, 0.0, float(c.y) * G + G * 0.5)

func _place(c: Vector2i) -> void:
	if placed.has(c):
		return
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = tile_mesh
	mi.set_surface_override_material(0, floor_mat)
	mi.position = _cell_center(c)
	add_child(mi)
	placed[c] = mi

func _remove(c: Vector2i) -> void:
	if placed.has(c):
		placed[c].queue_free()
		placed.erase(c)

func _toggle(c: Vector2i) -> void:
	if placed.has(c):
		_remove(c)
	else:
		_place(c)

func _process(_d: float) -> void:
	var sp: Vector2 = get_viewport().get_mouse_position()
	var c: Vector2i = _cell_from_screen(sp)
	cursor.position = _cell_center(c) + Vector3(0.0, 0.09, 0.0)

func _pan(rel: Vector2) -> void:
	var b: Basis = cam.global_transform.basis
	var right: Vector3 = b.x
	right.y = 0.0
	right = right.normalized()
	var fwd: Vector3 = -b.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var s: float = cam_dist * 0.0018
	target += (-right * rel.x + fwd * rel.y) * s
	_update_cam()

func _update_cam() -> void:
	var b: Basis = Basis.from_euler(Vector3(cam_pitch, cam_yaw, 0.0))
	cam.position = target + b * Vector3(0.0, 0.0, cam_dist)
	cam.look_at(target, Vector3.UP)

func _zoom(amount: float) -> void:
	cam_dist = clampf(cam_dist + amount, 7.0, 90.0)
	_update_cam()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_pos = e.position
				press_time = Time.get_ticks_msec()
				dragging = false
			else:
				if not dragging and Time.get_ticks_msec() - press_time < 350:
					_toggle(_cell_from_screen(e.position))
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-2.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(2.5)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if e.position.distance_to(press_pos) > 8.0:
			dragging = true
		if dragging:
			_pan(e.relative)
	elif e is InputEventScreenTouch:
		if e.pressed:
			touch_points[e.index] = e.position
			if touch_points.size() == 1:
				press_pos = e.position
				press_time = Time.get_ticks_msec()
				dragging = false
		else:
			if touch_points.has(e.index):
				touch_points.erase(e.index)
			if touch_points.size() < 2:
				last_pinch = 0.0
			if touch_points.size() == 0 and not dragging and Time.get_ticks_msec() - press_time < 350:
				_toggle(_cell_from_screen(e.position))
	elif e is InputEventScreenDrag:
		touch_points[e.index] = e.position
		if touch_points.size() >= 2:
			var pts: Array = touch_points.values()
			var d: float = pts[0].distance_to(pts[1])
			if last_pinch > 0.0:
				_zoom((last_pinch - d) * 0.06)
			last_pinch = d
		else:
			if e.position.distance_to(press_pos) > 8.0:
				dragging = true
			if dragging:
				_pan(e.relative)
