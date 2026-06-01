extends CanvasLayer
class_name PremiumHud

var _distance_label: Label
var _flashlight_bar: ProgressBar
var _stamina_bar: ProgressBar
var _danger_bar: ProgressBar
var _noise_bar: ProgressBar
var _ai_state_label: Label
var _message_panel: Panel
var _message_title: Label
var _message_subtitle: Label
var _subtitle_label: Label
var _fps_label: Label
var _pulse_time: float = 0.0
var _hint_timer: float = 0.0
var _hints: Array[String] = [
    "Koşmak sesi büyütür. Bazı şeyler gözden önce sesi bulur.",
    "Floresan uğultusunu takip etme. Bazen seni yanıltır.",
    "Fener seni kurtarır ama seni ele de verebilir.",
    "Bir koridor fazla sessizse, orası boş olmayabilir.",
    "Canavar bazen kovalamaz; yolunu keser."
]

func _ready() -> void:
    layer = 40
    _build_ui()

func _process(delta: float) -> void:
    _pulse_time += delta
    _hint_timer += delta
    if _hint_timer > 9.0:
        _hint_timer = 0.0
        var index: int = int(_pulse_time) % _hints.size()
        set_hint(_hints[index])
    if _subtitle_label != null:
        var alpha: float = 0.48 + sin(_pulse_time * 1.8) * 0.14
        _subtitle_label.modulate = Color(1.0, 0.86, 0.54, alpha)
    if _fps_label != null:
        # FPS + teşhis: yüksek "dc" (draw call) => CPU/draw-call darboğazı,
        # yüksek "kp" (bin primitive) ama düşük dc => GPU piksel/aydınlatma darboğazı.
        var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
        _fps_label.text = "FPS %d   dc %d   kp %d" % [int(Engine.get_frames_per_second()), dc, prims / 1000]

func set_distance_to_exit(distance: float) -> void:
    if _distance_label != null:
        _distance_label.text = "Çıkış sinyali: %04dm" % int(distance)

func set_flashlight_energy(value: float) -> void:
    if _flashlight_bar != null:
        _flashlight_bar.value = clamp(value * 100.0, 0.0, 100.0)
        if value < 0.2:
            _flashlight_bar.modulate = Color(1.0, 0.35, 0.25, 1.0)
        else:
            _flashlight_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_stamina(value: float) -> void:
    if _stamina_bar != null:
        _stamina_bar.value = clamp(value * 100.0, 0.0, 100.0)

func set_danger_level(value: float) -> void:
    if _danger_bar != null:
        _danger_bar.value = clamp(value * 100.0, 0.0, 100.0)

func set_noise_level(value: float) -> void:
    if _noise_bar != null:
        _noise_bar.value = clamp(value * 100.0, 0.0, 100.0)

func set_ai_state(state_name: String) -> void:
    if _ai_state_label != null:
        _ai_state_label.text = "Varlık: " + state_name

func set_hint(text: String) -> void:
    if _subtitle_label != null:
        _subtitle_label.text = text

func show_big_message(title: String, subtitle: String) -> void:
    _message_panel.visible = true
    _message_title.text = title
    _message_subtitle.text = subtitle

func _build_ui() -> void:
    var root: Control = Control.new()
    root.name = "PremiumHudRoot"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    _distance_label = Label.new()
    _distance_label.name = "DistanceToExit"
    _distance_label.text = "Çıkış sinyali: ----m"
    _distance_label.modulate = Color(1.0, 0.88, 0.56, 0.86)
    _distance_label.position = Vector2(42.0, 76.0)
    root.add_child(_distance_label)

    _flashlight_bar = _make_bar("Fener", Vector2(42.0, 112.0), root)
    _stamina_bar = _make_bar("Nefes", Vector2(42.0, 150.0), root)
    _danger_bar = _make_bar("Yakınlık", Vector2(42.0, 188.0), root)
    _noise_bar = _make_bar("Ses", Vector2(42.0, 226.0), root)

    _ai_state_label = Label.new()
    _ai_state_label.name = "EntityState"
    _ai_state_label.text = "Varlık: Uzakta"
    _ai_state_label.position = Vector2(42.0, 270.0)
    _ai_state_label.modulate = Color(1.0, 0.66, 0.42, 0.70)
    root.add_child(_ai_state_label)

    _subtitle_label = Label.new()
    _subtitle_label.name = "SubtitleHint"
    _subtitle_label.text = _hints[0]
    _subtitle_label.position = Vector2(600.0, 972.0)
    _subtitle_label.size = Vector2(900.0, 40.0)
    _subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _subtitle_label.modulate = Color(1.0, 0.86, 0.54, 0.55)
    root.add_child(_subtitle_label)

    _message_panel = Panel.new()
    _message_panel.name = "MessagePanel"
    _message_panel.size = Vector2(900.0, 290.0)
    _message_panel.position = Vector2(510.0, 335.0)
    _message_panel.visible = false
    root.add_child(_message_panel)

    _message_title = Label.new()
    _message_title.name = "MessageTitle"
    _message_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _message_title.size = Vector2(860.0, 90.0)
    _message_title.position = Vector2(20.0, 50.0)
    _message_title.add_theme_font_size_override("font_size", 48)
    _message_panel.add_child(_message_title)

    _message_subtitle = Label.new()
    _message_subtitle.name = "MessageSubtitle"
    _message_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _message_subtitle.size = Vector2(820.0, 120.0)
    _message_subtitle.position = Vector2(40.0, 150.0)
    _message_subtitle.add_theme_font_size_override("font_size", 24)
    _message_panel.add_child(_message_subtitle)

    _fps_label = Label.new()
    _fps_label.name = "FpsCounter"
    _fps_label.text = "FPS 0"
    _fps_label.position = Vector2(42.0, 36.0)
    _fps_label.add_theme_font_size_override("font_size", 24)
    _fps_label.modulate = Color(0.55, 1.0, 0.65, 0.92)
    root.add_child(_fps_label)

func _make_bar(label_text: String, position: Vector2, root: Control) -> ProgressBar:
    var label: Label = Label.new()
    label.text = label_text
    label.position = position
    label.size = Vector2(92.0, 28.0)
    label.modulate = Color(1.0, 0.88, 0.56, 0.78)
    root.add_child(label)

    var bar: ProgressBar = ProgressBar.new()
    bar.position = position + Vector2(96.0, 1.0)
    bar.size = Vector2(255.0, 24.0)
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    root.add_child(bar)
    return bar
