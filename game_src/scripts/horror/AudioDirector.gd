extends Node
class_name AudioDirector

# Mevcut sesler
const HUM_LOOP: String = "res://audio/loops/backrooms_fluorescent_hum.wav"
const ROOM_TONE_LOOP: String = "res://audio/loops/deep_room_tone.wav"
const PIPE_RUMBLE_LOOP: String = "res://audio/loops/pipe_rumble.wav"
const FOOTSTEP_01: String = "res://audio/footsteps/carpet_step_01.wav"
const FOOTSTEP_02: String = "res://audio/footsteps/carpet_step_02.wav"
const FOOTSTEP_03: String = "res://audio/footsteps/carpet_step_03.wav"
const METAL_KNOCK: String = "res://audio/stingers/metal_knock.wav"
const LIGHT_POP: String = "res://audio/stingers/light_pop.wav"
const ENTITY_BREATH: String = "res://audio/stingers/entity_breath.wav"
const CHASE_STING: String = "res://audio/stingers/chase_sting.wav"
const ENTITY_GROWL: String = "res://audio/entity/entity_growl.wav"
# Yeni sesler
const SUB_DRONE: String = "res://audio/loops/sub_drone.wav"
const CHASE_LAYER: String = "res://audio/loops/chase_layer.wav"
const DARK_AMBIENCE: String = "res://audio/loops/dark_ambience.wav"
const JUMPSCARE_HIT: String = "res://audio/stingers/jumpscare_hit.wav"
const SCARE_RISER: String = "res://audio/stingers/scare_riser.wav"
const HEARTBEAT: String = "res://audio/stingers/heartbeat_strong.wav"
const MONSTER_SCREAM: String = "res://audio/entity/monster_scream.wav"
const MONSTER_BREATH: String = "res://audio/entity/monster_breath_close.wav"
const MONSTER_WHISPER: String = "res://audio/entity/monster_whisper.wav"
const MONSTER_STEP: String = "res://audio/entity/monster_step.wav"
const PLAYER_BREATH: String = "res://audio/player/player_breath.wav"
const PLAYER_PANT: String = "res://audio/player/player_pant.wav"

var player
var stalker
var level_builder
var light_manager
var hud

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hum_player: AudioStreamPlayer
var _room_player: AudioStreamPlayer
var _pipe_player: AudioStreamPlayer
var _drone_player: AudioStreamPlayer
var _chase_player: AudioStreamPlayer
var _dark_player: AudioStreamPlayer
var _breath_calm: AudioStreamPlayer
var _breath_heavy: AudioStreamPlayer
var _heartbeat_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer3D
var _step_player: AudioStreamPlayer3D
var _stinger_pool: Array[AudioStreamPlayer3D] = []
var _stinger_index: int = 0
var _event_timer: float = 3.0
var _heartbeat_timer: float = 0.0
var _last_state: String = ""
var _voice_state: String = ""
var _footstep_paths: Array[String] = [FOOTSTEP_01, FOOTSTEP_02, FOOTSTEP_03]

func _ready() -> void:
    _rng.randomize()
    _ensure_audio_buses()
    _create_2d_layers()
    _create_3d_pool()
    _create_creature_voice()

func bind_references(new_player: Node, new_stalker: Node, new_level: Node, new_light_manager: Node, new_hud: CanvasLayer) -> void:
    player = new_player
    stalker = new_stalker
    level_builder = new_level
    light_manager = new_light_manager
    hud = new_hud
    if player != null:
        _connect_safe(player, "footstep", "_on_player_footstep")
        _connect_safe(player, "flashlight_clicked", "_on_flashlight_clicked")
    if stalker != null:
        _connect_safe(stalker, "ai_state_changed", "_on_stalker_state_changed")
        _connect_safe(stalker, "scare_pulse", "_on_scare_pulse")
        _connect_safe(stalker, "near_scare", "_on_near_scare")
        _connect_safe(stalker, "creature_step", "_on_creature_step")

func _connect_safe(obj: Object, signal_name: String, method_name: String) -> void:
    var c: Callable = Callable(self, method_name)
    if obj.has_signal(signal_name) and not obj.is_connected(signal_name, c):
        obj.connect(signal_name, c)

func _process(delta: float) -> void:
    _event_timer -= delta
    _heartbeat_timer -= delta
    _update_layers(delta)
    _update_creature_voice(delta)
    if _event_timer <= 0.0:
        _event_timer = _rng.randf_range(5.0, 11.0)
        _play_random_event()

    if player != null and stalker != null:
        var danger_distance: float = player.global_position.distance_to(stalker.global_position)
        var fear: float = clamp(1.0 - danger_distance / 30.0, 0.0, 1.0)
        fear = max(fear, stalker.get_awareness() * 0.8)
        if stalker.get_state_name() == "CHASE":
            fear = max(fear, 0.85)
        if _heartbeat_timer <= 0.0 and fear > 0.34 and _heartbeat_player.stream != null:
            _heartbeat_timer = lerp(1.15, 0.42, fear)
            _heartbeat_player.volume_db = lerp(-16.0, -2.0, fear)
            _heartbeat_player.pitch_scale = lerp(0.92, 1.16, fear)
            _heartbeat_player.play()

