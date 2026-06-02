extends CharacterBody3D
class_name PremiumFpsPlayer

signal footstep(world_position: Vector3, intensity: float)
signal flashlight_toggled(enabled: bool)
signal flashlight_clicked(world_position: Vector3)

@export var walk_speed: float = 3.45
@export var run_speed: float = 5.65
@export var crouch_speed: float = 1.55
@export var acceleration: float = 18.0
@export var look_sensitivity: float = 0.0024
@export var touch_look_sensitivity: float = 0.0040
@export var flashlight_drain_per_second: float = 0.010
@export var flashlight_recharge_per_second: float = 0.014
@export var stamina_drain_per_second: float = 0.18
@export var stamina_recover_per_second: float = 0.12

var mobile_controls
var hud
var level_builder
var lock_controls: bool = false
var flashlight_energy: float = 1.0
var stamina: float = 1.0
var noise_level: float = 0.0
var is_running: bool = false
var is_moving: bool = false
var is_crouching: bool = false
var stress_level: float = 0.0
var local_light: float = 0.0      # GameRoot tarafından beslenir (0=karanlık,1=floresan altında)

var _head: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _fill_light: OmniLight3D
var _vision_light: OmniLight3D       # daima açık, çok sönük -> kapkaranlıkta bile yakını seçebilme
var _flashlight_model: Node3D        # elde tutulan fener modeli (viewmodel)
var _lens_material: StandardMaterial3D
var _fl_sway: Vector2 = Vector2.ZERO
var _pitch: float = 0.0
var _flashlight_enabled: bool = true
var _bob_time: float = 0.0
var _base_camera_y: float = 0.84
var _crouch_offset: float = 0.0
var _mouse_look_delta: Vector2 = Vector2.ZERO
var _breath_phase: float = 0.0
var _footstep_phase: float = 0.0
var _last_footstep_mark: int = 0
var _last_horizontal_speed: float = 0.0
var _trauma: float = 0.0           # kamera sarsıntısı (jumpscare/yakınlık)
var _grab_active: bool = false
var _grab_time: float = 0.0
var _grab_target: Vector3 = Vector3.ZERO
var _shake_seed: float = 0.0

func _ready() -> void:
    _shake_seed = randf() * 100.0
    _build_body()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if _grab_active:
        _update_grab(delta)
        return
    if lock_controls:
        velocity = velocity.move_toward(Vector3.ZERO, acceleration * delta)
        move_and_slide()
        noise_level = move_toward(noise_level, 0.0, delta * 4.0)
        _update_camera_motion(delta)
        return
    _update_look(delta)
    _update_flashlight(delta)
    _update_movement(delta)
    _update_camera_motion(delta)
    _update_noise(delta)

func _unhandled_input(event: InputEvent) -> void:
    if lock_controls:
        return
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event
        if mouse_button.pressed:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        var motion: InputEventMouseMotion = event
        _mouse_look_delta += motion.relative
    if event is InputEventKey:
        var key_event: InputEventKey = event
        if key_event.pressed and not key_event.echo:
            if key_event.keycode == KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            if key_event.keycode == KEY_F:
                _toggle_flashlight()
            if key_event.keycode == KEY_CTRL or key_event.keycode == KEY_C:
                is_crouching = not is_crouching

func get_camera() -> Camera3D:
    return _camera

func is_flashlight_on() -> bool:
    return _flashlight_enabled and flashlight_energy > 0.01

func get_noise_level() -> float:
    return clamp(noise_level, 0.0, 1.0)

func get_stress_level() -> float:
    return clamp(stress_level, 0.0, 1.0)

func set_stress_level(value: float) -> void:
    stress_level = clamp(value, 0.0, 1.0)

func set_local_light(value: float) -> void:
    local_light = clamp(value, 0.0, 1.0)

# Yaratık için: oyuncu ne kadar görünür? Fener açık + hareket + ışık altında = çok görünür.
# Çömelmiş + durağan + karanlık = neredeyse görünmez (oyuncu canavarı şaşırtabilir).
func get_visibility() -> float:
    var vis: float = 0.16
    vis += local_light * 0.40
    if is_flashlight_on():
        vis += 0.55
    if is_moving:
        vis += 0.22
    if is_running:
        vis += 0.20
    if is_crouching:
        vis *= 0.45
    if is_crouching and not is_moving and not is_flashlight_on():
        vis = min(vis, 0.06)
    return clamp(vis, 0.0, 1.0)

