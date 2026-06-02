extends CanvasLayer
class_name SettingsMenu

# Kalite ayarları menüsü: dişli (MobileControls) ile açılır, oyunu duraklatır.
# Render ölçeği + FPS hedefi presetleri (her telefonda çalışsın). user:// kaydı.
var mobile_controls
var _panel: Panel
var _open: bool = false
var _info: Label
const CFG: String = "user://settings.cfg"

func _ready() -> void:
    layer = 50
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build()
    _load_apply()

func _process(_d: float) -> void:
    if mobile_controls != null and mobile_controls.consume_settings_toggle():
        _toggle()

func _toggle() -> void:
    _open = not _open
    _panel.visible = _open
    get_tree().paused = _open

func _build() -> void:
    _panel = Panel.new()
    _panel.size = Vector2(760.0, 540.0)
    _panel.position = Vector2((1920.0 - 760.0) * 0.5, (1080.0 - 540.0) * 0.5)
    _panel.visible = false
    var sb: StyleBoxFlat = StyleBoxFlat.new()
    sb.bg_color = Color(0.06, 0.06, 0.08, 0.96)
    sb.set_corner_radius_all(16)
    sb.set_border_width_all(2)
    sb.border_color = Color(1.0, 0.86, 0.5, 0.6)
    _panel.add_theme_stylebox_override("panel", sb)
    add_child(_panel)

    _mklabel("AYARLAR  •  Grafik Kalitesi", Vector2(40.0, 30.0), 40)
    var presets: Array = [["Düşük", 0.6, 30], ["Orta", 0.75, 30], ["Yüksek", 0.85, 60], ["Ultra", 1.0, 60]]
    for i: int in range(presets.size()):
        var entry: Array = presets[i]
        var b: Button = _mkbtn(str(entry[0]), Vector2(40.0 + float(i) * 178.0, 130.0), Vector2(168.0, 110.0))
        var sc: float = float(entry[1])
        var fps: int = int(entry[2])
        b.pressed.connect(func() -> void: _apply(sc, fps))

    _info = _mklabel("Render ölçeği + FPS hedefi. Telefonun kasarsa Düşük seç.", Vector2(40.0, 280.0), 24)
    var close: Button = _mkbtn("KAPAT", Vector2(40.0, 400.0), Vector2(680.0, 100.0))
    close.pressed.connect(_toggle)

func _mkbtn(text: String, pos: Vector2, size: Vector2) -> Button:
    var b: Button = Button.new()
    b.text = text
    b.position = pos
    b.size = size
    b.add_theme_font_size_override("font_size", 30)
    _panel.add_child(b)
    return b

func _mklabel(t: String, pos: Vector2, fs: int) -> Label:
    var l: Label = Label.new()
    l.text = t
    l.position = pos
    l.add_theme_font_size_override("font_size", fs)
    l.modulate = Color(1.0, 0.92, 0.7, 0.95)
    _panel.add_child(l)
    return l

func _apply(scale_value: float, fps: int) -> void:
    var vp: Viewport = get_viewport()
    if vp != null:
        vp.scaling_3d_scale = scale_value
    Engine.max_fps = fps
    if _info != null:
        _info.text = "Seçildi: render %d%%  •  %d FPS" % [int(scale_value * 100.0), fps]
    _save(scale_value, fps)

func _save(scale_value: float, fps: int) -> void:
    var c: ConfigFile = ConfigFile.new()
    c.set_value("quality", "scale", scale_value)
    c.set_value("quality", "fps", fps)
    c.save(CFG)

func _load_apply() -> void:
    var c: ConfigFile = ConfigFile.new()
    if c.load(CFG) == OK:
        _apply(float(c.get_value("quality", "scale", 0.85)), int(c.get_value("quality", "fps", 60)))