func _ensure_audio_buses() -> void:
    _ensure_bus("Ambience", -6.0)
    _ensure_bus("HorrorSFX", -2.0)
    _ensure_bus("Creature", -1.0)
    _ensure_bus("Music", -5.0)
    _ensure_bus("Player", -3.0)

func _ensure_bus(bus_name: String, volume_db: float) -> void:
    if AudioServer.get_bus_index(bus_name) != -1:
        return
    var bus_index: int = AudioServer.get_bus_count()
    AudioServer.add_bus(bus_index)
    AudioServer.set_bus_name(bus_index, bus_name)
    AudioServer.set_bus_volume_db(bus_index, volume_db)

func _create_2d_layers() -> void:
    _hum_player = _make_loop_player("FluorescentHum", HUM_LOOP, "Ambience", -5.5)
    _room_player = _make_loop_player("DeepRoomTone", ROOM_TONE_LOOP, "Ambience", -13.0)
    _pipe_player = _make_loop_player("PipeRumble", PIPE_RUMBLE_LOOP, "Ambience", -16.0)
    _drone_player = _make_loop_player("SubDrone", SUB_DRONE, "Music", -20.0)
    _chase_player = _make_loop_player("ChaseLayer", CHASE_LAYER, "Music", -60.0)
    _dark_player = _make_loop_player("DarkAmbience", DARK_AMBIENCE, "Ambience", -60.0)
    _breath_calm = _make_loop_player("PlayerBreathCalm", PLAYER_BREATH, "Player", -16.0)
    _breath_heavy = _make_loop_player("PlayerBreathHeavy", PLAYER_PANT, "Player", -60.0)
    _heartbeat_player = AudioStreamPlayer.new()
    _heartbeat_player.name = "HeartbeatLayer"
    _heartbeat_player.stream = _load_audio(HEARTBEAT)
    _heartbeat_player.bus = "HorrorSFX"
    _heartbeat_player.volume_db = -12.0
    add_child(_heartbeat_player)

func _make_loop_player(node_name: String, path: String, bus_name: String, volume_db: float) -> AudioStreamPlayer:
    var p2d: AudioStreamPlayer = AudioStreamPlayer.new()
    p2d.name = node_name
    p2d.stream = _load_audio(path)
    p2d.bus = bus_name
    p2d.volume_db = volume_db
    add_child(p2d)
    if p2d.stream == null:
        return p2d
    _set_wav_loop(p2d.stream)
    p2d.play()
    return p2d

func _create_3d_pool() -> void:
    for index: int in range(12):
        var p3d: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
        p3d.name = "Horror3D_%02d" % index
        p3d.bus = "HorrorSFX"
        p3d.max_distance = 40.0
        p3d.unit_size = 6.0
        p3d.volume_db = -4.0
        _stinger_pool.append(p3d)
        add_child(p3d)

func _create_creature_voice() -> void:
    _voice_player = AudioStreamPlayer3D.new()
    _voice_player.name = "CreatureVoice"
    _voice_player.bus = "Creature"
    _voice_player.max_distance = 60.0
    _voice_player.unit_size = 13.0
    _voice_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    _voice_player.volume_db = -6.0
    add_child(_voice_player)

    _step_player = AudioStreamPlayer3D.new()
    _step_player.name = "CreatureSteps"
    _step_player.bus = "Creature"
    _step_player.max_distance = 56.0
    _step_player.unit_size = 12.0
    _step_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    _step_player.volume_db = -6.0
    add_child(_step_player)

