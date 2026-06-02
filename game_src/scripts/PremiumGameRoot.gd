extends Node3D

const BUILDER_SCRIPT: Script = preload("res://scripts/level/PremiumBackroomsBuilder.gd")
const PLAYER_SCRIPT: Script = preload("res://scripts/player/PremiumFpsPlayer.gd")
const MOBILE_CONTROLS_SCRIPT: Script = preload("res://scripts/ui/MobileControls.gd")
const HUD_SCRIPT: Script = preload("res://scripts/ui/PremiumHud.gd")
const POST_SCRIPT: Script = preload("res://scripts/horror/PremiumPostProcessOverlay.gd")
const LIGHT_SCRIPT: Script = preload("res://scripts/horror/SmartFluorescentLightManager.gd")
const STALKER_SCRIPT: Script = preload("res://scripts/horror/ShadowStalker.gd")
const DUST_SCRIPT: Script = preload("res://scripts/horror/DustVolume.gd")
const AUDIO_DIRECTOR_SCRIPT: Script = preload("res://scripts/horror/AudioDirector.gd")
const JUMPSCARE_SCRIPT: Script = preload("res://scripts/horror/JumpscareOverlay.gd")
const BATTERY_SCRIPT: Script = preload("res://scripts/items/BatteryPickup.gd")
const FAKE_EXIT_SCRIPT: Script = preload("res://scripts/items/FakeExit.gd")
const SETTINGS_SCRIPT: Script = preload("res://scripts/ui/SettingsMenu.gd")

@export var world_seed: int = 463063
@export var maze_width: int = 33
@export var maze_height: int = 33
@export var premium_mode: bool = true
@export var spawn_stalker: bool = true

var level_builder
var chunk_streamer
var player
var mobile_controls
var hud
var post_process
var light_manager
var stalker
var audio_director
var jumpscare
var _grab_phase: int = 0
var _grab_timer: float = 0.0
var exit_area: Area3D
var game_finished: bool = false
var _calm_time: float = 0.0           # ScareDirector: oyuncu ne kadar süredir sakin
var _scare_cooldown: float = 12.0

func _ready() -> void:
    _apply_premium_runtime_settings()
    _create_environment()
    _create_level()
    _create_player()
    _create_chunk_streamer()
    _create_lighting()
    _create_reflection_probes()
    _create_atmosphere_particles()
    _create_ui()
    _create_items()
    _create_settings()
    _create_stalker()
    _create_audio_director()
    _connect_exit()

func _create_settings() -> void:
    var settings: CanvasLayer = SETTINGS_SCRIPT.new()
    settings.name = "SettingsMenu"
    settings.mobile_controls = mobile_controls
    add_child(settings)

func _create_items() -> void:
    if level_builder == null:
        return
    for pos: Vector3 in level_builder.battery_positions:
        var battery: Area3D = BATTERY_SCRIPT.new()
        battery.hud = hud
        add_child(battery)
        battery.global_position = pos
    # Sahte çıkışlar (tuzak EXIT tabelaları)
    for i: int in range(level_builder.fake_exit_positions.size()):
        var fx: Node3D = FAKE_EXIT_SCRIPT.new()
        fx.hud = hud
        fx.light_manager = light_manager
        add_child(fx)
        fx.global_position = level_builder.fake_exit_positions[i]
        var d: Vector3 = level_builder.fake_exit_dirs[i]
        if d.length() > 0.1:
            fx.rotation.y = atan2(d.x, d.z)

