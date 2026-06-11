extends Node
## ALTYAZI (autoload) - IKI AYRI KANAL:
##  goster(metin)  -> CANAVAR sesi altyazisi (alt orta, kanli kirmizi, glitch) - sadece canavar konusunca.
##  cevre(metin)   -> ic ses / ortam (ust orta, soluk gri, italik egik) - rahatsiz edici dusunceler.
## Ikisi gorsel olarak AYRI: oyuncu hangisinin canavar oldugunu karistirmaz.

var _lbl: Label          # canavar
var _gizle_t: float = 0.0
var _clbl: Label         # cevre / ic ses
var _cgizle_t: float = 0.0

func _ready() -> void:
	var cl := CanvasLayer.new(); cl.layer = 50; add_child(cl)
	# --- CANAVAR (alt) ---
	_lbl = Label.new()
	_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_lbl.offset_top = -118.0; _lbl.offset_bottom = -62.0
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 26)
	_lbl.add_theme_color_override("font_color", Color(0.90, 0.08, 0.08))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_lbl.add_theme_constant_override("outline_size", 7)
	_lbl.visible = false
	cl.add_child(_lbl)
	# --- CEVRE / IC SES (ust) ---
	_clbl = Label.new()
	_clbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_clbl.offset_top = 64.0; _clbl.offset_bottom = 104.0
	_clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clbl.add_theme_font_size_override("font_size", 19)
	_clbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.70))
	_clbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clbl.add_theme_constant_override("outline_size", 5)
	_clbl.modulate.a = 0.0
	_clbl.visible = false
	cl.add_child(_clbl)

## CANAVAR sesi altyazisi - kanli, alt, glitch titreme.
func goster(metin: String, sure: float = 3.0) -> void:
	if _lbl == null: return
	_lbl.text = metin
	_lbl.visible = true
	_gizle_t = sure

## IC SES / ortam - soluk, ust, yavas belir-soner (canavar DEGIL).
func cevre(metin: String, sure: float = 4.0) -> void:
	if _clbl == null: return
	_clbl.text = metin
	_clbl.visible = true
	_cgizle_t = sure

func _process(delta: float) -> void:
	# canavar altyazisi: glitch
	if _gizle_t > 0.0:
		_gizle_t -= delta
		if _lbl:
			_lbl.modulate.a = 0.80 + 0.20 * sin(Time.get_ticks_msec() * 0.02)
			if randf() < 0.04: _lbl.position.x = randf_range(-2, 2)
		if _gizle_t <= 0.0 and _lbl:
			_lbl.visible = false
	# ic ses: yumusak belir/soner (fade in/out), titreme yok
	if _cgizle_t > 0.0:
		_cgizle_t -= delta
		if _clbl:
			var a := 1.0
			if _cgizle_t > 0.0 and _clbl.modulate.a < 1.0:
				a = minf(1.0, _clbl.modulate.a + delta * 1.6)   # belir
			if _cgizle_t < 0.7:
				a = _cgizle_t / 0.7                              # son
			_clbl.modulate.a = clampf(a, 0.0, 0.92)
		if _cgizle_t <= 0.0 and _clbl:
			_clbl.visible = false
			_clbl.modulate.a = 0.0
