extends CanvasLayer
class_name JumpscareOverlay

signal jumpscare_finished

var _face: TextureRect
var _flash: ColorRect
var _active: bool = false
var _timer: float = 0.0
var _duration: float = 0.0
var _shake_target: Node = null

func _ready() -> void:
    layer = 60
    _flash = ColorRect.new()
    _flash.name = "JumpscareFlash"
    _flash.set_anchors_preset(Control.PRESET_FULL_RECT)
    _flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _flash.color = Color(0.0, 0.0, 0.0, 0.0)
    add_child(_flash)

    _face = TextureRect.new()
    _face.name = "JumpscareFace"
    _face.set_anchors_preset(Control.PRESET_FULL_RECT)
    _face.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    _face.texture = _build_face_texture()
    _face.visible = false
    add_child(_face)

func bind_shake_target(target: Node) -> void:
    _shake_target = target

func _process(delta: float) -> void:
    if not _active:
        return
    _timer += delta
    var k: float = clamp(_timer / _duration, 0.0, 1.0)
    # İlk anda sert göster, sonra hızla sönsün
    var appear: float = clamp(_timer / 0.06, 0.0, 1.0)
    var fade: float = 1.0 - smoothstep(0.55, 1.0, k)
    var intensity: float = appear * fade
    _face.visible = intensity > 0.01
    _face.modulate = Color(1.0, 1.0, 1.0, intensity)
    # titreyen ölçek
    var jitter: float = 1.0 + sin(_timer * 90.0) * 0.03 * intensity
    _face.scale = Vector2(jitter, jitter)
    _face.pivot_offset = _face.size * 0.5
    _flash.color = Color(0.9, 0.85, 0.82, intensity * 0.5)
    if _shake_target != null and _shake_target.has_method("add_trauma"):
        _shake_target.add_trauma(0.9 * intensity * delta * 6.0)
    if _timer >= _duration:
        _active = false
        _face.visible = false
        _flash.color = Color(0.0, 0.0, 0.0, 0.0)
        jumpscare_finished.emit()

func trigger(duration: float = 1.1) -> void:
    _active = true
    _timer = 0.0
    _duration = max(0.4, duration)
    _face.visible = true
    if _shake_target != null and _shake_target.has_method("add_trauma"):
        _shake_target.add_trauma(1.0)

func is_active() -> bool:
    return _active

# Karanlık bir yüz: parlayan turuncu gözler, açık karanlık ağız
func _build_face_texture() -> Texture2D:
    var size: int = 256
    var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var cx: float = float(size) * 0.5
    for y: int in range(size):
        for x: int in range(size):
            var nx: float = (float(x) - cx) / cx
            var ny: float = (float(y) - cx) / cx
            var head: float = (nx * nx) / 0.62 + (ny * ny) / 0.95
            var color: Color = Color(0.0, 0.0, 0.0, 0.0)
            if head < 1.0:
                var shade: float = clamp(1.0 - head, 0.0, 1.0)
                color = Color(0.03 + shade * 0.04, 0.02 + shade * 0.02, 0.02, 1.0)
            # gözler
            var eye_l: float = pow(nx + 0.32, 2.0) / 0.020 + pow(ny + 0.18, 2.0) / 0.012
            var eye_r: float = pow(nx - 0.32, 2.0) / 0.020 + pow(ny + 0.18, 2.0) / 0.012
            var eye: float = min(eye_l, eye_r)
            if eye < 1.0:
                var glow: float = clamp(1.0 - eye, 0.0, 1.0)
                color = Color(1.0, 0.42 + glow * 0.25, 0.06).lerp(Color(1.0, 0.85, 0.4), glow * 0.5)
                color.a = 1.0
            # ağız (karanlık dikey yarık)
            var mouth: float = pow(nx, 2.0) / 0.05 + pow(ny - 0.42, 2.0) / 0.05
            if mouth < 1.0 and head < 1.0:
                color = Color(0.0, 0.0, 0.0, 1.0)
            image.set_pixel(x, y, color)
    return ImageTexture.create_from_image(image)