func _process(delta: float) -> void:
    if game_finished:
        _update_grab_cinematic(delta)
        return
    if player == null:
        return

    # --- KARANLIK MEKANİĞİ ---
    var illumination: float = 0.0
    if light_manager != null:
        illumination = light_manager.get_illumination(player.global_position)
    player.set_local_light(illumination)
    if post_process != null:
        post_process.set_darkness(player.get_darkness() * 0.82)
        # fener kapalıyken görüş alanı daralır ama merkez net kalır
        var vision: float = 0.95 if player.is_flashlight_on() else lerp(0.44, 0.62, illumination)
        post_process.set_vision_radius(vision)

    if hud != null and level_builder != null:
        # Döngü harita: çıkış yok. HUD bulunduğun katı + uyarıyı gösterir.
        var floor_index: int = level_builder.world_to_grid(player.global_position).y
        var floor_name: String = ["ÜST KAT", "ORTA KAT", "ALT KAT (HAVUZ)"][clamp(floor_index, 0, 2)]
        var sanity_warn: String = ""
        if player.get_sanity() < 0.4:
            sanity_warn = "  •  AKLIN BULANIYOR…"
        hud.set_status("%s — çıkış yok, hayatta kal%s" % [floor_name, sanity_warn])
        hud.set_stamina(player.stamina)
        hud.set_flashlight_energy(player.flashlight_energy)
        hud.set_noise_level(player.get_noise_level())

    if stalker != null and post_process != null:
        var danger_distance: float = player.global_position.distance_to(stalker.global_position)
        # Tehlike, harita boyutuna oranlı + canavarın farkındalığıyla harmanlı.
        var map_span: float = float(maze_width) * level_builder.cell_size
        var danger_ref: float = max(28.0, map_span * 0.22)
        var distance_factor: float = clamp(1.0 - danger_distance / danger_ref, 0.0, 1.0)
        var fear: float = max(distance_factor, stalker.get_awareness() * 0.85)
        if stalker.get_state_name() == "CHASE":
            fear = max(fear, 0.8)
        player.set_stress_level(fear)
        # SANITY: düşük akıl görsel bozulmayı artırır (plan: HUD/karanlık bozulur)
        var insane: float = 1.0 - player.get_sanity()
        post_process.set_fear_level(max(fear, insane * 0.55))
        if hud != null:
            hud.set_danger_level(max(fear, insane * 0.5))
        _update_scare_director(delta, fear)

func _update_scare_director(delta: float, fear: float) -> void:
    # Oyuncu uzun süre sakinse kontrollü korku olayı tetikle (jumpscare spam yok).
    # Akıl düştükçe olaylar daha sık (eşik kısalır).
    if light_manager == null:
        return
    if fear < 0.25:
        _calm_time += delta
    else:
        _calm_time = 0.0
    _scare_cooldown = max(0.0, _scare_cooldown - delta)
    var threshold: float = lerp(13.0, 26.0, player.get_sanity())
    if _calm_time > threshold and _scare_cooldown <= 0.0:
        _trigger_scare()
        _calm_time = 0.0
        _scare_cooldown = randf_range(16.0, 30.0)

func _trigger_scare() -> void:
    var roll: float = randf()
    if roll < 0.5:
        light_manager.trigger_blackout(randf_range(0.5, 1.2))               # ışıklar kısa söner
    else:
        var off: Vector3 = Vector3(randf_range(-12.0, 12.0), 0.0, randf_range(-12.0, 12.0))
        light_manager.trigger_disturbance(player.global_position + off, 2.4, 1.0)  # uzakta titreme

func _apply_premium_runtime_settings() -> void:
    # Render ayarları project.godot'ta tutulur (runtime'da yazmak debugger'ı kirletir / no-op'tur).
    # Gerçekten runtime'da etki eden viewport ayarları burada.
    Engine.max_fps = 60
    var vp: Viewport = get_viewport()
    if vp != null:
        vp.msaa_3d = Viewport.MSAA_DISABLED
        vp.use_debanding = true
        vp.positional_shadow_atlas_size = 2048