func _update_layers(delta: float) -> void:
    if _hum_player == null:
        return
    _ensure_playing(_hum_player)
    _ensure_playing(_room_player)
    _ensure_playing(_pipe_player)
    _ensure_playing(_drone_player)
    _ensure_playing(_chase_player)
    _ensure_playing(_dark_player)

    var fear: float = 0.0
    var noise: float = 0.0
    var aggression: float = 0.0
    var darkness: float = 0.0
    var chasing: bool = false
    if player != null:
        noise = player.get_noise_level()
        if player.has_method("get_darkness"):
            darkness = player.get_darkness()
    if stalker != null:
        fear = stalker.get_awareness()
        aggression = stalker.get_aggression()
        chasing = stalker.get_state_name() == "CHASE"

    var proximity: float = 0.0
    if player != null and stalker != null:
        var d: float = player.global_position.distance_to(stalker.global_position)
        proximity = clamp(1.0 - d / 34.0, 0.0, 1.0)
        proximity = proximity * proximity * (3.0 - 2.0 * proximity)

    var tension: float = max(fear, aggression * 0.6, proximity * 0.85)
    _hum_player.volume_db = lerp(-6.5, -3.5, fear) + sin(Time.get_ticks_msec() * 0.003) * 0.45
    _room_player.volume_db = lerp(-15.5, -9.0, fear)
    _pipe_player.volume_db = lerp(-18.0, -12.0, noise)
    # gerilim bedeni (drone) yükselir
    _set_target_db(_drone_player, lerp(-22.0, -6.0, tension), delta, 3.0)
    # kovalama müziği sadece kovalarken
    var chase_db: float = -60.0
    if chasing:
        chase_db = lerp(-10.0, -3.0, fear)
    _set_target_db(_chase_player, chase_db, delta, 6.0)
    # karanlık ambiyansı fener kapalıyken yükselir
    _set_target_db(_dark_player, lerp(-60.0, -8.0, darkness), delta, 2.5)

    # --- Oyuncu nefesi: efora göre sakin ↔ panting ---
    if player != null and _breath_calm != null:
        _ensure_playing(_breath_calm)
        _ensure_playing(_breath_heavy)
        var running: float = 0.45 if player.is_running else 0.0
        var stamina_drain: float = (1.0 - clamp(player.stamina, 0.0, 1.0)) * 0.5
        var exertion: float = clamp(running + stamina_drain + player.get_stress_level() * 0.5, 0.0, 1.0)
        _set_target_db(_breath_calm, lerp(-13.0, -30.0, exertion), delta, 2.0)
        _set_target_db(_breath_heavy, lerp(-52.0, -5.0, exertion), delta, 3.0)
        _breath_heavy.pitch_scale = lerp(0.9, 1.22, exertion)
        _breath_calm.pitch_scale = lerp(0.95, 1.08, exertion)

func _ensure_playing(p: AudioStreamPlayer) -> void:
    if p != null and p.stream != null and not p.playing:
        p.play()

func _set_target_db(p: AudioStreamPlayer, target: float, delta: float, speed: float) -> void:
    if p == null:
        return
    p.volume_db = move_toward(p.volume_db, target, speed * 6.0 * delta)

func _update_creature_voice(delta: float) -> void:
    if stalker == null or _voice_player == null:
        return
    _voice_player.global_position = stalker.global_position + Vector3(0.0, 1.3, 0.0)
    var state: String = stalker.get_state_name()
    var dist: float = 99.0
    if player != null:
        dist = player.global_position.distance_to(stalker.global_position)

    # Duruma göre döngüsel canavar sesi seç
    var desired_path: String = ""
    if state == "CHASE":
        desired_path = MONSTER_BREATH
    elif dist < 14.0:
        desired_path = MONSTER_BREATH
    elif state == "STALK" or state == "SEARCH" or state == "AMBUSH":
        desired_path = MONSTER_WHISPER
    if desired_path != "" and desired_path != _voice_state:
        var s: AudioStream = _load_audio(desired_path)
        if s != null:
            _set_wav_loop(s)
            _voice_player.stream = s
            _voice_state = desired_path
            _voice_player.play()
    if _voice_player.stream != null and not _voice_player.playing:
        _voice_player.play()
    # Yakınlık eğrisi yumuşatıldı (smoothstep) + 3D inverse-distance sönümleme doğal artış verir.
    # Manuel kısım sadece duruma göre hafif vurgu yapar; yaklaşırken ani sıçrama olmaz.
    var proximity: float = clamp(1.0 - dist / 46.0, 0.0, 1.0)
    proximity = proximity * proximity * (3.0 - 2.0 * proximity)
    var vol: float = lerp(-20.0, 1.0, proximity)
    if state == "CHASE":
        vol += 4.0
    _voice_player.volume_db = move_toward(_voice_player.volume_db, vol, 16.0 * delta)

func _play_random_event() -> void:
    if player == null or level_builder == null:
        return
    var player_cell: Vector2i = level_builder.world_to_grid(player.global_position)
    var event_cell: Vector2i = level_builder.get_random_open_cell_near(player_cell, 4, 13, _rng)
    var event_position: Vector3 = level_builder.grid_to_world(event_cell, 1.55)
    var roll: float = _rng.randf()
    if roll < 0.34:
        _play_3d(METAL_KNOCK, event_position, -5.0, _rng.randf_range(0.84, 1.10), "HorrorSFX")
        if hud != null:
            hud.set_hint("Metal sesi yakından gelmedi. Ama cevap verdi.")
    elif roll < 0.6:
        _play_3d(LIGHT_POP, event_position, -4.0, _rng.randf_range(0.90, 1.25), "HorrorSFX")
        if light_manager != null:
            light_manager.trigger_disturbance(event_position, 2.0, 0.8)
    else:
        _play_3d(ENTITY_BREATH, event_position, -7.0, _rng.randf_range(0.74, 0.96), "Creature")
        if hud != null:
            hud.set_hint("Nefes sesi senden uzaklaşıyor gibi. Ya da yaklaşıyor.")

