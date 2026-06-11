extends Node
## ACILIS SINEMATIGI (#24): bayginken goz kirpma -> uyanis -> canavar yuzde bagirir ->
## replik + 'ON saniye veriyorum' -> birakir -> korkunc sayim 10..1 -> AV baslar.
## Oyuncu kontrolu sinematik boyunca kilitli (OyunDurumu.sinematik).

var _od: Node
var _alt: Node
var _oyuncu: Node3D
var _canavar: Node3D
var _kara: ColorRect
var _ses_cig: AudioStreamPlayer
var _ses_thud: AudioStreamPlayer

func _ready() -> void:
	call_deferred("_basla")

func _basla() -> void:
	_od = get_node_or_null("/root/OyunDurumu")
	_alt = get_node_or_null("/root/Altyazi")
	if _od == null: return
	_od.sinematik = true
	_od.av_modu = false
	# oyuncu + canavar hazir olana kadar bekle
	for _t in range(180):
		_oyuncu = _od.oyuncu; _canavar = _od.canavar
		if _oyuncu and _canavar: break
		await get_tree().process_frame
	_ui_kur()
	if _oyuncu and _canavar:
		var ileri := -_oyuncu.global_transform.basis.z
		var p: Vector3 = _oyuncu.global_position + ileri * 1.15
		_canavar.call("sinematik_yerlestir", p, _oyuncu.global_position)
	await _akis()

func _ui_kur() -> void:
	var cl := CanvasLayer.new(); cl.layer = 60; cl.name = "SinematikUI"; add_child(cl)
	_kara = ColorRect.new(); _kara.color = Color(0, 0, 0, 1)
	_kara.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_kara)
	_ses_cig = AudioStreamPlayer.new(); _ses_cig.stream = load("res://audio/bagir.wav"); _ses_cig.volume_db = 2.0
	add_child(_ses_cig)
	var g = load("res://audio/canavar_growl.wav")
	_ses_thud = AudioStreamPlayer.new(); _ses_thud.stream = g; _ses_thud.pitch_scale = 0.5; _ses_thud.volume_db = 1.0
	add_child(_ses_thud)

func _b(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _say(metin: String, sure: float) -> void:
	if _alt: _alt.call("goster", metin, sure)

func _cig() -> void:
	if _ses_cig: _ses_cig.play()
func _thud() -> void:
	if _ses_thud: _ses_thud.play()

func _akis() -> void:
	# 1) baygin -> goz kirpma (kara alpha cirpinmasi)
	var tw := create_tween()
	tw.tween_property(_kara, "color:a", 0.25, 0.7)
	tw.tween_property(_kara, "color:a", 0.85, 0.35)
	tw.tween_property(_kara, "color:a", 0.10, 0.5)
	tw.tween_property(_kara, "color:a", 0.65, 0.3)
	tw.tween_property(_kara, "color:a", 0.0, 0.8)
	await tw.finished
	# 2) gozler acildi: canavar yuzde, bagiris + replikler
	_cig()
	_say("UYAN.", 2.0); await _b(2.0)
	_say("Uyudugun her an... benim eglencemdi.", 3.0); await _b(3.0)
	_say("Korkun, uyanikken cok daha tatli.", 3.0); await _b(3.0)
	_say("KAC. Sana ON saniye veriyorum.", 2.5); await _b(2.5)
	# 3) birak: oyuncu kontrolu acilir, canavar geri cekilir
	_od.sinematik = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_CAPTURED
	if _canavar and _oyuncu:
		var geri := (_canavar.global_position - _oyuncu.global_position)
		geri.y = 0
		if geri.length() > 0.1: _canavar.global_position += geri.normalized() * 3.0
	# 4) korkunc geri sayim 10..1 (her rakamda rahatsiz edici vurus + altyazi)
	var rakam := ["ON", "DOKUZ", "SEKIZ", "YEDI", "ALTI", "BES", "DORT", "UC", "IKI", "BIR"]
	for r in rakam:
		_say(r + "...", 1.0); _thud(); await _b(1.0)
	# 5) AV baslar
	_od.av_modu = true
	_cig()
	_say("GELIYORUM.", 2.6)
	await _b(2.0)
	queue_free()
