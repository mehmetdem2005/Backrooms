extends Node
## ALTYAZI (autoload) - ekran altinda korku/psikolojik altyazilar (#28) + sinematik replikleri.
## goster(metin, sure) ile cagrilir; hafif titreme/glitch.

var _lbl: Label
var _gizle_t: float = 0.0

func _ready() -> void:
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
	_lbl = Label.new()
	_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lbl.offset_top = -110.0; _lbl.offset_bottom = -60.0
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 24)
	_lbl.add_theme_color_override("font_color", Color(0.88, 0.12, 0.12))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_lbl.add_theme_constant_override("outline_size", 6)
	_lbl.visible = false
	cl.add_child(_lbl)

func goster(metin: String, sure: float = 3.0) -> void:
	if _lbl == null: return
	_lbl.text = metin
	_lbl.visible = true
	_gizle_t = sure

func _process(delta: float) -> void:
	if _gizle_t > 0.0:
		_gizle_t -= delta
		if _lbl:
			_lbl.modulate.a = 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.02)
			if randf() < 0.04: _lbl.position.x = randf_range(-2, 2)   # glitch titreme
		if _gizle_t <= 0.0 and _lbl:
			_lbl.visible = false