func _create_environment() -> void:
    var world_environment: WorldEnvironment = WorldEnvironment.new()
    world_environment.name = "PremiumWorldEnvironment"

    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.010, 0.009, 0.006, 1.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.45, 0.39, 0.25, 1.0)
    # Taban ışık biraz yükseltildi: fenersiz alan karanlık ama yön bulunabilir (kapkaranlık değil)
    environment.ambient_light_energy = 0.16

    environment.fog_enabled = true
    environment.fog_light_color = Color(0.70, 0.60, 0.36, 1.0)
    environment.fog_light_energy = 0.45
    environment.fog_density = 0.020
    environment.fog_sky_affect = 0.0
    environment.fog_mode = Environment.FOG_MODE_DEPTH
    environment.fog_depth_begin = 6.0
    environment.fog_depth_end = 50.0
    environment.fog_depth_curve = 1.6

    # NOT: Volumetrik sis yalnızca Forward+ renderer'da çalışır. Bu oyun Mobile renderer
    # kullandığı için kapalı (açık olsaydı debugger'a hata basar ve hiçbir etki yapmazdı).
    # Mobile'da normal derinlik sisi (yukarıdaki fog_*) zaten atmosferi sağlıyor.
    environment.volumetric_fog_enabled = false

    # Glow KAPALI: mobilde çok-geçişli bloom pahalı + gereksiz parlama yapıyordu
    environment.glow_enabled = false
    environment.glow_intensity = 0.36
    environment.glow_strength = 0.78
    environment.glow_bloom = 0.20
    environment.glow_hdr_threshold = 0.85
    environment.glow_hdr_scale = 1.5
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.0
    environment.tonemap_white = 1.0
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 0.90
    environment.adjustment_contrast = 1.20
    environment.adjustment_saturation = 0.70

    world_environment.environment = environment
    add_child(world_environment)

func _create_level() -> void:
    level_builder = BUILDER_SCRIPT.new()
    level_builder.name = "PremiumProceduralBackrooms"
    level_builder.world_seed = world_seed
    level_builder.grid_width = maze_width
    level_builder.grid_height = maze_height
    level_builder.room_count = 12
    level_builder.detail_density = 1.0
    level_builder.floors = 3            # üst kat / orta kat (başlangıç) / alt kat (havuz)
    add_child(level_builder)
    level_builder.generate()

func _create_player() -> void:
    player = PLAYER_SCRIPT.new()
    player.name = "Player"
    add_child(player)
    player.level_builder = level_builder
    player.global_position = level_builder.start_world_position + Vector3(0.0, 1.05, 0.0)

func _create_chunk_streamer() -> void:
    if level_builder == null or level_builder.chunks.is_empty():
        return
    chunk_streamer = ChunkStreamer.new()
    chunk_streamer.name = "ChunkStreamer"
    add_child(chunk_streamer)
    # Görüş mesafesi sise hizalandı: sis ~50m'de tamamen kapatıyor, ötesini çizmek boşa.
    # (Önceki 64m, sisin arkasındaki görünmez geometriyi de çiziyordu → boşa draw call.)
    var distance: float = level_builder.cell_size * 13.0  # ~52m: sis sınırı (ötesi görünmez)
    chunk_streamer.setup(player, level_builder.chunks, distance)

func _create_lighting() -> void:
    light_manager = LIGHT_SCRIPT.new()
    light_manager.name = "SmartFluorescentLightManager"
    light_manager.player = player
    light_manager.fixture_positions = level_builder.fixture_positions
    light_manager.max_active_lights = 6
    light_manager.enable_near_shadows = false
    add_child(light_manager)

func _create_reflection_probes() -> void:
    # Yansıma probları mobilde ek render maliyeti getiriyordu ve etkisi inceydi → kapalı.
    pass

func _create_atmosphere_particles() -> void:
    if not premium_mode:
        return
    var dust: Node3D = DUST_SCRIPT.new()
    dust.name = "DustVolume"
    dust.player = player
    add_child(dust)

func _create_ui() -> void:
    mobile_controls = MOBILE_CONTROLS_SCRIPT.new()
    mobile_controls.name = "MobileControls"
    add_child(mobile_controls)
    player.mobile_controls = mobile_controls

    hud = HUD_SCRIPT.new()
    hud.name = "PremiumHud"
    add_child(hud)
    player.hud = hud

    post_process = POST_SCRIPT.new()
    post_process.name = "PremiumPostProcessOverlay"
    add_child(post_process)

    jumpscare = JUMPSCARE_SCRIPT.new()
    jumpscare.name = "JumpscareOverlay"
    add_child(jumpscare)
    jumpscare.bind_shake_target(player)