# Karanlık seviyesi (post-process için): fener açıksa ve/veya ışık altındaysa az.
func get_darkness() -> float:
    var light: float = local_light
    if is_flashlight_on():
        light = max(light, 0.85)
    return clamp(1.0 - light, 0.0, 1.0)

func add_trauma(amount: float) -> void:
    _trauma = clamp(_trauma + amount, 0.0, 1.0)

func face_position(world_position: Vector3) -> void:
    # Jumpscare anında bakışı tehdide kilitler
    var flat: Vector3 = world_position - global_position
    flat.y = 0.0
    if flat.length() > 0.05:
        look_at(global_position - flat, Vector3.UP)

func start_grab(target_head_world: Vector3) -> void:
    # Canavar seni kollarıyla havaya kaldırırken kameranı yukarı kaldırıp yüzüne kilitler.
    _grab_active = true
    _grab_time = 0.0
    _grab_target = target_head_world
    lock_controls = true

func update_grab_target(world_position: Vector3) -> void:
    _grab_target = world_position

func _update_grab(delta: float) -> void:
    _grab_time += delta
    velocity = velocity.move_toward(Vector3.ZERO, 30.0 * delta)
    move_and_slide()
    # Kaldırma: kamera tabandan yukarı yükselir (ayağın yerden kesilir gibi)
    var lift_t: float = clamp(_grab_time / 1.5, 0.0, 1.0)
    var eased: float = lift_t * lift_t * (3.0 - 2.0 * lift_t)
    var lifted_y: float = lerp(_base_camera_y, _base_camera_y + 0.98, eased)
    # Artan titreme (çaresizlik / canavarın sarsması)
    var tremble: float = 0.012 + eased * 0.05 + _trauma * 0.06
    var st: float = Time.get_ticks_msec() * 0.001
    var tx: float = sin(st * 38.0 + _shake_seed) * tremble
    var ty: float = sin(st * 44.0 + _shake_seed * 1.7) * tremble
    _head.position = Vector3(tx, lifted_y + ty, 0.0)
    _head.rotation = Vector3.ZERO
    # Yüze kilitlen: kamerayı doğrudan canavarın başına çevir
    var cam_position: Vector3 = _camera.global_position
    var look_point: Vector3 = _grab_target + Vector3(tx * 0.5, ty * 0.5, 0.0)
    if cam_position.distance_to(look_point) > 0.1:
        _camera.look_at(look_point, Vector3.UP)

func _toggle_flashlight() -> void:
    if flashlight_energy <= 0.02 and not _flashlight_enabled:
        return
    _flashlight_enabled = not _flashlight_enabled
    flashlight_toggled.emit(_flashlight_enabled)
    flashlight_clicked.emit(global_position)
    # Fener aç/kapa küçük bir ses çıkarır (plan: 0.15) — canavar hızlı tıklamayı duyar
    noise_level = max(noise_level, 0.15)