func _on_player_footstep(world_position: Vector3, intensity: float) -> void:
    var path_index: int = _rng.randi_range(0, _footstep_paths.size() - 1)
    _play_3d(_footstep_paths[path_index], world_position, lerp(-24.0, -13.0, intensity), _rng.randf_range(0.94, 1.06), "HorrorSFX")

func _on_creature_step(world_position: Vector3, intensity: float) -> void:
    if _step_player == null or _step_player.stream == null:
        var s: AudioStream = _load_audio(MONSTER_STEP)
        if s == null:
            return
        _step_player.stream = s
    _step_player.global_position = world_position
    _step_player.volume_db = lerp(-10.0, 0.0, clamp(intensity, 0.0, 1.0))
    _step_player.pitch_scale = _rng.randf_range(0.88, 1.02)
    _step_player.play()

func _on_flashlight_clicked(world_position: Vector3) -> void:
    _play_3d(LIGHT_POP, world_position, -16.0, _rng.randf_range(1.3, 1.6), "HorrorSFX")

func _on_stalker_state_changed(state_name: String) -> void:
    if hud != null:
        hud.set_ai_state(state_name)
    if state_name == "Kovalıyor" and _last_state != state_name:
        _play_2d_once(SCARE_RISER, -5.0, 1.0, "Music")
        if stalker != null:
            _play_3d(MONSTER_SCREAM, stalker.global_position + Vector3(0.0, 1.3, 0.0), -2.0, _rng.randf_range(0.92, 1.06), "Creature")
    _last_state = state_name

func _on_scare_pulse(world_position: Vector3, strength: float) -> void:
    _play_3d(ENTITY_GROWL, world_position, lerp(-10.0, -2.0, strength), _rng.randf_range(0.76, 1.06), "Creature")
    if light_manager != null:
        light_manager.trigger_disturbance(world_position, 3.2, strength)
        if strength > 0.75:
            light_manager.trigger_blackout(0.42)

func _on_near_scare(world_position: Vector3) -> void:
    _play_3d(MONSTER_SCREAM, world_position, 0.0, _rng.randf_range(0.95, 1.1), "Creature")
    _play_2d_once(JUMPSCARE_HIT, -3.0, 1.0, "HorrorSFX")
    if player != null and player.has_method("add_trauma"):
        player.add_trauma(0.7)

# GameRoot tarafından çağrılır (yakalanma anı)
func play_grab_breath() -> void:
    if stalker != null:
        _play_3d(MONSTER_BREATH, stalker.global_position + Vector3(0.0, 1.5, 0.0), -1.0, 0.9, "Creature")

func play_jumpscare() -> void:
    _play_2d_once(JUMPSCARE_HIT, 0.0, 1.0, "HorrorSFX")
    if stalker != null:
        _play_3d(MONSTER_SCREAM, stalker.global_position + Vector3(0.0, 1.3, 0.0), 2.0, 1.0, "Creature")

func _play_2d_once(path: String, volume_db: float, pitch: float, bus_name: String) -> void:
    var s: AudioStream = _load_audio(path)
    if s == null:
        return
    var p2d: AudioStreamPlayer = AudioStreamPlayer.new()
    p2d.name = "OneShot2D"
    p2d.stream = s
    p2d.bus = bus_name
    p2d.volume_db = volume_db
    p2d.pitch_scale = pitch
    add_child(p2d)
    p2d.finished.connect(Callable(p2d, "queue_free"))
    p2d.play()

func _play_3d(path: String, world_position: Vector3, volume_db: float, pitch: float, bus_name: String) -> void:
    if _stinger_pool.size() == 0:
        return
    var s: AudioStream = _load_audio(path)
    if s == null:
        return
    var p3d: AudioStreamPlayer3D = _stinger_pool[_stinger_index]
    _stinger_index = (_stinger_index + 1) % _stinger_pool.size()
    p3d.stop()
    p3d.stream = s
    p3d.global_position = world_position
    p3d.volume_db = volume_db
    p3d.pitch_scale = pitch
    p3d.bus = bus_name
    p3d.play()

func _load_audio(path: String) -> AudioStream:
    if not ResourceLoader.exists(path):
        return null
    var resource: Resource = load(path)
    if resource is AudioStream:
        return resource as AudioStream
    return null

func _set_wav_loop(stream: AudioStream) -> void:
    if stream == null:
        return
    var wav_stream: AudioStreamWAV = stream as AudioStreamWAV
    if wav_stream != null:
        wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