func _create_stalker() -> void:
    if not spawn_stalker:
        return
    stalker = STALKER_SCRIPT.new()
    stalker.name = "ShadowStalker"
    stalker.level_builder = level_builder
    stalker.player = player
    add_child(stalker)
    stalker.global_position = level_builder.enemy_world_position + Vector3(0.0, 1.0, 0.0)
    stalker.caught_player.connect(Callable(self, "_on_player_caught"))
    stalker.near_scare.connect(Callable(self, "_on_near_scare"))
    # Canavarı chunk çarpışma yayınına dahil et: altındaki/etrafındaki chunk'lar çarpışır kalsın
    if chunk_streamer != null:
        var entity_collision_distance: float = float(level_builder.chunk_size) * level_builder.cell_size * 1.6
        chunk_streamer.set_entity(stalker, entity_collision_distance)

func _create_audio_director() -> void:
    audio_director = AUDIO_DIRECTOR_SCRIPT.new()
    audio_director.name = "AudioDirector"
    add_child(audio_director)
    audio_director.bind_references(player, stalker, level_builder, light_manager, hud)

func _connect_exit() -> void:
    exit_area = level_builder.exit_area
    if exit_area != null:
        exit_area.body_entered.connect(Callable(self, "_on_exit_body_entered"))

func _on_near_scare(_world_position: Vector3) -> void:
    # ölümcül olmayan irkilme: kısa flaş + sarsıntı (oyun bitmez)
    if post_process != null:
        post_process.trigger_flash(0.45, 0.0)

func _on_exit_body_entered(body: Node3D) -> void:
    if game_finished:
        return
    if body == player:
        game_finished = true
        if hud != null:
            hud.show_big_message("ÇIKIŞ BULUNDU", "Kapı açıldı ama sesler hâlâ içeriden geliyor.")
        if post_process != null:
            post_process.set_fear_level(0.25)
        if player != null:
            player.lock_controls = true

func _on_player_caught() -> void:
    if game_finished:
        return
    game_finished = true
    # Doğrudan öldürme YOK: canavar seni kollarıyla havaya kaldırır, yüzünü gösterir, sonra bağırır.
    if player != null:
        player.lock_controls = true
    if stalker != null and player != null:
        var in_front: Vector3 = player.global_position - player.global_transform.basis.z * 1.25
        stalker.global_position = Vector3(in_front.x, stalker.global_position.y, in_front.z)
        if player.has_method("face_position"):
            player.face_position(stalker.global_position)
        if stalker.has_method("begin_grab"):
            stalker.begin_grab(player)
        if player.has_method("start_grab"):
            player.start_grab(stalker.global_position + Vector3(0.0, 1.82, 0.0))
    if post_process != null:
        post_process.set_fear_level(1.0)
    if audio_director != null and audio_director.has_method("play_grab_breath"):
        audio_director.play_grab_breath()
    _grab_phase = 1
    _grab_timer = 0.0

func _update_grab_cinematic(delta: float) -> void:
    if _grab_phase == 0:
        return
    _grab_timer += delta
    # Kamera hedefini canlı tut (canavar başını takip et) — oyuncu kendi _process'inde kaldırılıyor
    if player != null and stalker != null and player.has_method("update_grab_target"):
        player.update_grab_target(stalker.global_position + Vector3(0.0, 1.82, 0.0))
    if _grab_phase == 1 and _grab_timer >= 1.75:
        # Kaldırma tamam, yüz yüzeyiz → ÇIĞLIK
        _grab_phase = 2
        if audio_director != null:
            audio_director.play_jumpscare()
        if player != null and player.has_method("add_trauma"):
            player.add_trauma(1.0)
        if post_process != null:
            post_process.trigger_flash(1.0, 0.9)
        if jumpscare != null:
            jumpscare.trigger(1.5)
    elif _grab_phase == 2 and _grab_timer >= 2.65:
        _grab_phase = 3
        if hud != null:
            hud.show_big_message("YAKALANDIN", "Seni havaya kaldırdı. Yüzü çok yakındı.")
