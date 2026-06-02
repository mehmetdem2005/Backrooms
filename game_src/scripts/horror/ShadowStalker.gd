extends CharacterBody3D
class_name ShadowStalker

signal caught_player
signal ai_state_changed(state_name: String)
signal scare_pulse(world_position: Vector3, strength: float)
signal near_scare(world_position: Vector3)
signal creature_step(world_position: Vector3, intensity: float)

@export var stalk_speed: float = 2.95
@export var investigate_speed: float = 3.2
@export var chase_speed: float = 5.4
@export var catch_distance: float = 1.15
@export var repath_interval: float = 0.28
@export var hearing_multiplier: float = 1.5
@export var vision_cells: int = 16

var level_builder
var player

var _path: Array[Vector3i] = []
var _path_index: int = 0
var _repath_timer: float = 0.0
var _mesh_root: Node3D
var _material: StandardMaterial3D
var _model: Node3D
var _anim: AnimationPlayer
var _current_anim: String = ""
const MONSTER_MODEL: PackedScene = preload("res://assets/monster/monster_rigged.glb")
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pulse_time: float = 0.0
var _caught: bool = false
var _grabbing: bool = false
var _grab_anim_t: float = 0.0
var _arm_nodes: Array[MeshInstance3D] = []
var _awareness: float = 0.0
var _aggression: float = 0.0          # zamanla ve gördükçe artar → "sürekli kovalar"
var _lock: float = 0.0                # Karma kilit sayacı (çok ses/uzun farkındalıkta dolar)
var _rage_timer: float = 0.0          # kilit dolunca kısa süre AMANSIZ kovalama
var _state_timer: float = 0.0
var _lost_timer: float = 0.0
var _current_state: String = "STALK"
var _target_cell: Vector3i = Vector3i.ZERO
var _last_known_player_cell: Vector3i = Vector3i.ZERO
var _last_player_noise: float = 0.0
var _ambush_cooldown: float = 5.0
var _reposition_cooldown: float = 7.0
var _near_scare_cooldown: float = 0.0
var _step_phase: float = 0.0
var _current_speed: float = 0.0

func _ready() -> void:
    _rng.randomize()
    # Rampalarda (kat geçişi) düzgün iniş için zemin yapışması.
    up_direction = Vector3.UP
    floor_max_angle = deg_to_rad(55.0)
    floor_snap_length = 0.8
    _build_visual()
    _set_state("STALK")

func _physics_process(delta: float) -> void:
    if player == null or level_builder == null:
        return
    if _caught:
        if _grabbing:
            _animate_grab(delta)
        return
    _pulse_time += delta
    _state_timer += delta
    _ambush_cooldown = max(0.0, _ambush_cooldown - delta)
    _reposition_cooldown = max(0.0, _reposition_cooldown - delta)
    _repath_timer = max(0.0, _repath_timer - delta)
    _near_scare_cooldown = max(0.0, _near_scare_cooldown - delta)
    # saldırganlık zamanla artar (oyun ilerledikçe daha amansız avlar)
    _aggression = clamp(_aggression + delta * 0.010, 0.0, 1.0)

    _update_perception(delta)
    _update_state_logic(delta)
    _follow_path(delta)
    _update_visual(delta)
    _update_steps(delta)

    var dist: float = global_position.distance_to(player.global_position)
    if dist <= catch_distance:
        _caught = true
        caught_player.emit()
    elif dist <= 3.0 and _current_state == "CHASE" and _near_scare_cooldown <= 0.0:
        # ölümcül olmayan irkilme/jumpscare hamlesi
        _near_scare_cooldown = _rng.randf_range(6.0, 10.0)
        near_scare.emit(global_position + Vector3(0.0, 1.2, 0.0))

func get_state_name() -> String:
    return _current_state

func get_awareness() -> float:
    return clamp(_awareness, 0.0, 1.0)

func get_aggression() -> float:
    return clamp(_aggression, 0.0, 1.0)

func get_current_speed() -> float:
    return _current_speed

func get_player_noise_heard() -> float:
    return _last_player_noise