func _build_body() -> void:
    # Rampalarda (kat geçişi) güvenli iniş/çıkış için zemin yapışması ve eğim toleransı.
    up_direction = Vector3.UP
    floor_max_angle = deg_to_rad(52.0)
    floor_snap_length = 0.8
    floor_stop_on_slope = false
    floor_constant_speed = true
    var capsule_shape: CapsuleShape3D = CapsuleShape3D.new()
    capsule_shape.radius = 0.33
    capsule_shape.height = 1.52
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "PlayerCollision"
    collision.shape = capsule_shape
    collision.position = Vector3(0.0, 0.76, 0.0)
    add_child(collision)

    _head = Node3D.new()
    _head.name = "Head"
    _head.position = Vector3(0.0, _base_camera_y, 0.0)
    add_child(_head)

    _camera = Camera3D.new()
    _camera.name = "Camera3D"
    _camera.fov = 78.0
    _camera.near = 0.035
    _camera.far = 90.0
    _head.add_child(_camera)
    _camera.current = true

    # Elde tutulan fener modeli (viewmodel) — ışık bunun ucundan çıkar.
    _build_flashlight_model()

    # AAA huzme: yumuşak kenar (cookie + açı atten.), uzun menzilde yumuşaya yumuşaya azalan parlaklık.
    _flashlight = SpotLight3D.new()
    _flashlight.name = "PremiumFlashlight"
    _flashlight.light_color = Color(1.0, 0.95, 0.82, 1.0)
    _flashlight.light_energy = 6.0
    _flashlight.spot_range = 34.0
    _flashlight.spot_angle = 30.0
    _flashlight.spot_angle_attenuation = 1.8     # merkez parlak, kenar yumuşak
    _flashlight.spot_attenuation = 1.1           # mesafeyle yumuşak sönme
    _flashlight.light_specular = 0.5
    _flashlight.shadow_enabled = false
    _flashlight.light_projector = _make_flashlight_cookie()
    # Fenerin ucundan (elin önünden) yayılır
    _flashlight.position = Vector3(0.26, -0.20, -0.55)
    _camera.add_child(_flashlight)

    # Yakın dolgu (huzme açıkken hemen önü siyahlıktan kurtarır)
    _fill_light = OmniLight3D.new()
    _fill_light.name = "FlashlightFill"
    _fill_light.light_color = Color(1.0, 0.93, 0.76, 1.0)
    _fill_light.light_energy = 0.4
    _fill_light.omni_range = 3.5
    _fill_light.omni_attenuation = 2.0
    _fill_light.shadow_enabled = false
    _fill_light.position = Vector3(0.0, -0.05, -0.5)
    _camera.add_child(_fill_light)

    # KALİTELİ KARANLIK: daima açık, çok sönük görüş ışığı → fener kapalıyken bile
    # yakın yüzeyler hafifçe seçilir (kapkaranlık kare değil, göz alışmış karanlık).
    _vision_light = OmniLight3D.new()
    _vision_light.name = "VisionAdapt"
    _vision_light.light_color = Color(0.62, 0.66, 0.78, 1.0)
    _vision_light.light_energy = 0.16
    _vision_light.omni_range = 6.5
    _vision_light.omni_attenuation = 2.4
    _vision_light.shadow_enabled = false
    _vision_light.position = Vector3(0.0, 0.0, 0.0)
    _camera.add_child(_vision_light)

func _build_flashlight_model() -> void:
    _flashlight_model = Node3D.new()
    _flashlight_model.name = "FlashlightViewmodel"
    _flashlight_model.position = Vector3(0.26, -0.22, -0.42)
    _flashlight_model.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(-4.0), 0.0)
    _camera.add_child(_flashlight_model)

    var body_mat: StandardMaterial3D = StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.07, 0.07, 0.08, 1.0)
    body_mat.metallic = 0.85
    body_mat.roughness = 0.35

    var body: MeshInstance3D = MeshInstance3D.new()
    var bm: CylinderMesh = CylinderMesh.new()
    bm.top_radius = 0.022; bm.bottom_radius = 0.026; bm.height = 0.20; bm.radial_segments = 16
    body.mesh = bm; body.material_override = body_mat
    body.rotation.x = deg_to_rad(90.0)        # silindir ekseni Y -> Z (öne uzanır)
    _flashlight_model.add_child(body)

    var head: MeshInstance3D = MeshInstance3D.new()
    var hm: CylinderMesh = CylinderMesh.new()
    hm.top_radius = 0.046; hm.bottom_radius = 0.028; hm.height = 0.06; hm.radial_segments = 16
    head.mesh = hm; head.material_override = body_mat
    head.rotation.x = deg_to_rad(90.0)
    head.position = Vector3(0.0, 0.0, -0.13)
    _flashlight_model.add_child(head)

    _lens_material = StandardMaterial3D.new()
    _lens_material.albedo_color = Color(1.0, 0.96, 0.80, 1.0)
    _lens_material.emission_enabled = true
    _lens_material.emission = Color(1.0, 0.95, 0.78, 1.0)
    _lens_material.emission_energy_multiplier = 6.0
    var lens: MeshInstance3D = MeshInstance3D.new()
    var lm: CylinderMesh = CylinderMesh.new()
    lm.top_radius = 0.042; lm.bottom_radius = 0.042; lm.height = 0.012; lm.radial_segments = 16
    lens.mesh = lm; lens.material_override = _lens_material
    lens.rotation.x = deg_to_rad(90.0)
    lens.position = Vector3(0.0, 0.0, -0.165)
    _flashlight_model.add_child(lens)

