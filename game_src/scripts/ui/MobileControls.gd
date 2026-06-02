extends CanvasLayer
class_name MobileControls

var move_vector: Vector2 = Vector2.ZERO
var run_pressed: bool = false
var crouch_pressed: bool = false

var _look_delta: Vector2 = Vector2.ZERO
var _flashlight_toggle_requested: bool = false
var _settings_requested: bool = false
var _left_touch_index: int = -1
var _right_touch_index: int = -1
var _run_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 150.0
var _home_center: Vector2 = Vector2(210.0, 830.0)

var _root: Control
var _stick_base: Panel
var _stick_knob: Panel
var _run_button: Button
var _flashlight_button: Button
var _crouch_button: Button

# Buton merkezleri (1920x1080 tasarım uzayı) + yarıçap → dokunma hit-testi
const FL_CENTER := Vector2(1790.0, 760.0)
const RUN_CENTER := Vector2(1600.0, 905.0)
const CR_CENTER := Vector2(1600.0, 735.0)
const GEAR_CENTER := Vector2(1850.0, 60.0)
const BTN_D: float = 152.0
const GEAR_D: float = 96.0

func _ready() -> void:
    layer = 30
    _build_ui()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event as InputEventScreenTouch)
    elif event is InputEventScreenDrag:
        _handle_drag(event as InputEventScreenDrag)

func consume_look_delta() -> Vector2:
    var result: Vector2 = _look_delta
    _look_delta = Vector2.ZERO
    return result

func consume_flashlight_toggle() -> bool:
    var result: bool = _flashlight_toggle_requested
    _flashlight_toggle_requested = false
    return result

func consume_settings_toggle() -> bool:
    var result: bool = _settings_requested
    _settings_requested = false
    return result

# Oyuncu her karede gerçek fener durumunu bildirir → buton "AÇ"/"KAPA" yazısı
func set_flashlight_on(on: bool) -> void:
    if _flashlight_button != null:
        _flashlight_button.text = "FENER\n" + ("KAPA" if on else "AÇ")

func _circle_style(fill: Color, border: Color, border_width: float = 3.0) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = fill
    style.set_corner_radius_all(400)
    style.border_width_left = int(border_width)
    style.border_width_top = int(border_width)
    style.border_width_right = int(border_width)
    style.border_width_bottom = int(border_width)
    style.border_color = border
    return style

func _make_round_button(node_name: String, label: String, center: Vector2, diameter: float, accent: Color) -> Button:
    var button: Button = Button.new()
    button.name = node_name
    button.text = label
    button.size = Vector2(diameter, diameter)
    button.position = center - Vector2(diameter, diameter) * 0.5
    # Görsel amaçlı; mantık dokunma hit-testinden sürülür (mobilde güvenilir).
    button.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.focus_mode = Control.FOCUS_NONE
    var idle: StyleBoxFlat = _circle_style(Color(0.06, 0.05, 0.04, 0.6), Color(accent.r, accent.g, accent.b, 0.7), 3.0)
    button.add_theme_stylebox_override("normal", idle)
    button.add_theme_stylebox_override("hover", idle)
    button.add_theme_stylebox_override("pressed", idle)
    button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 0.97))
    button.add_theme_font_size_override("font_size", 30)
    return button

func _build_ui() -> void:
    _root = Control.new()
    _root.name = "MobileControlsRoot"
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    var base_d: float = _joystick_radius * 2.0
    _stick_base = Panel.new()
    _stick_base.name = "JoystickBase"
    _stick_base.size = Vector2(base_d, base_d)
    _stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _stick_base.add_theme_stylebox_override("panel", _circle_style(Color(0.9, 0.78, 0.42, 0.08), Color(1.0, 0.88, 0.5, 0.30), 3.0))
    _root.add_child(_stick_base)

    _stick_knob = Panel.new()
    _stick_knob.name = "JoystickKnob"
    _stick_knob.size = Vector2(90.0, 90.0)
    _stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _stick_knob.add_theme_stylebox_override("panel", _circle_style(Color(1.0, 0.9, 0.55, 0.28), Color(1.0, 0.95, 0.7, 0.6), 3.0))
    _root.add_child(_stick_knob)

    _joystick_center = _home_center
    _reset_joystick_visual()

    _flashlight_button = _make_round_button("FlashlightButton", "FENER\nKAPA", FL_CENTER, BTN_D, Color(1.0, 0.86, 0.45))
    _flashlight_button.add_theme_font_size_override("font_size", 26)
    _root.add_child(_flashlight_button)

    _run_button = _make_round_button("RunButton", "KOŞ", RUN_CENTER, BTN_D, Color(0.55, 0.85, 1.0))
    _root.add_child(_run_button)

    _crouch_button = _make_round_button("CrouchButton", "GİZLEN", CR_CENTER, BTN_D, Color(0.7, 1.0, 0.7))
    _root.add_child(_crouch_button)

    var gear: Button = _make_round_button("SettingsButton", "⚙", GEAR_CENTER, GEAR_D, Color(0.8, 0.8, 0.85))
    gear.add_theme_font_size_override("font_size", 40)
    _root.add_child(gear)

func _reset_joystick_visual() -> void:
    _stick_base.position = _joystick_center - _stick_base.size * 0.5
    _stick_knob.position = _joystick_center - _stick_knob.size * 0.5

func _hit(pos: Vector2, center: Vector2) -> bool:
    return pos.distance_to(center) <= BTN_D * 0.5 + 8.0

func _handle_touch(touch: InputEventScreenTouch) -> void:
    var screen_width: float = get_viewport().get_visible_rect().size.x
    if touch.pressed:
        # 1) Aksiyon tuşları (her yerde, dokunma ile) — GUI sinyaline güvenmeyiz
        if touch.position.distance_to(GEAR_CENTER) <= GEAR_D * 0.5 + 12.0:
            _settings_requested = true
            return
        if _hit(touch.position, FL_CENTER):
            _flashlight_toggle_requested = true
            return
        if _hit(touch.position, RUN_CENTER):
            run_pressed = true
            _run_touch_index = touch.index
            return
        if _hit(touch.position, CR_CENTER):
            crouch_pressed = not crouch_pressed
            _crouch_button.text = "GÖRÜN" if crouch_pressed else "GİZLEN"
            return
        # 2) Sol yarı → joystick
        if touch.position.x < screen_width * 0.5 and _left_touch_index == -1:
            _left_touch_index = touch.index
            _joystick_center = touch.position
            _reset_joystick_visual()
        # 3) Sağ yarı → bakış
        elif _right_touch_index == -1:
            _right_touch_index = touch.index
    else:
        if touch.index == _run_touch_index:
            run_pressed = false
            _run_touch_index = -1
        if touch.index == _left_touch_index:
            _left_touch_index = -1
            move_vector = Vector2.ZERO
            _joystick_center = _home_center
            _reset_joystick_visual()
        if touch.index == _right_touch_index:
            _right_touch_index = -1

func _handle_drag(drag: InputEventScreenDrag) -> void:
    if drag.index == _left_touch_index:
        var stick_offset: Vector2 = drag.position - _joystick_center
        if stick_offset.length() > _joystick_radius:
            stick_offset = stick_offset.normalized() * _joystick_radius
        move_vector = Vector2(stick_offset.x / _joystick_radius, -stick_offset.y / _joystick_radius)
        _stick_knob.position = _joystick_center + stick_offset - _stick_knob.size * 0.5
    elif drag.index == _right_touch_index:
        _look_delta += drag.relative