func _build_visual() -> void:
    # Karanlık et materyali (riglenmiş modele uygulanır). Fenerde koyu silüet, korku hissi.
    _material = StandardMaterial3D.new()
    _material.albedo_color = Color(0.045, 0.040, 0.034, 1.0)
    _material.roughness = 1.0
    _material.metallic = 0.0
    _material.emission_enabled = true
    _material.emission = Color(0.10, 0.03, 0.018, 1.0)
    _material.emission_energy_multiplier = 0.5

    var collision_shape: CapsuleShape3D = CapsuleShape3D.new()
    collision_shape.radius = 0.35
    collision_shape.height = 2.0
    var collision: CollisionShape3D = CollisionShape3D.new()
    collision.name = "StalkerCollision"
    collision.shape = collision_shape
    collision.position = Vector3(0.0, 1.0, 0.0)
    add_child(collision)

    _mesh_root = Node3D.new()
    _mesh_root.name = "StalkerVisualRoot"
    add_child(_mesh_root)

    # TripoSR ile üretilip Blender (bpy) ile riglenmiş DEV canavar (idle/walk/attack).
    _model = MONSTER_MODEL.instantiate() as Node3D
    _model.scale = Vector3(1.6, 1.6, 1.6)            # dev boy (~2.9m)
    # Yön her karede oyuncuya doğru ayarlanır (_update_visual). Başlangıç 0.
    _mesh_root.add_child(_model)

    _anim = _model.get_node_or_null("AnimationPlayer") as AnimationPlayer
    var mi: MeshInstance3D = _find_mesh(_model)
    if mi != null:
        mi.material_override = _material
    if _anim != null:
        # Lokomosyon animasyonları DÖNGÜ olmalı (yoksa bir kez oynayıp donar = "dümdüz").
        for loop_name: String in ["idle", "walk"]:
            if _anim.has_animation(loop_name):
                _anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
        _anim.play("idle")
        _current_anim = "idle"