func _make_flashlight_cookie() -> Texture2D:
    var size: int = 256
    var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var c: float = float(size) * 0.5
    for y: int in range(size):
        for x: int in range(size):
            var dx: float = (float(x) - c) / c
            var dy: float = (float(y) - c) / c
            var r: float = sqrt(dx * dx + dy * dy)
            # yumuşak kenar: merkez parlak, kenara doğru pürüzsüz söner
            var brightness: float = smoothstep(1.0, 0.12, r)
            # hafif sıcak hotspot
            brightness += smoothstep(0.30, 0.0, r) * 0.35
            # gerçekçi küçük kusurlar / hafif huzme dokusu
            var angle: float = atan2(dy, dx)
            brightness *= 1.0 - 0.06 * abs(sin(angle * 5.0)) - 0.04 * abs(sin(angle * 13.0 + r * 8.0))
            brightness = clamp(brightness, 0.0, 1.0)
            image.set_pixel(x, y, Color(brightness, brightness * 0.97, brightness * 0.9, 1.0))
    return ImageTexture.create_from_image(image)

func _update_look(_delta: float) -> void:
    var look_delta: Vector2 = Vector2.ZERO
    if mobile_controls != null:
        look_delta += mobile_controls.consume_look_delta() * touch_look_sensitivity
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        look_delta += _mouse_look_delta * look_sensitivity
        _mouse_look_delta = Vector2.ZERO

    rotate_y(-look_delta.x)
    _pitch = clamp(_pitch - look_delta.y, deg_to_rad(-84.0), deg_to_rad(84.0))
    _head.rotation.x = _pitch

func _update_movement(delta: float) -> void:
    var input_vector: Vector2 = _get_desktop_move_vector()
    if mobile_controls != null:
        input_vector += mobile_controls.move_vector
    if input_vector.length() > 1.0:
        input_vector = input_vector.normalized()

    var forward: Vector3 = -global_transform.basis.z
    var right: Vector3 = global_transform.basis.x
    forward.y = 0.0
    right.y = 0.0
    forward = forward.normalized()
    right = right.normalized()

    if mobile_controls != null:
        is_crouching = mobile_controls.crouch_pressed

    var wants_run: bool = Input.is_key_pressed(KEY_SHIFT)
    if mobile_controls != null:
        wants_run = wants_run or mobile_controls.run_pressed
    is_moving = input_vector.length() > 0.05
    var can_run: bool = wants_run and is_moving and stamina > 0.04 and not is_crouching
    is_running = can_run

    var target_speed: float = walk_speed
    if is_crouching:
        target_speed = crouch_speed
    elif can_run:
        target_speed = run_speed
        stamina = max(0.0, stamina - stamina_drain_per_second * delta)
    else:
        stamina = min(1.0, stamina + stamina_recover_per_second * delta)

    # HAVUZ: suda hareket yavaşlar (karşıya geçerek kaçma — canavar da yavaşlar)
    if level_builder != null and level_builder.has_method("is_in_water") and level_builder.is_in_water(global_position):
        target_speed *= 0.55

    var desired: Vector3 = (right * input_vector.x + forward * input_vector.y) * target_speed
    velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
    velocity.y = -0.2
    move_and_slide()

func _get_desktop_move_vector() -> Vector2:
    var result: Vector2 = Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        result.y += 1.0
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        result.y -= 1.0
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        result.x += 1.0
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        result.x -= 1.0
    if result.length() > 1.0:
        result = result.normalized()
    return result

