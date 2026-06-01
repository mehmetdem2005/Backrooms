extends CanvasLayer
class_name MobileControls

var move_vector: Vector2 = Vector2.ZERO
var run_pressed: bool = false
var crouch_pressed: bool = false

var _look_delta: Vector2 = Vector2.ZERO
var _flashlight_toggle_requested: bool = false
var _left_touch_index: int = -1
var _right_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 150.0
var _home_center: Vector2 = Vector2(210.0, 830.0)

var _root: Control
var _stick_base: Panel
var _stick_knob: Panel
var _run_button: Button
var _flashlight_button: Button
var _crouch_button: Button

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
    var idle: StyleBoxFlat = _circle_style(Color(0.06, 0.05, 0.04, 0.55), Color(accent.r, accent.g, accent.b, 0.65), 3.0)
    var down: StyleBoxFlat = _circle_style(Color(accent.r, accent.g, accent.b, 0.55), Color(1.0, 0.96, 0.82, 0.9), 3.0)
    button.add_theme_stylebox_override("normal", idle)
    button.add_theme_stylebox_override("hover", idle)
    button.add_theme_stylebox_override("focus", idle)
    button.add_theme_stylebox_override("pressed", down)
    button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 0.95))
    button.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.04, 1.0))
    button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82, 0.95))
    button.add_theme_font_size_override("font_size", 30)
    return button

func _build_ui() -> void:
    _root = Control.new()
    _root.name = "MobileControlsRoot"
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_root)

    # --- Yuvarlak joystick ---
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

    # --- Yuvarlak aksiyon tuşları (sağ alt) ---
    _flashlight_button = _make_round_button("FlashlightButton", "FENER", Vector2(1780.0, 770.0), 138.0, Color(1.0, 0.86, 0.45))
    _root.add_child(_flashlight_button)
    _flashlight_button.pressed.connect(Callable(self, "_on_flashlight_pressed"))

    _run_button = _make_round_button("RunButton", "KOŞ", Vector2(1610.0, 900.0), 138.0, Color(0.55, 0.85, 1.0))
    _root.add_child(_run_button)
    _run_button.button_down.connect(Callable(self, "_on_run_down"))
    _run_button.button_up.connect(Callable(self, "_on_run_up"))

    _crouch_button = _make_round_button("CrouchButton", "GİZLEN", Vector2(1610.0, 730.0), 138.0, Color(0.7, 1.0, 0.7))
    _crouch_button.toggle_mode = true
    _root.add_child(_crouch_button)
    _crouch_button.toggled.connect(Callable(self, "_on_crouch_toggled"))

func _reset_joystick_visual() -> void:
    _stick_base.position = _joystick_center - _stick_base.size * 0.5
    _stick_knob.position = _joystick_center - _stick_knob.size * 0.5

func _handle_touch(touch: InputEventScreenTouch) -> void:
    var screen_width: float = get_viewport().get_visible_rect().size.x
    if touch.pressed:
        if touch.position.x < screen_width * 0.5 and _left_touch_index == -1:
            _left_touch_index = touch.index
            _joystick_center = touch.position
            _reset_joystick_visual()
            _stick_base.modulate = Color(1, 1, 1, 1)
        elif _right_touch_index == -1 and touch.position.x >= screen_width * 0.42:
            _right_touch_index = touch.index
    else:
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

func _on_run_down() -> void:
    run_pressed = true

func _on_run_up() -> void:
    run_pressed = false

func _on_flashlight_pressed() -> void:
    _flashlight_toggle_requested = true

func _on_crouch_toggled(pressed_state: bool) -> void:
    crouch_pressed = pressed_state