func _find_mesh(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child: Node in node.get_children():
        var found: MeshInstance3D = _find_mesh(child)
        if found != null:
            return found
    return null

func _play_loco(anim_name: String) -> void:
    if _anim == null or _current_anim == anim_name:
        return
    _current_anim = anim_name
    _anim.play(anim_name, 0.25)

func begin_grab(target: Node3D) -> void:
    # Canavar yakaladı: öldürmek yerine kollarını kaldırıp oyuncuyu tutar, yüzünü ona döner.
    _grabbing = true
    _grab_anim_t = 0.0
    _caught = true
    velocity = Vector3.ZERO
    if target != null:
        var flat_point: Vector3 = Vector3(target.global_position.x, global_position.y, target.global_position.z)
        if global_position.distance_to(flat_point) > 0.1:
            look_at(flat_point, Vector3.UP)
    # Saldırı/yakalama animasyonu (tek sefer, son pozda kalır).
    if _anim != null:
        _current_anim = "attack"
        _anim.play("attack")
        _anim.speed_scale = 1.0

func _animate_grab(delta: float) -> void:
    _grab_anim_t = min(_grab_anim_t + delta, 1.0)
    # Animasyon AnimationPlayer'da (attack) oynuyor; burada hafif bir nefes/titreme.
    if _mesh_root != null:
        var st: float = Time.get_ticks_msec() * 0.001
        _mesh_root.scale = Vector3(1.0, 1.0 + sin(st * 9.0) * 0.02, 1.0)

func _update_perception(delta: float) -> void:
    var self_cell: Vector3i = level_builder.world_to_grid(global_position)
    var player_cell: Vector3i = level_builder.world_to_grid(player.global_position)
    var distance_to_player: float = global_position.distance_to(player.global_position)

    var visibility: float = 0.5
    if player.has_method("get_visibility"):
        visibility = player.get_visibility()

    var can_see: bool = false
    var line_of_sight: bool = level_builder.has_grid_line_of_sight(self_cell, player_cell, vision_cells)
    if line_of_sight:
        var to_player: Vector3 = player.global_position - global_position
        to_player.y = 0.0
        var forward: Vector3 = -global_transform.basis.z
        forward.y = 0.0
        if to_player.length() > 0.01:
            if forward.length() < 0.01:
                forward = to_player.normalized()
            var facing_dot: float = forward.normalized().dot(to_player.normalized())
            # görüş, oyuncunun görünürlüğüne ve mesafeye bağlı
            var sight_reach: float = 9.0 + visibility * 30.0
            if (facing_dot > 0.1 or distance_to_player < 5.5) and distance_to_player < sight_reach:
                can_see = visibility > 0.05

    var player_noise: float = player.get_noise_level()
    _last_player_noise = player_noise
    var hearing_range: float = 8.0 + player_noise * 36.0 * hearing_multiplier
    var heard: bool = player_noise > 0.08 and distance_to_player < hearing_range

    if can_see:
        _last_known_player_cell = player_cell
        var gain: float = 0.7 + max(0.0, 18.0 - distance_to_player) * 0.06
        _awareness = min(1.0, _awareness + delta * gain * (0.7 + visibility))
        _aggression = min(1.0, _aggression + delta * 0.10)
        _lost_timer = 0.0
    elif heard:
        _last_known_player_cell = player_cell
        _awareness = min(1.0, _awareness + delta * (0.28 + player_noise * 0.6))
        _lost_timer = max(0.0, _lost_timer - delta * 0.35)
    else:
        _lost_timer += delta
        # oyuncu iyi saklanıyorsa (görünürlük düşük) farkındalık daha hızlı düşer → şaşırtılabilir
        var decay: float = 0.04 + (1.0 - visibility) * 0.07
        if _current_state == "CHASE":
            decay = 0.02 + (1.0 - visibility) * 0.05
        _awareness = max(0.0, _awareness - delta * decay)
    # Durum kararı tek yerde: _update_state_logic (Karma)

func _predicted_player_cell() -> Vector3i:
    # lead-pursuit: oyuncunun gittiği yöne bir miktar önden hedefle
    var player_cell: Vector3i = level_builder.world_to_grid(player.global_position)
    var pv: Vector3 = Vector3.ZERO
    if "velocity" in player:
        pv = player.velocity
    pv.y = 0.0
    if pv.length() < 0.5:
        return player_cell
    var lead_world: Vector3 = player.global_position + pv.normalized() * (2.0 + _aggression * 3.0)
    return level_builder.world_to_grid(lead_world)

func _update_state_logic(delta: float) -> void:
    # KARMA: sesle/görüşle avlar, sessiz+görünmezsen seni KAYBEDER; ama çok ses çıkarır
    # veya uzun süre tam fark edilirsen KİLİTLENİR ve kısa süre AMANSIZ kovalar.
    var pcell: Vector3i = level_builder.world_to_grid(player.global_position)
    var loud: bool = _last_player_noise > 0.6
    if loud or _awareness >= 0.99:
        _lock = min(1.0, _lock + delta * (0.55 if loud else 0.30))
    else:
        _lock = max(0.0, _lock - delta * 0.12)
    if _lock >= 1.0 and _rage_timer <= 0.0:
        _rage_timer = 6.0
        _lock = 0.0
    _rage_timer = max(0.0, _rage_timer - delta)

    if _rage_timer > 0.0:
        # AMANSIZ: tam konuma kilitli
        _set_state("CHASE")
        _last_known_player_cell = pcell
        if _repath_timer <= 0.0 or _path.is_empty():
            _repath_timer = repath_interval
            _request_path_to(pcell)
        return

    if _awareness > 0.30:
        _set_state("CHASE")
        if _repath_timer <= 0.0 or _path.is_empty():
            _repath_timer = repath_interval
            _request_path_to(_predicted_player_cell())
    elif _awareness > 0.10:
        if _current_state != "INVESTIGATE":
            _set_state("INVESTIGATE")
            _request_path_to(_last_known_player_cell)
        elif _path.is_empty() or _arrived_to_cell(_last_known_player_cell):
            _set_state("SEARCH")
    else:
        # KAYIP: son bilinen çevresinde ara; uzun süre bulamazsa başıboş dolan (seni kaybetti)
        if _lost_timer > 8.0:
            if _current_state != "STALK" or _path.is_empty() or _state_timer > 2.5:
                _set_state("STALK")
                _request_path_to(level_builder.get_random_open_cell_near(level_builder.world_to_grid(global_position), 4, 14, _rng))
                _state_timer = 0.0
        else:
            if _current_state != "SEARCH" or _path.is_empty() or _state_timer > 1.5:
                _set_state("SEARCH")
                _request_path_to(level_builder.get_random_open_cell_near(_last_known_player_cell, 2, 8, _rng))
                _state_timer = 0.0

func _request_path_to(goal: Vector3i) -> void:
    if level_builder == null:
        return
    var start: Vector3i = level_builder.world_to_grid(global_position)
    _path = level_builder.get_grid_path(start, goal, 4000)
    _path_index = 0

func _follow_path(delta: float) -> void:
    if _path.is_empty() or _path_index >= _path.size():
        velocity = velocity.move_toward(Vector3.ZERO, 7.0 * delta)
        move_and_slide()
        _current_speed = Vector2(velocity.x, velocity.z).length()
        return

    # YOL DÜZLEŞTİRME (string-pulling): aynı kattaki, görüş hattı olan EN UZAK ara noktaya
    # yönel → ızgara zikzakı yerine açık alandan/köşelerden doğal, düz hareket.
    var cur_cell: Vector3i = level_builder.world_to_grid(global_position)
    var look: int = _path_index
    while look + 1 < _path.size() and _path[look + 1].y == cur_cell.y and level_builder.has_grid_line_of_sight(cur_cell, _path[look + 1], 18):
        look += 1
    _path_index = look

    var target_position: Vector3 = level_builder.grid_to_world(_path[_path_index], 0.0)
    var flat_to_target: Vector3 = target_position - global_position
    flat_to_target.y = 0.0
    if flat_to_target.length() < 0.5:
        _path_index += 1
        if _path_index >= _path.size():
            velocity = velocity.move_toward(Vector3.ZERO, 7.0 * delta)
            move_and_slide()
            _current_speed = Vector2(velocity.x, velocity.z).length()
            return
        target_position = level_builder.grid_to_world(_path[_path_index], 0.0)
        flat_to_target = target_position - global_position
        flat_to_target.y = 0.0

    # Hız duruma bağlı: kovalama hızlı, araştırma orta, başıboş yavaş. Suda yavaşlar.
    var spd: float = chase_speed
    if _current_state == "INVESTIGATE" or _current_state == "SEARCH":
        spd = investigate_speed
    elif _current_state == "STALK":
        spd = stalk_speed
    if level_builder.has_method("is_in_water") and level_builder.is_in_water(global_position):
        spd *= 0.62
    var desired: Vector3 = flat_to_target.normalized() * spd
    velocity.x = move_toward(velocity.x, desired.x, 12.0 * delta)
    velocity.z = move_toward(velocity.z, desired.z, 12.0 * delta)
    velocity.y = -0.2
    move_and_slide()
    _current_speed = Vector2(velocity.x, velocity.z).length()
    # Yön: model _update_visual'da daima oyuncuya bakar.

func _update_steps(delta: float) -> void:
    if _current_speed < 0.6:
        return
    _step_phase += delta * _current_speed * 0.85
    if _step_phase >= 1.0:
        _step_phase -= 1.0
        var intensity: float = clamp(_current_speed / chase_speed, 0.3, 1.0)
        creature_step.emit(global_position, intensity)

func _update_visual(delta: float) -> void:
    var distance: float = 99.0
    if player != null:
        distance = global_position.distance_to(player.global_position)
    var fear: float = clamp(1.0 - distance / 24.0, 0.0, 1.0)
    if _current_state == "CHASE":
        fear = max(fear, 0.82)
    if _material != null:
        _material.emission_energy_multiplier = 0.45 + fear * 1.6 + sin(_pulse_time * 13.0) * 0.12
    # Yön: kovalarken oyuncuya bakar (ürkütücü); ararken hareket yönüne bakar (seni kaybetti).
    if _model != null and player != null:
        var face_dir: Vector3
        if _current_state == "CHASE" or _rage_timer > 0.0:
            face_dir = player.global_position - global_position
        else:
            face_dir = Vector3(velocity.x, 0.0, velocity.z)
        face_dir.y = 0.0
        if face_dir.length() > 0.1:
            var target_yaw: float = atan2(face_dir.x, face_dir.z)
            _model.rotation.y = lerp_angle(_model.rotation.y, target_yaw, clamp(delta * 9.0, 0.0, 1.0))
    # Lokomosyon animasyonu: hareket ederken yürü, dururken idle. Hız arttıkça hızlan (kovalama).
    if _anim != null and not _grabbing:
        if _current_speed > 0.4:
            _play_loco("walk")
            _anim.speed_scale = clamp(_current_speed / 2.6, 0.7, 2.0)
        else:
            _play_loco("idle")
            _anim.speed_scale = 1.0

func _set_state(new_state: String) -> void:
    if _current_state == new_state and _state_timer > 0.0:
        return
    _current_state = new_state
    _state_timer = 0.0
    ai_state_changed.emit(_state_to_turkish(new_state))

func _state_to_turkish(state_name: String) -> String:
    match state_name:
        "STALK":
            return "Takipte"
        "INVESTIGATE":
            return "Sesi duydu"
        "SEARCH":
            return "Arıyor"
        "CHASE":
            return "Kovalıyor"
        "AMBUSH":
            return "Pusu kuruyor"
    return state_name

func _arrived_to_cell(cell: Vector3i) -> bool:
    var current: Vector3i = level_builder.world_to_grid(global_position)
    return current == cell or _cell_distance(current, cell) <= 1.5

func _cell_distance(a: Vector3i, b: Vector3i) -> float:
    var dx: int = a.x - b.x
    var dz: int = a.z - b.z
    var df: int = (a.y - b.y) * 6
    return sqrt(float(dx * dx + dz * dz + df * df))

func _phase_reposition_near_player(player_cell: Vector3i) -> void:
    var candidate: Vector3i = level_builder.get_ambush_cell_around(player_cell, _rng)
    if candidate == player_cell:
        return
    global_position = level_builder.grid_to_world(candidate, 0.2)
    _path.clear()
    _reposition_cooldown = _rng.randf_range(10.0, 15.0)
    scare_pulse.emit(global_position + Vector3(0.0, 1.1, 0.0), 0.90)