func _update_flashlight(delta: float) -> void:
    if mobile_controls != null and mobile_controls.consume_flashlight_toggle():
        _toggle_flashlight()

    if _flashlight_enabled:
        flashlight_energy = max(0.0, flashlight_energy - flashlight_drain_per_second * delta)
    else:
        flashlight_energy = min(1.0, flashlight_energy + flashlight_recharge_per_second * delta)

    if flashlight_energy <= 0.005:
        if _flashlight_enabled:
            _flashlight_enabled = false
            flashlight_toggled.emit(false)

    _flashlight.visible = _flashlight_enabled
    _fill_light.visible = _flashlight_enabled
    var lens_glow: float = 0.0
    if _flashlight_enabled:
        var stress_flicker: float = 1.0 - stress_level * 0.12 + sin(Time.get_ticks_msec() * 0.021) * stress_level * 0.10
        var battery: float = lerp(0.40, 1.0, flashlight_energy)
        # düşük pilde rastgele kırpışma
        if flashlight_energy < 0.2 and sin(Time.get_ticks_msec() * 0.05) > 0.4:
            battery *= 0.4
        _flashlight.light_energy = 6.0 * battery * stress_flicker
        _flashlight.spot_range = lerp(18.0, 36.0, flashlight_energy)   # pil azaldıkça menzil kısalır
        _fill_light.light_energy = 0.4 * battery
        lens_glow = 6.5 * battery * stress_flicker
    # Lens parıltısı (fener kapalıyken sönük)
    if _lens_material != null:
        _lens_material.emission_energy_multiplier = move_toward(_lens_material.emission_energy_multiplier, lens_glow, delta * 30.0)
    # Buton etiketi: kapalıyken "AÇ", açıkken "KAPA"
    if mobile_controls != null:
        mobile_controls.set_flashlight_on(_flashlight_enabled)

func _update_camera_motion(delta: float) -> void:
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    _last_horizontal_speed = horizontal_speed
    _breath_phase += delta * (0.85 + stress_level * 1.5)
    if horizontal_speed > 0.2:
        _bob_time += delta * horizontal_speed * 2.05
        _footstep_phase += delta * horizontal_speed * (1.25 if is_running else 0.92)
    else:
        _bob_time = lerp(_bob_time, 0.0, delta * 4.0)
        _footstep_phase = lerp(_footstep_phase, 0.0, delta * 2.0)

    var step_mark: int = int(_footstep_phase * 2.0)
    if horizontal_speed > 1.1 and step_mark != _last_footstep_mark:
        _last_footstep_mark = step_mark
        var intensity: float = clamp(horizontal_speed / run_speed, 0.25, 1.0)
        if is_crouching:
            intensity *= 0.4
        footstep.emit(global_position, intensity)

    # çömelme yüksekliği
    var target_crouch: float = -0.42 if is_crouching else 0.0
    _crouch_offset = lerp(_crouch_offset, target_crouch, delta * 8.0)

    var bob_y: float = sin(_bob_time) * (0.038 + stress_level * 0.018)
    var bob_x: float = cos(_bob_time * 0.5) * (0.018 + stress_level * 0.012)
    var breath_y: float = sin(_breath_phase) * (0.010 + stress_level * 0.022)

    # travma tabanlı kamera sarsıntısı (jumpscare/yakınlık)
    _trauma = move_toward(_trauma, 0.0, delta * 1.6)
    var shake: float = _trauma * _trauma
    var st: float = Time.get_ticks_msec() * 0.001
    var shake_x: float = (sin(st * 47.0 + _shake_seed) ) * 0.06 * shake
    var shake_y: float = (sin(st * 53.0 + _shake_seed * 1.7)) * 0.06 * shake
    _head.rotation.z = sin(st * 60.0 + _shake_seed) * 0.05 * shake
    _head.position = Vector3(bob_x + shake_x, _base_camera_y + _crouch_offset + bob_y + breath_y + shake_y, 0.0)

func _update_noise(delta: float) -> void:
    # Plan değerleri: yürüme 0.25, koşma 0.75, çömelme ~0.10, durağan ~0.02
    var target_noise: float = 0.02
    if is_moving:
        target_noise = 0.25
    if is_running:
        target_noise = 0.75
    if is_crouching:
        target_noise *= 0.40
    # Suda (havuz) çıkardığın ses artar (su şıpırtısı)
    if level_builder != null and level_builder.has_method("is_in_water") and level_builder.is_in_water(global_position):
        target_noise = max(target_noise, 0.35) + (0.25 if is_moving else 0.0)
    target_noise += stress_level * 0.10
    noise_level = move_toward(noise_level, clamp(target_noise, 0.0, 1.0), delta * 2.8)
