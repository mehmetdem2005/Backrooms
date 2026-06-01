extends CanvasLayer
class_name PremiumPostProcessOverlay

const SHADER: Shader = preload("res://shaders/premium_vignette_noise.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial
var _fear_level: float = 0.0
var _darkness: float = 0.0
var _darkness_target: float = 0.0
var _vision_radius: float = 0.62
var _flash: float = 0.0
var _flash_dark: float = 0.0
var _time: float = 0.0

func _ready() -> void:
    layer = 20
    _material = ShaderMaterial.new()
    _material.shader = SHADER
    _rect = ColorRect.new()
    _rect.name = "PremiumPostProcessRect"
    _rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rect.material = _material
    _rect.color = Color.WHITE
    add_child(_rect)

func _process(delta: float) -> void:
    _time += delta
    # Karanlık yumuşak geçişle hedefe yaklaşır (anında değil)
    _darkness = move_toward(_darkness, _darkness_target, delta * 1.8)
    _flash = move_toward(_flash, 0.0, delta * 3.5)
    _flash_dark = move_toward(_flash_dark, 0.0, delta * 1.2)
    if _material != null:
        _material.set_shader_parameter("time", _time)
        _material.set_shader_parameter("fear", _fear_level)
        _material.set_shader_parameter("darkness", _darkness)
        _material.set_shader_parameter("vision_radius", _vision_radius)
        _material.set_shader_parameter("flash", _flash)
        _material.set_shader_parameter("flash_dark", _flash_dark)

func set_fear_level(value: float) -> void:
    _fear_level = clamp(value, 0.0, 1.0)

# 0 = aydınlık, 1 = tam karanlık
func set_darkness(value: float) -> void:
    _darkness_target = clamp(value, 0.0, 1.0)

func set_vision_radius(value: float) -> void:
    _vision_radius = clamp(value, 0.18, 0.95)

# Jumpscare flaşı tetikler
func trigger_flash(white_strength: float = 1.0, dark_after: float = 0.0) -> void:
    _flash = clamp(white_strength, 0.0, 1.0)
    _flash_dark = clamp(dark_after, 0.0, 1.0)
